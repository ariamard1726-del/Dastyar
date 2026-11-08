import 'dart:async';
import 'dart:convert';

/// تابعی که پرامپت را به Gemini می‌فرستد و متن جواب را برمی‌گرداند.
typedef LlmCall = Future<String> Function(String prompt);

/// ابزار قابل‌استفاده برای ایجنت.
typedef ToolFn = Future<String> Function(Map<String, dynamic> args);

class AgentTool {
  final String name;
  final String description;
  final ToolFn run;
  const AgentTool(this.name, this.description, this.run);
}

class AgentStep {
  final int index;
  final String thought;
  final String? tool;
  final String? observation;
  const AgentStep(this.index, this.thought, {this.tool, this.observation});
}

class AgentResult {
  final String answer;
  final List<AgentStep> steps;
  final bool usedFallback;
  const AgentResult(this.answer, this.steps, {this.usedFallback = false});
}

class AutonomousAgent {
  final LlmCall llm;
  final List<AgentTool> tools;
  final Future<String> Function(String question) offlineFallback;
  final int maxSteps;
  final Duration stepTimeout;
  final void Function(AgentStep step)? onStep;

  AutonomousAgent({
    required this.llm,
    required this.tools,
    required this.offlineFallback,
    this.maxSteps = 5,
    this.stepTimeout = const Duration(seconds: 40),
    this.onStep,
  });

  String _toolsText() => tools
      .map((t) => '- ${t.name}: ${t.description}')
      .join('\n');

  String _buildPrompt(String goal, List<String> history, List<AgentStep> steps) {
    final b = StringBuffer();
    b.writeln('تو ایجنت دستیار حقوقی آفلاین فارسی هستی.');
    b.writeln('قوانین سخت:');
    b.writeln('1) هر ادعای حقوقی و شماره ماده فقط باید از نتیجه ابزارها بیاید؛ هرگز از حافظه خودت ماده یا قانون نساز.');
    b.writeln('2) اگر ابزارها چیزی پیدا نکردند، صریح بگو در اپ موجود نیست.');
    b.writeln('3) اگر سؤال حقوقی نیست یا خارج از حوزه است، مودبانه رد کن (action=final).');
    b.writeln('4) اگر اطلاعات لازم کم است، با action=final یک سؤال روشن از کاربر بپرس.');
    b.writeln('5) حداکثر $maxSteps مرحله داری.');
    b.writeln();
    b.writeln('ابزارها:');
    b.writeln(_toolsText());
    b.writeln();
    b.writeln('فقط و فقط یک JSON بده، بدون هیچ متن دیگر:');
    b.writeln('{"thought":"فکر کوتاه","action":"tool","tool":"نام_ابزار","args":{}}');
    b.writeln('یا');
    b.writeln('{"thought":"...","action":"final","answer":"پاسخ نهایی به فارسی"}');
    b.writeln();
    if (history.isNotEmpty) {
      b.writeln('تاریخچه گفتگو:');
      for (final h in history) {
        b.writeln(h);
      }
      b.writeln();
    }
    b.writeln('هدف کاربر: $goal');
    if (steps.isNotEmpty) {
      b.writeln();
      b.writeln('مراحل قبلی:');
      for (final s in steps) {
        b.writeln('مرحله ${s.index}: ${s.thought}');
        if (s.tool != null) b.writeln('ابزار: ${s.tool}');
        if (s.observation != null) b.writeln('نتیجه: ${s.observation}');
      }
    }
    return b.toString();
  }

  Map<String, dynamic>? _parse(String raw) {
    final s = raw.indexOf('{');
    final e = raw.lastIndexOf('}');
    if (s < 0 || e <= s) return null;
    try {
      final v = jsonDecode(raw.substring(s, e + 1));
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
    return null;
  }

  Future<AgentResult> run(String goal, {List<String> history = const []}) async {
    final steps = <AgentStep>[];
    try {
      for (var i = 1; i <= maxSteps; i++) {
        final raw = await llm(_buildPrompt(goal, history, steps)).timeout(stepTimeout);
        final m = _parse(raw);
        if (m == null) {
          // یک بار تلاش مجدد با یادآوری قالب
          final raw2 = await llm(
                  '${_buildPrompt(goal, history, steps)}\n\nپاسخ قبلی JSON معتبر نبود. فقط JSON بده.')
              .timeout(stepTimeout);
          final m2 = _parse(raw2);
          if (m2 == null) throw StateError('bad_json');
          final r = await _handle(m2, i, steps);
          if (r != null) return r;
          continue;
        }
        final r = await _handle(m, i, steps);
        if (r != null) return r;
      }
      // مراحل تمام شد: از روی مشاهدات جمع‌بندی کن
      if (steps.any((s) => s.observation != null)) {
        final sum = await llm(
                '${_buildPrompt(goal, history, steps)}\n\nمراحل تمام شد. فقط بر اساس «نتیجه»های بالا، پاسخ نهایی فارسی بده (متن ساده، نه JSON).')
            .timeout(stepTimeout);
        return AgentResult(sum.trim(), steps);
      }
    } catch (_) {
      // خطای شبکه/زمان/JSON → برگرد به موتور آفلاین
    }
    final off = await offlineFallback(goal);
    return AgentResult(off, steps, usedFallback: true);
  }

  Future<AgentResult?> _handle(
      Map<String, dynamic> m, int i, List<AgentStep> steps) async {
    final thought = (m['thought'] ?? '').toString();
    final action = (m['action'] ?? '').toString();

    if (action == 'final') {
      final ans = (m['answer'] ?? '').toString().trim();
      if (ans.isEmpty) throw StateError('empty_answer');
      final st = AgentStep(i, thought);
      steps.add(st);
      onStep?.call(st);
      return AgentResult(ans, steps);
    }

    final name = (m['tool'] ?? '').toString();
    final tool = tools.where((t) => t.name == name).cast<AgentTool?>().firstWhere(
          (t) => true,
          orElse: () => null,
        );
    String obs;
    if (tool == null) {
      obs = 'ابزار «$name» وجود ندارد. فقط از ابزارهای فهرست‌شده استفاده کن.';
    } else {
      try {
        final args = (m['args'] is Map)
            ? Map<String, dynamic>.from(m['args'] as Map)
            : <String, dynamic>{};
        obs = await tool.run(args).timeout(const Duration(seconds: 20));
        if (obs.length > 3000) obs = obs.substring(0, 3000);
      } catch (e) {
        obs = 'خطا در اجرای ابزار: $e';
      }
    }
    final st = AgentStep(i, thought, tool: name, observation: obs);
    steps.add(st);
    onStep?.call(st);
    return null;
  }
}

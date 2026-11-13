@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/intent_net.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/ui/chat_controller.dart';

/// ابزار بازبینی دستی: گفتگوهای واقعی را اجرا و خروجی را در فایل می‌نویسد.
///
/// اجرا: `AUDIT_OUT=/tmp/audit_out.txt flutter test test/audit/conversation_audit_test.dart`
/// ورودی پیش‌فرض `test/audit/conversations.txt` است (گفتگوها با سطر خالی جدا
/// می‌شوند). علاوه بر خروجی، بررسی می‌کند هیچ نوبتی بی‌پاسخ نماند.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('audit', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final engine = KnowledgeEngine();
    await engine.load();
    final repo = TemplateRepository();
    await repo.load();
    // همان طبقه‌بند نیتی که خودِ برنامه بار می‌کند، تا رونوشت‌ها با رفتار
    // برنامه روی گوشی یکی باشد.
    final net = IntentNet.fromJson(
      jsonDecode(File('assets/brain/intent_model.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final inputs = (Platform.environment['AUDIT_IN'] ??
            'test/audit/conversations.txt,test/audit/conversations_followup.txt')
        .split(',');
    final convs = [
      for (final p in inputs)
        ...File(p.trim()).readAsStringSync().split(RegExp(r'\n\s*\n')),
    ];
    final out = StringBuffer();
    var n = 0;
    for (final c in convs) {
      final turns = c.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (turns.isEmpty) continue;
      n++;
      final ctrl = ChatController(
        engine: engine,
        repo: repo,
        history: HistoryStore(),
        settings: AppSettings()
          ..saveHistory = false
          ..saveDraftProgress = false,
        intentNet: net,
      );
      out.writeln('=================== گفتگو $n');
      for (final t in turns) {
        final before = ctrl.messages.length;
        await ctrl.submit(t);
        out.writeln('👤 $t');
        for (final m in ctrl.messages.skip(before)) {
          if (m.fromUser) continue;
          out.writeln('🤖 ${m.isDoc ? "[سند] ${m.docTitle}" : m.text}');
          if (m.chips.isNotEmpty) out.writeln('   [چیپ‌ها] ${m.chips.join(" | ")}');
        }
        expect(ctrl.messages.length, greaterThan(before + 1),
            reason: 'بی‌پاسخ ماند: $t');
        out.writeln('---');
      }
      ctrl.dispose();
    }
    // گزارش «نظر دوم»: کدام جمله‌های مجموعهٔ آزمونِ طبقه‌بند را قاعده‌های
    // وکیل نشناخته بودند و طبقه‌بند پرونده‌شان را باز کرد.
    out.writeln('=================== نظر دوم طبقه‌بند نیت');
    var total = 0, byRules = 0, byNet = 0;
    for (final line
        in File('brain/eval/intent_eval.txt').readAsLinesSync()) {
      final i = line.indexOf('|');
      if (line.startsWith('#') || i <= 0) continue;
      final label = line.substring(0, i);
      final text = line.substring(i + 1).trim();
      total++;
      final plain = Advocate(engine)..respond(text);
      final hinted = Advocate(engine, intentNet: net)..respond(text);
      if (plain.file.topic.isNotEmpty) {
        byRules++;
      } else if (hinted.file.topic.isNotEmpty) {
        byNet++;
        out.writeln('[$label → ${hinted.file.topic}] $text');
      }
    }
    out.writeln('جمله‌ها: $total | قاعده‌ها باز کردند: $byRules | '
        'طبقه‌بند باز کرد: $byNet');
    File(Platform.environment['AUDIT_OUT'] ??
            '${Directory.systemTemp.path}/dastyar_audit_out.txt')
        .writeAsStringSync(out.toString());
  }, timeout: const Timeout(Duration(minutes: 10)));
}

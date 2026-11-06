@Tags(['slow'])
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/domain/assistant.dart';
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
        assistant: Assistant(engine),
        repo: repo,
        history: HistoryStore(),
        settings: AppSettings()
          ..saveHistory = false
          ..saveDraftProgress = false,
        random: Random(1),
        phraseSeed: 1,
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
    File(Platform.environment['AUDIT_OUT'] ??
            '${Directory.systemTemp.path}/dastyar_audit_out.txt')
        .writeAsStringSync(out.toString());
  }, timeout: const Timeout(Duration(minutes: 10)));
}

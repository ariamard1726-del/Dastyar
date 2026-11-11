import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/domain/assistant.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/ui/chat_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;
  late TemplateRepository repo;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    engine = KnowledgeEngine();
    await engine.load();
    repo = TemplateRepository();
    await repo.load();
  });

  ChatController makeCtrl() => ChatController(
        engine: engine,
        assistant: Assistant(engine),
        repo: repo,
        history: HistoryStore(),
        settings: AppSettings()
          ..saveHistory = false
          ..saveDraftProgress = false,
        random: Random(1),
      );

  group('end of counseling resets flow memory', () {
    test('after end command isCounseling is false', () async {
      final ChatController ctrl = makeCtrl();
      await ctrl.submit('شوهرم مهریه‌م رو نمی‌ده');
      expect(ctrl.isCounseling, isTrue);

      await ctrl.submit('پایان مشاوره');

      expect(ctrl.isCounseling, isFalse);
      ctrl.dispose();
    });

    test('dowry then end then cheque: answer has no dowry leftovers', () async {
      final ChatController ctrl = makeCtrl();
      await ctrl.submit('شوهرم مهریه‌م رو نمی‌ده');
      await ctrl.submit('پایان مشاوره');
      await ctrl.submit('چک‌م گم شده، چیکار کنم؟');

      final String t = ctrl.messages.last.text;
      expect(t, isNot(contains('عقدنامه')));
      expect(t, isNot(contains('مهریه')));
      expect(t, isNot(contains('زوجه')));
      ctrl.dispose();
    });

    test('safety: without end command cheque counseling continues', () async {
      final ChatController ctrl = makeCtrl();
      await ctrl.submit('چک‌م برگشت خورده');
      expect(ctrl.isCounseling, isTrue);

      await ctrl.submit('بدهی قطعی بوده');

      expect(ctrl.isCounseling, isTrue);
      ctrl.dispose();
    });
  });
}

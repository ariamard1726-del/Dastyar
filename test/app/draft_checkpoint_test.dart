import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/ui/chat_controller.dart';

List<LegalTemplate> _loadTemplatesSync() {
  final out = <LegalTemplate>[];
  for (final f in Directory('assets/templates').listSync()) {
    if (f is File && f.path.endsWith('.json')) {
      final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      out.add(LegalTemplate.fromJson(m));
    }
  }
  out.sort((a, b) => a.id.compareTo(b.id));
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;
  late List<LegalTemplate> templates;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
    templates = _loadTemplatesSync();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ذخیرهٔ رمزنگاری‌شدهٔ پیش‌نویس ناتمام', () {
    test('DraftCheckpointStore و ChatController پیش‌نویس ناتمام را رمزنگاری، بازیابی و پاک می‌کنند', () async {
      final repo = TemplateRepository()..templates.addAll(templates);
      final settings = AppSettings()
        ..saveHistory = false
        ..saveDraftProgress = true;

      final ctrl1 = ChatController(
        engine: engine,
        repo: repo,
        history: HistoryStore(),
        settings: settings,
      );

      await ctrl1.submit('دادخواست مطالبهٔ وجه');
      expect(ctrl1.isDrafting, isTrue);
      await ctrl1.submit('تهران');
      final saved = await ctrl1.saveDraftCheckpoint();
      expect(saved, isTrue);

      final prefs = await SharedPreferences.getInstance();
      final rawCipher = prefs.getString('active_draft_v1') ?? '';
      expect(rawCipher, isNotEmpty);
      expect(rawCipher.contains('تهران'), isFalse); // رمزنگاری شده است

      ctrl1.dispose();

      final ctrl2 = ChatController(
        engine: engine,
        repo: repo,
        history: HistoryStore(),
        settings: settings,
      );
      final restored = await ctrl2
          .restoreDraftCheckpoint()
          .timeout(const Duration(seconds: 5));
      expect(restored, isTrue);
      expect(ctrl2.isDrafting, isTrue);
      expect(ctrl2.draft?.values['court_city'], 'تهران');
      expect(ctrl2.messages.last.text, contains('بازیابی شد'));

      await ctrl2.submit(DraftCmd.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await DraftCheckpointStore.load(templates), isNull);
      ctrl2.dispose();
    });
  });
}

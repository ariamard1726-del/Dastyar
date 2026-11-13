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

  ChatController make({HistoryStore? history, bool saveHistory = false}) {
    return ChatController(
      engine: engine,
      repo: TemplateRepository()..templates.addAll(templates),
      history: history ?? HistoryStore(),
      settings: AppSettings()..saveHistory = saveHistory,
    );
  }

  group('کنترلر گفتگو: فقط یک مسیر (وکیل + تنظیم سند)', () {
    test('پرسش عادی پاسخ می‌گیرد و در تاریخچه ذخیره می‌شود', () async {
      final history = HistoryStore();
      await history.load();
      final ctrl = make(history: history, saveHistory: true);

      await ctrl.submit('ماده ۱۰ قانون مدنی');
      expect(ctrl.messages.length, 2);
      expect(ctrl.messages.first.fromUser, isTrue);
      expect(ctrl.messages.last.text, contains('قراردادهای خصوصی'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(history.sessions.length, 1);

      ctrl.dispose();
    });

    test('هر پیام را همان وکیل جواب می‌دهد و پرونده را به خاطر می‌سپارد',
        () async {
      final ctrl = make();
      await ctrl.submit('صاحبخونه پول پیشمو نمیده');
      expect(ctrl.advocate.file.topic, 'rent');
      expect(ctrl.messages.last.fromUser, isFalse);
      expect(ctrl.messages.last.laws, isNotEmpty);
      expect(ctrl.messages.last.chips, isNotEmpty);

      await ctrl.submit('۱۵۰ میلیون');
      expect(ctrl.advocate.file.n('amount'), 150000000);
      expect(ctrl.messages.length, 4);

      ctrl.newChat();
      expect(ctrl.messages, isEmpty);
      expect(ctrl.advocate.hasCase, isFalse);
      ctrl.dispose();
    });

    test('بازکردن گفتگوی ذخیره‌شده، حافظهٔ پرونده را از نو می‌سازد', () async {
      final ctrl = make();
      ctrl.loadSession(
        ChatSession(
          id: 's1',
          title: 'ودیعه',
          updated: 1,
          messages: [
            StoredMsg('صاحبخونه پول پیشمو نمیده', true),
            StoredMsg('پاسخ قبلی', false),
            StoredMsg('۱۵۰ میلیون', true),
            StoredMsg('پاسخ قبلی', false),
          ],
        ),
      );
      expect(ctrl.sessionId, 's1');
      expect(ctrl.messages.length, 4);
      expect(ctrl.messages.every((m) => m.revealed), isTrue);
      expect(ctrl.advocate.file.topic, 'rent');
      expect(ctrl.advocate.file.n('amount'), 150000000);
      ctrl.dispose();
    });

    test('لمس عنوان یک قالب، تنظیم همان سند را شروع می‌کند و انصراف به گفتگو برمی‌گردد',
        () async {
      final ctrl = make();
      await ctrl.submit('دادخواست مطالبهٔ وجه');
      expect(ctrl.isDrafting, isTrue);
      expect(ctrl.draft?.template.id, 'demand_money');

      await ctrl.submit(DraftCmd.cancel);
      expect(ctrl.isDrafting, isFalse);

      await ctrl.submit('چکم برگشت خورده');
      expect(ctrl.isDrafting, isFalse);
      expect(ctrl.advocate.file.topic, 'cheque');
      ctrl.dispose();
    });

    test('«برام بنویسش» سندی را شروع می‌کند که به همان پرونده می‌خورد', () async {
      final ctrl = make();
      await ctrl.submit('صاحبخونه پول پیشمو نمیده');
      final ids = ctrl.advocate.draftIds;
      expect(ids, isNotEmpty);
      await ctrl.submit('برام بنویسش');
      expect(ctrl.isDrafting, isTrue);
      expect(ctrl.draft?.template.id, ids.first);
      // پرونده با شروع سند از بین نمی‌رود.
      expect(ctrl.advocate.file.topic, 'rent');
      ctrl.dispose();
    });

    test('«نه» در پاسخ به «کدام متن؟» هیچ سندی را شروع نمی‌کند', () async {
      final ctrl = make();
      await ctrl.submit('برام بنویسش');
      expect(ctrl.pendingChoices, isNotEmpty);
      expect(ctrl.messages.last.text, Drafting.chooseText);
      // «نه» درون عنوان «دادخواست اعسار از هزینهٔ دادرسی» هم هست.
      await ctrl.submit('نه');
      expect(ctrl.isDrafting, isFalse);
      expect(ctrl.pendingChoices, isEmpty);

      await ctrl.submit('برام بنویسش');
      await ctrl.submit('اعسار');
      expect(ctrl.draft?.template.id, 'insolvency');
      ctrl.dispose();
    });

    test('مبلغی که در گفتگو گفته شده، در فیلد مبلغ سند به ریال پیشنهاد می‌شود',
        () async {
      final ctrl = make();
      await ctrl.submit('صاحبخونه پول پیشمو نمیده');
      await ctrl.submit('۱۵۰ میلیون');
      await ctrl.submit('دادخواست مطالبهٔ وجه');
      expect(ctrl.isDrafting, isTrue);
      const answers = [
        'تهران',
        'علی رضایی',
        'تهران، خیابان آزادی، پلاک ۱۰',
        DraftCmd.skip,
        'حسن احمدی',
        'کرج، خیابان اصلی، پلاک ۵',
      ];
      for (final a in answers) {
        if (ctrl.draft?.current?.id == 'amount') break;
        await ctrl.submit(a);
      }
      expect(ctrl.draft?.current?.id, 'amount');
      // ۱۵۰ میلیون تومان = ۱٬۵۰۰ میلیون ریال.
      expect(ctrl.messages.last.chips, contains('۱۵۰۰۰۰۰۰۰۰'));
      ctrl.dispose();
    });
  });
}

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/history.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/core/privacy.dart';
import 'package:dastyar/domain/feedback.dart';
import 'package:dastyar/domain/settings.dart';

import '../support/keystore_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('برش ایمن یونیکد و رمزنگاری فقط با Keystore (بدون کلید جایگزین)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      clearKeystoreMock();
    });

    tearDown(clearKeystoreMock);

    test('PersianText.truncate جفت‌های جایگزین (ایموجی) را از وسط نصف نمی‌کند', () {
      final text = '${'الف' * 13}😀انتها';
      final title = HistoryStore.makeTitle(text);
      expect(() => utf8.encode(title), returnsNormally);
      expect(title.endsWith('...'), isTrue);
      expect(title, contains('😀'));

      const shortEmoji = '😀😀😀';
      expect(PersianText.truncate(shortEmoji, 2, ellipsis: '…'), '😀😀…');
    });

    test('نبود/خطای Keystore ذخیره را متوقف می‌کند و هیچ کلیدی کنار داده نوشته نمی‌شود', () async {
      clearKeystoreMock(); // معادل MissingPluginException
      await expectLater(
        PrivacyService.seal('دادهٔ حساس'),
        throwsA(isA<KeystoreUnavailableException>()),
      );

      final store = HistoryStore();
      await store.load();
      await store.upsert(
        ChatSession(
          id: 's1',
          title: 'پرسش محرمانه',
          updated: 100,
          messages: [StoredMsg('متن محرمانهٔ پروندهٔ چک', true)],
        ),
      );
      expect(await FeedbackStore.add('پرسش خصوصی', 'پاسخ', -1), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('history_v1'), isNull);
      expect(prefs.getString('feedback_v1'), isNull);
      expect(prefs.getString('__dastyar_local_key_v1'), isNull);
      expect(prefs.getKeys().any((k) => k.contains('key')), isFalse);
      expect((await FeedbackStore.all()).isEmpty, isTrue);
    });

    test('خطای صریح کانال Keystore هم ذخیره را متوقف می‌کند', () async {
      mockKeystore(fail: true);
      await expectLater(
        PrivacyService.seal('دادهٔ حساس'),
        throwsA(isA<KeystoreUnavailableException>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('history_v1'), isNull);
      expect(prefs.getString('__dastyar_local_key_v1'), isNull);
    });

    test('داده‌های رمزنگاری جایگزین حذف‌شده قابل‌بازیابی نیستند', () async {
      mockKeystore();
      expect(PrivacyService.isEncrypted('encf1:AAAA'), isFalse);
      expect(await PrivacyService.open('encf1:AAAA'), isNull);
      expect(PrivacyService.isEncrypted('enc1:AAAA'), isTrue);
      // بدون کانال بومی، حتی پیام enc1 هم باز نمی‌شود و متن آزاد برنمی‌گردد.
      clearKeystoreMock();
      expect(await PrivacyService.open('enc1:AAAA'), isNull);
    });

    test('با Keystore، HistoryStore و FeedbackStore رمزنگاری و بازیابی می‌شوند', () async {
      mockKeystore();
      final store = HistoryStore();
      await store.load();
      await store.upsert(
        ChatSession(
          id: 's1',
          title: 'پرسش محرمانه',
          updated: 100,
          messages: [StoredMsg('متن محرمانهٔ پروندهٔ چک', true)],
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final rawHistory = prefs.getString('history_v1')!;
      expect(PrivacyService.isEncrypted(rawHistory), isTrue);
      expect(rawHistory.startsWith(PrivacyService.nativePrefix), isTrue);
      expect(rawHistory.contains('متن محرمانهٔ پروندهٔ چک'), isFalse);
      expect(prefs.getString('__dastyar_local_key_v1'), isNull);

      final reloaded = HistoryStore();
      await reloaded.load();
      expect(reloaded.sessions.length, 1);
      expect(reloaded.sessions.first.messages.first.text,
          'متن محرمانهٔ پروندهٔ چک');

      const flipIdx = PrivacyService.nativePrefix.length + 1;
      final flippedChar = rawHistory[flipIdx] == 'A' ? 'B' : 'A';
      final tampered =
          '${rawHistory.substring(0, flipIdx)}$flippedChar${rawHistory.substring(flipIdx + 1)}';
      final original = await PrivacyService.open(rawHistory);
      expect(await PrivacyService.open(tampered), isNot(original));

      final saved = await FeedbackStore.add('پرسش خصوصی', 'پاسخ آزمایشی', -1);
      expect(saved, isTrue);
      final rawFeedback = prefs.getString('feedback_v1')!;
      expect(PrivacyService.isEncrypted(rawFeedback), isTrue);
      expect(rawFeedback.contains('پرسش خصوصی'), isFalse);

      final entries = await FeedbackStore.all();
      expect(entries.length, 1);
      expect(entries.first.q, 'پرسش خصوصی');
    });

    test('مهاجرت داده‌های قدیمیِ رمزنشده فقط با Keystore انجام می‌شود', () async {
      final legacyHistory = jsonEncode([
        {
          'id': 'legacy-1',
          'title': 'گفتگوی قدیمی',
          'updated': 42,
          'messages': [
            {'t': 'سلام قدیمی', 'u': true},
          ],
        },
      ]);
      final legacyFeedback = jsonEncode([
        {'q': 'سؤال قدیمی', 'a': 'جواب قدیمی', 'v': 1, 't': 10},
      ]);
      SharedPreferences.setMockInitialValues(<String, Object>{
        'history_v1': legacyHistory,
        'feedback_v1': legacyFeedback,
      });

      // بدون Keystore، متن قدیمی خوانده می‌شود ولی دوباره ذخیره نمی‌شود.
      clearKeystoreMock();
      final noKeystore = HistoryStore();
      await noKeystore.load();
      expect(noKeystore.sessions.length, 1);
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('history_v1'), legacyHistory);

      // با Keystore، همان داده رمزنگاری و جایگزین می‌شود.
      mockKeystore();
      final store = HistoryStore();
      await store.load();
      expect(store.sessions.length, 1);
      expect(store.sessions.first.title, 'گفتگوی قدیمی');
      final fb = await FeedbackStore.all();
      expect(fb.length, 1);
      expect(fb.first.q, 'سؤال قدیمی');

      prefs = await SharedPreferences.getInstance();
      expect(PrivacyService.isEncrypted(prefs.getString('history_v1')!), isTrue);
      expect(PrivacyService.isEncrypted(prefs.getString('feedback_v1')!), isTrue);
    });

    test('اتصال کانال بومی اندروید برای Keystore، کلیپ‌بورد حساس و FLAG_SECURE', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PrivacyService.channel, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'seal':
            final t = (call.arguments as Map)['text'] as String;
            return 'enc1:${base64Encode(utf8.encode(t))}';
          case 'open':
            final p = (call.arguments as Map)['payload'] as String;
            return utf8.decode(base64Decode(p.substring(5)));
          case 'copySensitive':
          case 'setSecureScreen':
            return true;
          default:
            return null;
        }
      });

      final sealed = await PrivacyService.seal('دادهٔ حساس');
      expect(sealed.startsWith('enc1:'), isTrue);
      expect(await PrivacyService.open(sealed), 'دادهٔ حساس');

      await PrivacyService.copyText('متن دادخواست با کد ملی', sensitive: true);
      final settings = await AppSettings.load();
      await settings.setSecureScreen(true);

      final methods = calls.map((c) => c.method).toList();
      expect(
        methods,
        containsAll(<String>['seal', 'open', 'copySensitive', 'setSecureScreen']),
      );
      expect(settings.secureScreen, isTrue);
    });
  });
}

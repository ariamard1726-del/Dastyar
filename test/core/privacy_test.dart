import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/history.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/core/privacy.dart';
import 'package:dastyar/domain/feedback.dart';
import 'package:dastyar/domain/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('برش ایمن یونیکد، رمزنگاری محلی، مهاجرت خودکار و کانال حریم خصوصی', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PrivacyService.channel, null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PrivacyService.channel, null);
    });

    test('PersianText.truncate جفت‌های جایگزین (ایموجی) را از وسط نصف نمی‌کند', () {
      // هر ایموجی 😀 دو واحد UTF-16 دارد اما یک Rune است
      final text = '${'الف' * 13}😀انتها'; // 39 نویسه + ایموجی در جایگاه 40ام
      final title = HistoryStore.makeTitle(text);
      // رشته باید UTF-8 معتبر باشد و jsonEncode روی آن خطا ندهد
      expect(() => utf8.encode(title), returnsNormally);
      expect(title.endsWith('...'), isTrue);
      expect(title, contains('😀'));

      const shortEmoji = '😀😀😀';
      expect(PersianText.truncate(shortEmoji, 2, ellipsis: '…'), '😀😀…');
    });

    test('SHA-256 داخلی با بردار استاندارد NIST مطابقت دارد', () {
      final digest = PrivacyService.sha256(utf8.encode('abc'));
      final hex =
          digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(
        hex,
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('HistoryStore و FeedbackStore داده‌ها را رمزنگاری می‌کنند و دستکاری را تشخیص می‌دهند', () async {
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
      final rawHistory = prefs.getString('history_v1');
      expect(PrivacyService.isEncrypted(rawHistory), isTrue);
      expect(rawHistory.contains('متن محرمانهٔ پروندهٔ چک'), isFalse);

      final reloaded = HistoryStore();
      await reloaded.load();
      expect(reloaded.sessions.length, 1);
      expect(reloaded.sessions.first.messages.first.text, 'متن محرمانهٔ پروندهٔ چک');

      // دستکاری متن رمزشده باید توسط برچسب احراز هویت (HMAC) رد شود
      const flipIdx = PrivacyService.fallbackPrefix.length + 24;
      final flippedChar = rawHistory[flipIdx] == 'A' ? 'B' : 'A';
      final tampered =
          '${rawHistory.substring(0, flipIdx)}$flippedChar${rawHistory.substring(flipIdx + 1)}';
      expect(await PrivacyService.open(tampered), isNull);

      // بررسی رمزنگاری FeedbackStore
      final saved = await FeedbackStore.add('پرسش خصوصی', 'پاسخ آزمایشی', -1);
      expect(saved, isTrue);
      final rawFeedback = prefs.getString('feedback_v1');
      expect(PrivacyService.isEncrypted(rawFeedback), isTrue);
      expect(rawFeedback.contains('پرسش خصوصی'), isFalse);

      final entries = await FeedbackStore.all();
      expect(entries.length, 1);
      expect(entries.first.q, 'پرسش خصوصی');
    });

    test('مهاجرت خودکار داده‌های قدیمیِ رمزنشده در HistoryStore و FeedbackStore', () async {
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

      final store = HistoryStore();
      await store.load();
      expect(store.sessions.length, 1);
      expect(store.sessions.first.title, 'گفتگوی قدیمی');

      final fb = await FeedbackStore.all();
      expect(fb.length, 1);
      expect(fb.first.q, 'سؤال قدیمی');

      final prefs = await SharedPreferences.getInstance();
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

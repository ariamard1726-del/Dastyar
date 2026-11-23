import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/history.dart';
import 'package:dastyar/core/privacy.dart';

/// ذخیرهٔ افزایشی تاریخچه: هر گفتگو کلید خودش را دارد، نوشتن‌ها سریالی‌اند،
/// و یک رکورد خراب بقیه را از بین نمی‌برد.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  ChatSession session(String id, List<String> texts, {int updated = 1}) =>
      ChatSession(
        id: id,
        title: 'گفتگوی $id',
        updated: updated,
        messages: [for (final t in texts) StoredMsg(t, true)],
      );

  test('هر گفتگو جداگانه و رمزنگاری‌شده ذخیره می‌شود', () async {
    final store = HistoryStore();
    await store.load();
    await store.upsert(session('s1', ['متن محرمانهٔ یک']));
    await store.upsert(session('s2', ['متن محرمانهٔ دو']));

    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getString('history_v1')!;
    expect(PrivacyService.isEncrypted(index), isTrue);
    expect(index.contains('متن محرمانهٔ یک'), isFalse);

    final one = prefs.getString('history_v1:m:s1')!;
    expect(PrivacyService.isEncrypted(one), isTrue);
    expect(one.contains('متن محرمانهٔ یک'), isFalse);

    final reloaded = HistoryStore();
    await reloaded.load();
    expect(reloaded.sessions.length, 2);
    expect(
      reloaded.sessions.map((s) => s.messages.first.text),
      containsAll(['متن محرمانهٔ یک', 'متن محرمانهٔ دو']),
    );
  });

  test('نوشتن یک گفتگو، بلوک گفتگوی دیگر را از نو رمز نمی‌کند', () async {
    final store = HistoryStore();
    await store.load();
    await store.upsert(session('s1', ['الف']));
    await store.upsert(session('s2', ['ب']));

    final prefs = await SharedPreferences.getInstance();
    final before = prefs.getString('history_v1:m:s2');

    await store.upsert(session('s1', ['الف', 'ج'], updated: 5));
    final after = prefs.getString('history_v1:m:s2');
    expect(identical(before, after) || before == after, isTrue);
  });

  test('نوشتن‌های پشت‌سرهم، نسخهٔ قدیمی را روی تازه نمی‌نشانند', () async {
    final store = HistoryStore();
    await store.load();

    // دو نوشتن هم‌زمان برای یک گفتگو؛ نوشتن دوم کامل‌تر است.
    final first = store.upsert(session('s1', ['یک']));
    final second = store.upsert(session('s1', ['یک', 'دو'], updated: 9));
    await Future.wait([first, second]);
    await store.flush();

    final reloaded = HistoryStore();
    await reloaded.load();
    expect(reloaded.sessions.single.messages.length, 2);
    expect(reloaded.sessions.single.updated, 9);
  });

  test('رکورد خراب یک گفتگو، بقیهٔ تاریخچه را پاک نمی‌کند', () async {
    final store = HistoryStore();
    await store.load();
    await store.upsert(session('s1', ['سالم']));
    await store.upsert(session('s2', ['خراب‌شدنی']));

    final prefs = await SharedPreferences.getInstance();
    // رشتهٔ رمزشدهٔ ناقص/دستکاری‌شده: باز نمی‌شود.
    await prefs.setString('history_v1:m:s2', '${PrivacyService.fallbackPrefix}AAAA');

    final reloaded = HistoryStore();
    await reloaded.load();
    expect(reloaded.sessions.length, 1);
    expect(reloaded.sessions.single.id, 's1');
    expect(reloaded.lastError, isNull);
  });

  test('قالب قدیمی (یک آرایهٔ کامل) به قالب افزایشی مهاجرت می‌کند', () async {
    final legacy = jsonEncode([
      {
        'id': 'old-1',
        'title': 'گفتگوی قدیمی',
        'updated': 7,
        'messages': [
          {'t': 'سلام قدیم', 'u': true},
        ],
      },
    ]);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'history_v1': legacy,
    });

    final store = HistoryStore();
    await store.load();
    expect(store.sessions.length, 1);
    expect(store.sessions.single.messages.single.text, 'سلام قدیم');

    final prefs = await SharedPreferences.getInstance();
    expect(PrivacyService.isEncrypted(prefs.getString('history_v1')!), isTrue);
    expect(prefs.getString('history_v1:m:old-1'), isNotNull);
  });

  test('حذف یک گفتگو، فقط کلید خودش را برمی‌دارد', () async {
    final store = HistoryStore();
    await store.load();
    await store.upsert(session('s1', ['الف']));
    await store.upsert(session('s2', ['ب']));

    await store.delete('s1');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('history_v1:m:s1'), isNull);
    expect(prefs.getString('history_v1:m:s2'), isNotNull);
    expect(store.sessions.length, 1);
  });

  test('تعداد پیام‌های هر گفتگو به سقف محدود می‌شود', () async {
    final store = HistoryStore();
    await store.load();
    await store.upsert(
      session('s1', [for (var i = 0; i < 130; i++) 'پیام $i']),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(store.sessions.single.messages.length, HistoryStore.maxMessages);
    expect(prefs.getString('history_v1:m:s1'), isNotNull);
  });
}

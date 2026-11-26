import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/history.dart';
import 'package:dastyar/core/privacy.dart';
import 'package:dastyar/domain/draft_models.dart';
import 'package:dastyar/domain/feedback.dart';
import 'package:dastyar/domain/templates.dart';

/// وقتی Keystore در دسترس نیست، نباید با کلید موقت بنویسیم که فردا خوانده
/// نمیشود. پرچم [PrivacyService.persistenceAllowed] توسط `main` خاموش میشود.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PrivacyService.persistenceAllowed = true;
    PrivacyService.resetEphemeralKeyForTesting();
  });

  tearDown(() {
    PrivacyService.persistenceAllowed = true;
  });

  test('نبود کانال بومی، ذخیره را پیش از هر نوشتن خاموش میکند', () async {
    // در محیط آزمون کانال `probe` وجود ندارد؛ رفتار مورد انتظار همان رفتار
    // دستگاهی است که Keystore ندارد.
    expect(await PrivacyService.beginSession(), isFalse);
    expect(PrivacyService.persistenceAllowed, isFalse);
  });

  test('با قفل شدن ذخیره، هیچ رکورد تاریخچهای نوشته نمیشود', () async {
    PrivacyService.persistenceAllowed = false;
    final history = HistoryStore();
    await history.load();
    await history.upsert(ChatSession(
      id: 'locked',
      title: 'محرمانه',
      updated: 1,
      messages: [StoredMsg('پرسش محرمانه', true)],
    ));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('history_v1'), isFalse);
    expect(prefs.containsKey('history_v1:m:locked'), isFalse);
    expect(history.lastError, isNotNull);
  });

  test('با قفل شدن ذخیره، بازخورد و پیشنویس هم نوشته نمیشوند', () async {
    PrivacyService.persistenceAllowed = false;
    expect(await FeedbackStore.add('پرسش', 'پاسخ', -1), isFalse);
    final template = LegalTemplate.fromJson(<String, dynamic>{
      'id': 'complaint',
      'title': 'شکواییه',
      'body': 'متن',
      'fields': <dynamic>[],
    });
    expect(await DraftCheckpointStore.save(DraftSession(template)), isFalse);
  });

  test('محمولهٔ ناخوانای نسخهٔ قبل پاک میشود، نه اینکه بیصدا بماند', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('history_v1', '${PrivacyService.fallbackPrefix}!!!');
    final history = HistoryStore();
    await history.load();
    expect(prefs.containsKey('history_v1'), isFalse);
    expect(history.lastNotice, isNotNull);
  });
}

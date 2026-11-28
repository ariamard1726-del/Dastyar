import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// متنهای ثابتِ موضوع اجاره، جدا از منطق و closureها.
///
/// پیشتر ۴۲ رشتهٔ بلند در `rent_bodies.dart` و `rent_bodies_landlord.dart`،
/// ۸۷ رشته و ۳۲ برچسبِ سند در `rent_claims.dart`، ۱۳ متنِ طرحِ دعوا در
/// `rent_plan.dart` و متنِ پرسشها، بحثها، اثرها، فیلدهای سند و خلاصهٔ پرونده
/// در فایلهای `rent_*.dart` بودند؛
/// هر تغییرِ متن یعنی پچِ دارت و هیچ نگهبانِ خودکاری نمیتوانست بگوید که
/// متن عوض شده یا نه. اکنون مرجعِ متن همین فایل است (`texts`، `claims`،
/// `filings`، `plans`، `bodies`، `fills`، `prompts`، `effects`، `slots`،
/// `issues` و `recaps`) و کد فقط با شناسهٔ پایدار آنرا میخواند.
/// منطق، شرطها و جملهسازیهای وابسته به پرونده عمداً در Dart ماندهاند.
const String rentTextsAsset = 'assets/brain/topics/rent_texts.json';

/// فهرستِ نصبشده. تنها [loadRentTexts] آنرا پر میکند.
final Map<String, String> _rentTexts = <String, String>{};

/// متنِ بارگذاریشده را برای آزمون و عیبیابی میدهد (کپیِ غیرقابل تغییر).
Map<String, String> get loadedRentTexts => Map<String, String>.unmodifiable(_rentTexts);

/// خواندنِ رشتهٔ JSON و نصبِ متنها. خروجی فهرستِ شناسههاست.
List<String> parseRentTexts(String source) {
  final data = jsonDecode(source) as Map<String, dynamic>;
  if (data['v'] != 1) {
    throw StateError('$rentTextsAsset: نسخهٔ ناشناخته (${data['v']})');
  }
  // یازده جدولِ جدا، یک فهرستِ شناسه: پاسخ (`texts`)، ادعاها (`claims`)،
  // برچسبهای سند (`filings`)، طرحِ دعوا (`plans`)، پارههای توابع
  // (`bodies`)، فیلدهای سند (`fills`)، پرسشهای دکمهدار (`prompts`)،
  // اثرهای حقوقی (`effects`)، پرسشهای پرونده (`slots`)، بحثها و عنوان
  // (`issues`) و خلاصه و پایان طرح (`recaps`). نبودِ هریک خطای صریح است.
  final installed = <String, String>{};
  for (final section in const [
    'texts',
    'claims',
    'filings',
    'plans',
    'bodies',
    'fills',
    'prompts',
    'effects',
    'slots',
    'issues',
    'recaps',
    'fillOptions',
  ]) {
    final raw = data[section];
    if (raw is! Map) {
      throw StateError('$rentTextsAsset: فاقد فهرست $section');
    }
    if (raw.isEmpty) throw StateError('$rentTextsAsset: فهرست $section خالی است');
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! String || value.isEmpty) {
        throw StateError(
            '$rentTextsAsset: متنِ ${entry.key} خالی یا نامعتبر است');
      }
      final key = entry.key.toString();
      if (installed.containsKey(key)) {
        throw StateError('$rentTextsAsset: شناسهٔ تکراری «$key»');
      }
      installed[key] = value;
    }
  }
  _rentTexts
    ..clear()
    ..addAll(installed);
  return _rentTexts.keys.toList();
}

/// متن را از فایلِ دارایی میخواند و نصب میکند.
///
/// باید **پیش از** اولین پاسخِ وکیل اجرا شود: `main` و
/// `test/flutter_test_config.dart` هر دو آنرا صدا میزنند. نبودِ متن بیصدا
/// جایگزین نمیشود؛ [rentText] در چنین حالتی خطا میدهد.
Future<List<String>> loadRentTexts({AssetBundle? bundle}) async {
  final source = await (bundle ?? rootBundle).loadString(rentTextsAsset);
  return parseRentTexts(source);
}

/// متنِ یک شناسه. شناسهٔ ناشناخته یا بارگذارینشده، خطای صریح میدهد.
String rentText(String id) {
  final text = _rentTexts[id];
  if (text == null) {
    throw StateError('متنِ اجارهٔ «$id» بارگذاری نشده است؛ '
        ' loadRentTexts() پیش از پاسخدهی صدا زده نشده است.');
  }
  return text;
}

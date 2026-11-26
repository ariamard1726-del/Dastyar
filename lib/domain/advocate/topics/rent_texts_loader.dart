import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// متنهای ثابتِ موضوع اجاره، جدا از منطق و closureها.
///
/// پیشتر ۴۲ رشتهٔ بلند بهصورت `const String` در `rent_bodies.dart` و
/// `rent_bodies_landlord.dart` بودند؛ هر تغییرِ متن یعنی پچِ دارت و هیچ
/// نگهبانِ خودکاری نمیتوانست بگوید که متن عوض شده یا نه. اکنون مرجعِ
/// متن همین فایل است و کد فقط با شناسهٔ پایدار آنرا میخواند. منطق، شرطها
/// و جملهسازیهای وابسته به پرونده عمداً در Dart ماندهاند.
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
  final raw = data['texts'];
  if (raw is! Map) throw StateError('$rentTextsAsset: فاقد فهرست texts');
  _rentTexts.clear();
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is! String || value.isEmpty) {
      throw StateError('$rentTextsAsset: متنِ ${entry.key} خالی یا نامعتبر است');
    }
    _rentTexts[entry.key.toString()] = value;
  }
  if (_rentTexts.isEmpty) throw StateError('$rentTextsAsset خالی است');
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

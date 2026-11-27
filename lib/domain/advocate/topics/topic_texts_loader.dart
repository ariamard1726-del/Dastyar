import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// متنهای ثابتِ موضوعهای وکیل (غیر از اجاره و ودیعه)، جدا از منطق و closureها.
///
/// فایلهای `shared.dart`، `labor_*.dart` و `family_*.dart` متنهای ثابتشان را
/// به جدولهای این دارایی (`shared`، `labor`، `family`) سپردهاند و کد فقط با
/// شناسهٔ پایدار از طریق [topicText] میخواند. منطق، شرطها، regexهای تشخیص و
/// درونیابیهای وابسته به پرونده در Dart ماندهاند.
const String topicTextsAsset = 'assets/brain/topic_texts.json';

/// بخشهای الزامی دارایی در این گام.
const List<String> topicTextSections = [
  'shared',
  'labor',
  'family',
];

/// فهرستِ نصبشده. تنها [parseTopicTexts] آنرا پر میکند.
final Map<String, String> _topicTexts = <String, String>{};

/// متنِ بارگذاریشده را برای آزمون و عیبیابی میدهد (کپیِ غیرقابل تغییر).
Map<String, String> get loadedTopicTexts =>
    Map<String, String>.unmodifiable(_topicTexts);

/// خواندنِ رشتهٔ JSON و نصبِ متنها. خروجی فهرستِ شناسههاست.
List<String> parseTopicTexts(String source) {
  final data = jsonDecode(source) as Map<String, dynamic>;
  if (data['v'] != 1) {
    throw StateError('$topicTextsAsset: نسخهٔ ناشناخته (${data['v']})');
  }
  final installed = <String, String>{};
  for (final section in topicTextSections) {
    final raw = data[section];
    if (raw is! Map) {
      throw StateError('$topicTextsAsset: فاقد فهرست $section');
    }
    if (raw.isEmpty) {
      throw StateError('$topicTextsAsset: فهرست $section خالی است');
    }
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! String || value.isEmpty) {
        throw StateError(
            '$topicTextsAsset: متنِ ${entry.key} خالی یا نامعتبر است');
      }
      final key = entry.key.toString();
      if (installed.containsKey(key)) {
        throw StateError('$topicTextsAsset: شناسهٔ تکراری «$key»');
      }
      installed[key] = value;
    }
  }
  _topicTexts
    ..clear()
    ..addAll(installed);
  return _topicTexts.keys.toList();
}

/// متن را از فایلِ دارایی میخواند و نصب میکند.
///
/// باید **پیش از** اولین پاسخِ وکیل اجرا شود: `main` و
/// `test/flutter_test_config.dart` هر دو آنرا صدا میزنند. نبودِ متن بیصدا
/// جایگزین نمیشود؛ [topicText] در چنین حالتی خطا میدهد.
Future<List<String>> loadTopicTexts({AssetBundle? bundle}) async {
  final source = await (bundle ?? rootBundle).loadString(topicTextsAsset);
  return parseTopicTexts(source);
}

/// متنِ یک شناسه. شناسهٔ ناشناخته یا بارگذارینشده، خطای صریح میدهد.
String topicText(String id) {
  final text = _topicTexts[id];
  if (text == null) {
    throw StateError('متنِ موضوع «$id» بارگذاری نشده است؛ '
        'loadTopicTexts() پیش از پاسخدهی صدا زده نشده است.');
  }
  return text;
}

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// متنهای ثابتِ لایهٔ گفت‌وگو و استدلالِ وکیل (خارج از موضوعها).
///
/// واژه‌نامه (`glossary.dart`)، عبارت‌های چرخشی (`phrases.dart`)، ایمنی،
/// راهنما، پاسخ‌های عمومی و جمله‌بندیِ استدلال، متنشان را به جدولهای این
/// دارایی سپردهاند و کد از طریق [advocateText]، [advocateFormat] و
/// [advocateTextSeq] میخواند. قواعد، regexها، ترتیبِ کاندیدها و منطقِ
/// تصمیمگیری در Dart ماندهاند.
const String advocateTextsAsset = 'assets/brain/advocate_texts.json';

/// بخشهای الزامی داراییِ متنهای عمومیِ وکیل.
const List<String> advocateTextSections = [
  'glossary',
  'phrases',
  'constants',
  'voice',
  'understanding',
  'safety',
  'meta',
  'talk_route',
  'talk_reply',
  'talk_data',
  'reply_routes',
  'case_text',
  'argue',
  'law_answer',
  'term_reply',
  'guide_reply',
  'case_answer',
  'reply_pipeline',
];

final RegExp _paramPattern = RegExp(r'\{([a-zA-Z0-9_]+)\}');

/// فهرستِ نصبشده. تنها [parseAdvocateTexts] آنرا پر میکند.
final Map<String, String> _advocateTexts = <String, String>{};

/// متنِ بارگذاریشده را برای آزمون و بررسیِ استنادها میدهد (کپیِ غیرقابل تغییر).
Map<String, String> get loadedAdvocateTexts =>
    Map<String, String>.unmodifiable(_advocateTexts);

/// خواندنِ رشتهٔ JSON و نصبِ متنها. خروجی فهرستِ شناسههاست.
List<String> parseAdvocateTexts(String source) {
  final data = jsonDecode(source) as Map<String, dynamic>;
  if (data['v'] != 1) {
    throw StateError('$advocateTextsAsset: نسخهٔ ناشناخته (${data['v']})');
  }
  final installed = <String, String>{};
  for (final section in advocateTextSections) {
    final raw = data[section];
    if (raw is! Map) {
      throw StateError('$advocateTextsAsset: فاقد فهرست $section');
    }
    if (raw.isEmpty) {
      throw StateError('$advocateTextsAsset: فهرست $section خالی است');
    }
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! String || value.isEmpty) {
        throw StateError(
            '$advocateTextsAsset: متنِ ${entry.key} خالی یا نامعتبر است');
      }
      final key = entry.key.toString();
      if (installed.containsKey(key)) {
        throw StateError('$advocateTextsAsset: شناسهٔ تکراری «$key»');
      }
      installed[key] = value;
    }
  }
  _advocateTexts
    ..clear()
    ..addAll(installed);
  return _advocateTexts.keys.toList();
}

/// متن را از فایلِ دارایی میخواند و نصب میکند.
///
/// باید **پیش از** اولین پاسخِ وکیل اجرا شود: `main` و
/// `test/flutter_test_config.dart` هر دو آنرا صدا میزنند. نبودِ متن بیصدا
/// جایگزین نمیشود؛ [advocateText] در چنین حالتی خطا میدهد.
Future<List<String>> loadAdvocateTexts({AssetBundle? bundle}) async {
  final source = await (bundle ?? rootBundle).loadString(advocateTextsAsset);
  return parseAdvocateTexts(source);
}

/// متنِ یک شناسه. شناسهٔ ناشناخته یا بارگذارینشده، خطای صریح میدهد.
String advocateText(String id) {
  final text = _advocateTexts[id];
  if (text == null) {
    throw StateError('متنِ وکیل «$id» بارگذاری نشده است؛ '
        'loadAdvocateTexts() پیش از پاسخدهی صدا زده نشده است.');
  }
  return text;
}

/// جایگذاری تک‌گذرهٔ `{کلید}` در متنِ آماده، بی‌خطر در برابر تداخلِ مقدارها.
String advocateFormat(String id, Map<String, String> params) =>
    advocateText(id).replaceAllMapped(
      _paramPattern,
      (m) => params[m[1]!] ?? m[0]!,
    );

/// فهرستِ مرتبِ `prefix_0 .. prefix_{count-1}` از دارایی.
List<String> advocateTextSeq(String prefix, int count) => [
      for (var i = 0; i < count; i++) advocateText('${prefix}_$i'),
    ];

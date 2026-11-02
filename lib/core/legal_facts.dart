import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// یک «واقعیت حقوقی»: جمله‌ای که ادعا، مهلت یا مجازاتی را بیان می‌کند.
///
/// متن این جمله‌ها فقط در `assets/legal_facts.json` نگهداری می‌شود؛ کد هیچ
/// ادعای حقوقی‌ای را درون خود hardcoded نمی‌کند تا اصلاح/تأیید منابع بدون
/// تغییر کد ممکن باشد. تا وقتی منابع رسمی تأیید نشده‌اند، نباید هیچ جمله‌ای
/// به‌عنوان حکم قطعی نشان داده شود.
class LegalFact {
  final String id;
  final String block;
  final int order;
  final String claimText;
  final String lawName;
  final String articleNumber;
  final String separatorAfter;

  const LegalFact({
    required this.id,
    required this.block,
    required this.order,
    required this.claimText,
    required this.lawName,
    required this.articleNumber,
    required this.separatorAfter,
  });

  factory LegalFact.fromJson(Map<String, dynamic> j) => LegalFact(
        id: (j['id'] ?? '').toString(),
        block: (j['block'] ?? '').toString(),
        order: (j['order'] is int) ? j['order'] as int : 0,
        claimText: (j['claim_text'] ?? '').toString(),
        lawName: (j['law_name'] ?? '').toString(),
        articleNumber: (j['article_number'] ?? '').toString(),
        separatorAfter: (j['separator_after'] ?? '').toString(),
      );

  bool get isValid =>
      id.isNotEmpty &&
      block.isNotEmpty &&
      claimText.isNotEmpty &&
      lawName.isNotEmpty &&
      articleNumber.isNotEmpty;
}

/// مخزن داده\u200cمحور جمله\u200cهای حقوقی.
///
/// [KnowledgeEngine.load] این فایل را یک\u200cبار همراه سایر دارایی\u200cها می\u200cخواند؛
/// کد (مثلاً `LegalCounselor`) فقط با شناسهٔ بلاک از [block] متن می\u200cگیرد.
/// اگر دارایی بارگذاری نشده یا شناسه\u200cای ناشناخته باشد، به\u200cجای حدس زدن،
/// جملهٔ امن [unverified] برگردانده می\u200cشود.
class LegalFacts {
  LegalFacts._();

  static final LegalFacts instance = LegalFacts._();

  static const String assetPath = 'assets/legal_facts.json';

  static const String unverified =
      'اطلاعات حقوقی این مورد هنوز از منبع رسمی تأیید نشده است؛ لطفاً متن قانون را از منبع رسمی بررسی کنید.';

  final Map<String, LegalFact> _byId = {};
  final Map<String, List<LegalFact>> _blocks = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;
  int get length => _byId.length;
  List<String> get blockIds => List<String>.unmodifiable(_blocks.keys);

  Future<void> load() async {
    final raw = await rootBundle.loadString(assetPath);
    loadFromJson(raw);
  }

  /// خطاهای ساختار فایل پرتاب می\u200cشوند تا لایهٔ بارگذاری بتواند آن\u200cها را
  /// در `KnowledgeEngine.warnings` ثبت کند (بی\u200cصدا رد نشوند).
  void loadFromJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> || decoded['facts'] is! List) {
      throw const FormatException('legal_facts.json: فهرست facts پیدا نشد');
    }
    final nextById = <String, LegalFact>{};
    final nextBlocks = <String, List<LegalFact>>{};
    for (final item in decoded['facts'] as List) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('legal_facts.json: یک رکورد نادرست است');
      }
      final f = LegalFact.fromJson(item);
      if (!f.isValid || nextById.containsKey(f.id)) {
        throw FormatException('legal_facts.json: رکورد نادرست یا تکراری: ${f.id}');
      }
      nextById[f.id] = f;
      nextBlocks.putIfAbsent(f.block, () => <LegalFact>[]).add(f);
    }
    for (final list in nextBlocks.values) {
      list.sort((a, b) => a.order.compareTo(b.order));
    }
    _byId
      ..clear()
      ..addAll(nextById);
    _blocks
      ..clear()
      ..addAll(nextBlocks);
    _loaded = true;
  }

  void clear() {
    _byId.clear();
    _blocks.clear();
    _loaded = false;
  }

  LegalFact? fact(String id) => _byId[id];

  bool hasBlock(String id) => _blocks.containsKey(id);

  /// متن کامل یک بلاک (چند جملهٔ پی\u200cدرپی) با جداکننده\u200cهای ذخیره\u200cشده در JSON.
  String block(String id) {
    final list = _blocks[id];
    if (list == null || list.isEmpty) return unverified;
    final sb = StringBuffer();
    for (final f in list) {
      sb.write(f.claimText);
      sb.write(f.separatorAfter);
    }
    return sb.toString();
  }
}

import 'package:dastyar/core/persian_text.dart';

/// یک پرسش‌وپاسخ از بانک، همراه با استنادهایی به مادهٔ مشخص قانون.
class QaItem {
  final String id;
  final String category;
  final String question;
  final String answer;

  /// استنادها به شکل `قانون:شماره‌ماده`، مثلاً `landlord_tenant:4`.
  final List<String> refs;

  final Set<String> _tokens;

  QaItem({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    required this.refs,
  }) : _tokens = PersianText.tokenize(question).toSet();
}

/// بانک پرسش‌وپاسخ حقوقی (فعلاً اجاره). منطق خالص و بدون وابستگی به فلاتر؛
/// بارگذاری فایل در [KnowledgeEngine.load] انجام می‌شود.
class QaBank {
  QaBank._(this.items, this.lawTitles, this.disclaimer);

  static final QaBank empty = QaBank._(const [], const {}, '');

  final List<QaItem> items;
  final Map<String, String> lawTitles;
  final String disclaimer;

  /// کمترین نسبت واژه‌های پرسش که باید در متن کاربر باشد.
  static const double minRatio = 0.6;

  /// کمترین تعداد واژهٔ مشترک؛ جلوی تطبیق با یک واژهٔ کلیدی را می‌گیرد.
  static const int minShared = 2;

  /// ساخت از JSON دیکد‌شده. ورودی نامعتبر، بانک خالی برمی‌گرداند.
  factory QaBank.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return empty;
    final rawItems = json['items'];
    if (rawItems is! List) return empty;
    final titles = <String, String>{};
    final rawTitles = json['law_titles'];
    if (rawTitles is Map) {
      for (final entry in rawTitles.entries) {
        titles[entry.key.toString()] = entry.value.toString();
      }
    }
    final items = <QaItem>[];
    for (final e in rawItems) {
      if (e is! Map) continue;
      final refs = e['refs'];
      final q = (e['q'] ?? '').toString().trim();
      final a = (e['a'] ?? '').toString().trim();
      if (q.isEmpty || a.isEmpty) continue;
      items.add(QaItem(
        id: (e['id'] ?? '').toString(),
        category: (e['category'] ?? '').toString(),
        question: q,
        answer: a,
        refs: refs is List ? refs.map((r) => r.toString()).toList() : const [],
      ));
    }
    return QaBank._(
      List.unmodifiable(items),
      Map.unmodifiable(titles),
      (json['disclaimer'] ?? '').toString(),
    );
  }

  bool get isEmpty => items.isEmpty;

  /// نزدیک‌ترین پرسش بانک به متن کاربر، یا `null` اگر تطبیق کافی نباشد.
  QaItem? match(String text) {
    final words = PersianText.tokenize(text).toSet();
    if (words.isEmpty) return null;
    QaItem? best;
    var bestRatio = 0.0;
    var bestShared = 0;
    for (final it in items) {
      if (it._tokens.isEmpty) continue;
      final shared = it._tokens.where(words.contains).length;
      if (shared < minShared) continue;
      final ratio = shared / it._tokens.length;
      if (ratio < minRatio) continue;
      if (ratio > bestRatio || (ratio == bestRatio && shared > bestShared)) {
        best = it;
        bestRatio = ratio;
        bestShared = shared;
      }
    }
    return best;
  }

  /// پرسش‌های هم‌دسته با [it] که به آن نزدیک‌ترند (بیشترین واژهٔ مشترک)،
  /// بدون خود [it]. برای پیشنهاد دکمه‌ها زیر پاسخ به کار می‌رود.
  List<QaItem> related(QaItem it, {int max = 2}) {
    final base = it._tokens;
    final scored = <({QaItem item, int shared, int order})>[];
    for (var k = 0; k < items.length; k++) {
      final o = items[k];
      if (identical(o, it) || o.category != it.category) continue;
      final shared = o._tokens.where(base.contains).length;
      scored.add((item: o, shared: shared, order: k));
    }
    scored.sort((a, b) {
      final d = b.shared.compareTo(a.shared);
      return d != 0 ? d : a.order.compareTo(b.order);
    });
    return [for (final s in scored.take(max)) s.item];
  }

  /// نام خوانا برای یک استناد، مثلاً «ماده ۴ قانون روابط موجر و مستأجر».
  String citeLabel(String ref) {
    final cut = ref.indexOf(':');
    if (cut <= 0 || cut == ref.length - 1) return '';
    final law = ref.substring(0, cut);
    final num = ref.substring(cut + 1);
    final title = lawTitles[law] ?? law;
    return 'ماده ${_fa(num)} $title';
  }

  static String _fa(String s) {
    const latin = '0123456789';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final sb = StringBuffer();
    for (final ch in s.split('')) {
      final i = latin.indexOf(ch);
      sb.write(i < 0 ? ch : persian[i]);
    }
    return sb.toString();
  }
}

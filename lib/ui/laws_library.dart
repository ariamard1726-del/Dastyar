// بارگذاری، پارس و جست‌وجوی قوانین بسته‌بندی‌شده در برنامه.
//
// همهٔ فایل‌های قانون (در زمان اجرا) از `assets/laws/` خوانده می‌شوند؛ نه از
// شبکه و نه از فایل‌های بیرونی. نتیجهٔ پارس یک‌بار در [LawsLibrary] ذخیره
// می‌شود تا هر بار بازشدن دراور دوباره ۳ مگابایت متن را نپیماید.
//
// قانون‌ها به ترتیبی که در `laws_catalog.json` آمده‌اند فهرست می‌شوند.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:dastyar/core/persian_text.dart';

/// یک ماده (یا اصلِ قانون اساسی) با متن کامل.
class ArticleEntry {
  final String kind; // 'ماده' | 'اصل'
  final int number;
  final bool mokarrar;

  /// سرخطِ نمایشی با ارقام فارسی، مثلاً «ماده ۱۱۶۷» یا «اصل ۴۲».
  final String title;
  final String text;

  ArticleEntry({
    required this.kind,
    required this.number,
    required this.mokarrar,
    required this.title,
    required this.text,
  });

  /// متنِ کپی‌شونده: سرخط + متن.
  String get copyText => '$title\n$text';

  late final String _norm = _searchNormalize(text);

  /// نرمال‌شده برای جست‌وجو (یک‌بار محاسبه می‌شود و کش می‌شود).
  String get normText => _norm;
}

/// یک قانون کامل.
class LawEntry {
  final String id;
  final String title;
  final List<ArticleEntry> articles;

  const LawEntry({required this.id, required this.title, required this.articles});

  /// متنِ کپی‌شوندهٔ کل قانون: عنوان + تمام ماده‌ها پشت‌سرهم.
  String get fullCopyText {
    final b = StringBuffer(title)..write('\n\n');
    for (final a in articles) {
      b
        ..write(a.title)
        ..write('\n')
        ..write(a.text)
        ..write('\n\n');
    }
    return b.toString().trimRight();
  }
}

/// نتیجهٔ جست‌وجو: یا تطابق دقیقِ شمارهٔ ماده، یا پیشنهاد مرتبط.
class ArticleHit {
  final LawEntry law;
  final ArticleEntry article;
  final bool exact;
  final int score;

  /// واژهٔ حقوقی‌ای که این ماده به آن پیوند خورده (از `legal_terms.json`)،
  /// در صورت وجود.
  final String? tag;

  const ArticleHit({
    required this.law,
    required this.article,
    required this.exact,
    required this.score,
    this.tag,
  });
}

class LawsLibrary {
  static Future<List<LawEntry>>? _cache;

  /// نقطه ورودی آزمون‌ها برای پارس متنِ خام.
  static List<ArticleEntry> debugParseArticles(String raw) =>
      _parseArticles(raw);

  /// فهرست ۲۴ قانون؛ اولین فراخوانی پارس می‌کند و بعدها از کش برمی‌گرداند.
  static Future<List<LawEntry>> load() => _cache ??= _load();

  static Future<List<LawEntry>> _load() async {
    final catalogRaw = await rootBundle.loadString('assets/laws_catalog.json',
        cache: false);
    final metaRaw =
        await rootBundle.loadString('assets/laws/_meta.json', cache: false);
    final catalog = (jsonDecode(catalogRaw) as Map<String, dynamic>);
    final meta = (jsonDecode(metaRaw) as Map<String, dynamic>);
    final out = <LawEntry>[];
    for (final raw in (catalog['laws'] as List)) {
      final l = raw as Map<String, dynamic>;
      final id = l['id'].toString();
      final info = meta[id];
      final path = info is Map<String, dynamic> ? info['path']?.toString() : null;
      if (path == null) continue;
      final rawText =
          await rootBundle.loadString('assets/laws/$path', cache: false);
      out.add(LawEntry(
        id: id,
        title: l['title'].toString(),
        articles: _parseArticles(rawText),
      ));
    }
    return out;
  }

  /// پارس سربرگ‌های «ماده N» / «اصل N» (با مکرر اختیاری و برچسب اصلاحیِ
  /// داخل پرانتز). خط‌های دیگر متن هستند؛ عنوانی که پیش از اولین ماده آمده
  /// نادیده گرفته می‌شود (عنوان فایل)، ولی «## ...»های میانهٔ قانون حفظ
  /// می‌شوند چون متن حقوقی واقعیِ پیش از ماده‌شان هستند.
  static List<ArticleEntry> _parseArticles(String raw) {
    // سربرگ: شماره + مکرر اختیاری + پرانتزِ اصلاحی اختیاری — و هیچ متن دیگری.
    final head = RegExp(
      r'^(ماده|اصل)\s+([0-9۰-۹٠-٩]+)'
      r'(?:\s*مکرر(?:\s*[0-9۰-۹٠-٩]{1,2})?)?'
      r'(?:\s*\([^)\n]*\))?\s*$',
    );
    final mak = RegExp(r'مکرر');
    final out = <ArticleEntry>[];
    String? kind;
    int? number;
    var mok = false;
    var seenFirst = false;
    final body = <String>[];

    void flush() {
      final k = kind;
      final n = number;
      if (k == null || n == null) return;
      out.add(ArticleEntry(
        kind: k,
        number: n,
        mokarrar: mok,
        title:
            '$k ${PersianText.toFaDigits(n.toString())}${mok ? ' مکرر' : ''}',
        text: body.join('\n').trim(),
      ));
    }

    for (final line in raw.split('\n')) {
      final s = line.trimRight();
      final m = head.firstMatch(s);
      if (m != null) {
        flush();
        kind = m.group(1);
        number = int.parse(_toEnDigits(m.group(2)!));
        mok = mak.hasMatch(s);
        seenFirst = true;
        body.clear();
        continue;
      }
      if (!seenFirst) continue; // عنوان فایل پیش از اولین ماده
      body.add(line);
    }
    flush();
    return out;
  }
}

/// ارقام فارسی/عربی به لاتین.
String _toEnDigits(String input) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  var out = input;
  for (var i = 0; i < 10; i++) {
    out = out.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
  }
  return out;
}

/// نرمال‌سازی جست‌وجو و متن: رقم‌ها، ي/ك، اعراب و فاصله‌ها.
String _searchNormalize(String input) {
  var s = _toEnDigits(input);
  s = s
      .replaceAll('ك', 'ک')
      .replaceAll('ي', 'ی')
      .replaceAll('ى', 'ی')
      .replaceAll(RegExp(r'[ً-ٰٟـ]'), '') // اعراب و تطویل
      .replaceAll('\u200c', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return s;
}

/// جست‌وجوی ماده‌ها.
///
/// * اگر ورودی شامل ارقام باشد، ماده‌هایی با همان شماره (و همان مکرر)
///   «تطابق دقیق» می‌شوند.
/// * بقیهٔ واژه‌های غیرعددی، روی متن نرمال‌شده همهٔ ماده‌ها امتیاز می‌گیرند
///   (هر واژه در متن = ۲ امتیاز، در عنوان = ۳ امتیاز) و بهترین‌ها به‌عنوان
///   «مرتبط» برگردانده می‌شوند.
/// * اگر `legalTerms` داده شود (همان `assets/brain/legal_terms.json`)،
///   هر ورودی‌ای که عبارتش با ورودی کاربر بخواند، مادهٔ متناظرش با تگ
///   «واژهٔ حقوقی» و امتیاز ۹۰۰ به بالای مرتبط‌ها می‌آید.
List<ArticleHit> searchLaws(
  List<LawEntry> laws,
  String query, {
  int maxRelated = 8,
  List<Map<String, dynamic>>? legalTerms,
}) {
  final q = _searchNormalize(query);
  if (q.isEmpty) return const [];

  final numberMatch = RegExp(r'(?:ماده|اصل)?\s*([0-9]{1,4})\s*(مکرر)?').firstMatch(q);
  final wantNumber = numberMatch == null ? null : int.tryParse(numberMatch.group(1)!);
  final wantMok = numberMatch != null && numberMatch.group(2) != null;
  final isNumberQuery = wantNumber != null && RegExp(r'\d').hasMatch(q);

  const stop = {
    'و', 'از', 'به', 'در', 'را', 'که', 'با', 'تا', 'یا', 'بر', 'برای', 'هم',
    'است', 'شد', 'شود', 'این', 'آن', 'های', 'هایِ',
    // کلیدواژه‌های ساختاریِ قانون‌ها (در عنوان/سرخط همه تکرار می‌شوند):
    'ماده', 'اصل', 'مواد', 'قانون', 'لایحه', 'مکرر',
  };
  final tokens = q
      .split(' ')
      .where((t) =>
          t.length > 1 &&
          !RegExp(r'^[0-9]+$').hasMatch(t) &&
          !stop.contains(t))
      .toList();

  var hits = <ArticleHit>[];
  for (final law in laws) {
    for (final a in law.articles) {
      if (isNumberQuery && a.number == wantNumber && a.mokarrar == wantMok) {
        hits.add(ArticleHit(law: law, article: a, exact: true, score: 1000));
        continue;
      }
      if (tokens.isEmpty) continue;
      var score = 0;
      for (final t in tokens) {
        if (a.normText.contains(t)) score += 2;
        if (a.title.contains(t)) score += 3;
      }
      if (score >= 2) {
        hits.add(ArticleHit(law: law, article: a, exact: false, score: score));
      }
    }
  }
  if (legalTerms != null && !RegExp(r'^[0-9]+$').hasMatch(q)) {
    hits = _applyLegalTerms(laws, hits, legalTerms, q);
  }
  final exact = hits.where((h) => h.exact).toList();
  final related = hits.where((h) => !h.exact).toList()
    ..sort((a, b) => b.score.compareTo(a.score));
  return [...exact, ...related.take(maxRelated)];
}

/// «واژهٔ حقوقی»ها را با امتیاز ۹۰۰ تزریق می‌کند و تکراری‌ها را یکتا می‌کند.
List<ArticleHit> _applyLegalTerms(
  List<LawEntry> laws,
  List<ArticleHit> base,
  List<Map<String, dynamic>> entries,
  String q,
) {
  String keyOf(String lawId, ArticleEntry a) =>
      '$lawId#${a.number}#${a.mokarrar}';

  final boosted = <ArticleHit>[];
  final boostedKeys = <String>{};
  for (final e in entries) {
    final rawPhrases = (e['phrases'] as List?) ?? const [];
    final phrases = rawPhrases
        .map((x) => _searchNormalize(x.toString()))
        .where((p) => p.isNotEmpty)
        .toList();
    final matches = phrases.any(
        (p) => q.contains(p) || (q.length >= 3 && p.contains(q)));
    if (!matches) continue;

    final lawId = (e['law'] ?? '').toString();
    LawEntry? law;
    for (final l in laws) {
      if (l.id == lawId) {
        law = l;
        break;
      }
    }
    final titleMatch = RegExp(r'^(ماده|اصل)\s+([0-9۰-۹٠-٩]+)\s*(مکرر)?')
        .firstMatch((e['title'] ?? '').toString());
    if (law == null || titleMatch == null) continue;
    final wantNumber = int.tryParse(_toEnDigits(titleMatch.group(2)!));
    final wantMok = titleMatch.group(3) != null;
    ArticleEntry? target;
    for (final a in law.articles) {
      if (a.number == wantNumber && a.mokarrar == wantMok) {
        target = a;
        break;
      }
    }
    if (target == null) continue;

    final key = keyOf(law.id, target);
    if (boostedKeys.add(key)) {
      boosted.add(ArticleHit(
        law: law,
        article: target,
        exact: false,
        score: 900,
        tag: (e['anchor'] ?? '').toString(),
      ));
    }
  }

  if (boosted.isEmpty) return base;
  final merged = List<ArticleHit>.from(base)
    ..removeWhere((h) =>
        boostedKeys.contains(keyOf(h.law.id, h.article)));
  return [...merged, ...boosted];
}

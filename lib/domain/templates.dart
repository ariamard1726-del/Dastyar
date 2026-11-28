import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle, AssetManifest;

import 'package:dastyar/core/persian_text.dart';

class TemplateField {
  final String id;
  final String label;
  final String type; // text, multiline, number, choice, check
  final bool required;
  final String hint;
  final List<String> options;

  TemplateField({
    required this.id,
    required this.label,
    required this.type,
    required this.required,
    required this.hint,
    required this.options,
  });

  factory TemplateField.fromJson(Map<String, dynamic> j) {
    final rawId = j['id'];
    if (rawId is! String || rawId.trim().isEmpty) {
      throw const FormatException('template field needs id');
    }
    final rawOpts = j['options'];
    return TemplateField(
      id: rawId,
      label: (j['label'] ?? rawId).toString(),
      type: (j['type'] ?? 'text').toString(),
      required: j['required'] == true,
      hint: (j['hint'] ?? '').toString(),
      options: rawOpts is List
          ? rawOpts.map((e) => e.toString()).toList()
          : const [],
    );
  }
}

/// ارجاع به یک ماده قانونی. متن ماده هرگز در قالب نوشته نمی‌شود،
/// فقط نام قانون و شمارهٔ ماده؛ متن از بستهٔ رسمی قوانین خوانده می‌شود.
class LawRef {
  final String law;
  final String article;
  final String note;

  LawRef({required this.law, required this.article, required this.note});

  factory LawRef.fromJson(Map<String, dynamic> j) {
    final law = (j['law'] ?? '').toString().trim();
    final article = (j['article'] ?? '').toString().trim();
    if (law.isEmpty || article.isEmpty) {
      throw const FormatException('lawRefs needs law and article');
    }
    return LawRef(
      law: law,
      article: article,
      note: (j['note'] ?? '').toString(),
    );
  }
}

class LegalTemplate {
  static final RegExp _ifOpenRe = RegExp(r'\{\{\s*#if\s+(\w+)\s*\}\}');
  static final RegExp _placeholderNameRe =
      RegExp(r'\{\{\s*(\w+)(?:\|\w+)?\s*\}\}');

  final String id;
  final String title;
  final String description;
  final int version;
  final bool reviewed;
  final String reviewNote;
  final List<String> tips;
  final List<String> keywords;
  final List<TemplateField> fields;
  final List<LawRef> lawRefs;
  final String body;

  LegalTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.version,
    required this.reviewed,
    required this.reviewNote,
    required this.tips,
    required this.keywords,
    required this.fields,
    required this.lawRefs,
    required this.body,
  });

  factory LegalTemplate.fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final title = j['title'];
    if (id is! String || id.isEmpty || title is! String || title.isEmpty) {
      throw const FormatException('template needs id and title');
    }
    final rawBody = j['body'];
    if (rawBody == null) {
      throw const FormatException('template needs body');
    }
    final body = rawBody is List
        ? rawBody.map((e) => e.toString()).join('\n')
        : rawBody.toString();
    final rawVer = j['version'];
    final rawTips = j['tips'];
    final rawKeywords = j['keywords'];
    final rawFields = j['fields'];
    final rawRefs = j['lawRefs'];
    return LegalTemplate(
      id: id,
      title: title,
      description: (j['description'] ?? '').toString(),
      version: rawVer is int ? rawVer : (rawVer is num ? rawVer.toInt() : 1),
      reviewed: j['reviewed'] == true,
      reviewNote: (j['reviewNote'] ?? '').toString(),
      tips: rawTips is List
          ? rawTips.map((e) => e.toString()).toList()
          : const [],
      keywords: rawKeywords is List
          ? rawKeywords.map((e) => e.toString()).toList()
          : const [],
      fields: rawFields is List
          ? [
              for (final e in rawFields)
                if (e is Map)
                  TemplateField.fromJson(Map<String, dynamic>.from(e))
                else
                  throw const FormatException('invalid template field'),
            ]
          : const [],
      lawRefs: rawRefs is List
          ? [
              for (final e in rawRefs)
                if (e is Map)
                  LawRef.fromJson(Map<String, dynamic>.from(e))
                else
                  throw const FormatException('invalid lawRef'),
            ]
          : const [],
      body: body,
    );
  }

  Set<String> undefinedPlaceholders() {
    final defined = fields.map((f) => f.id).toSet();
    final used = <String>{};
    for (final m in _ifOpenRe.allMatches(body)) {
      used.add(m.group(1)!);
    }
    for (final m in _placeholderNameRe.allMatches(body)) {
      final id = m.group(1)!;
      if (id != 'else') used.add(id);
    }
    return used.difference(defined);
  }
}

class TemplateRenderer {
  static final RegExp _ifBlockRe =
      RegExp(r'\{\{\s*#if\s+(\w+)\s*\}\}([\s\S]*?)\{\{\s*/if\s*\}\}');
  static final RegExp _elseRe = RegExp(r'\{\{\s*else\s*\}\}');
  static final RegExp _placeholderRe =
      RegExp(r'\{\{\s*(\w+)(?:\|(\w+))?\s*\}\}');
  static final RegExp _trailingSpaceLineRe = RegExp(r'[ \t]+\n');
  static final RegExp _multiBlankLineRe = RegExp(r'\n{3,}');

  static String toFa(String s) => PersianText.toFaDigits(s);

  static String money(String v) {
    final d = PersianText.asciiDigits(v);
    if (d.isEmpty) return v;
    final sb = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i > 0 && (d.length - i) % 3 == 0) sb.write('،');
      sb.write(d[i]);
    }
    return toFa(sb.toString());
  }

  static bool _has(String? v) {
    if (v == null) return false;
    final t = v.trim().toLowerCase();
    return t.isNotEmpty && t != '0' && t != 'false';
  }

  static List<String> missing(LegalTemplate t, Map<String, String> values) {
    return t.fields
        .where((f) => f.required && !_has(values[f.id]))
        .map((f) => f.label)
        .toList();
  }

  static String render(
    LegalTemplate t,
    Map<String, String> values, {
    String blank = '..........',
  }) {
    var out = t.body;

    out = out.replaceAllMapped(
      _ifBlockRe,
      (m) {
        final parts = m.group(2)!.split(_elseRe);
        final yes = parts.first;
        final no = parts.length > 1 ? parts.sublist(1).join() : '';
        return _has(values[m.group(1)!]) ? yes : no;
      },
    );

    out = out.replaceAllMapped(
      _placeholderRe,
      (m) {
        final v = (values[m.group(1)!] ?? '').trim();
        if (v.isEmpty) return blank;
        final f = m.group(2);
        if (f == 'money') return money(v);
        if (f == 'fa') return toFa(v);
        return v;
      },
    );

    return out
        .replaceAll(_trailingSpaceLineRe, '\n')
        .replaceAll(_multiBlankLineRe, '\n\n')
        .trim();
  }
}

class TemplateRepository {
  final List<LegalTemplate> templates = [];
  final List<String> problems = [];

  Future<void> load() async {
    templates.clear();
    problems.clear();
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest
        .listAssets()
        .where((p) => p.startsWith('assets/templates/') && p.endsWith('.json'))
        .toList()
      ..sort();
    final loaded = await Future.wait(
      paths.map((p) async {
        try {
          final text = await rootBundle.loadString(p);
          return (path: p, text: text, error: null);
        } catch (e) {
          return (path: p, text: null, error: e);
        }
      }),
    );
    for (final item in loaded) {
      final text = item.text;
      if (item.error != null || text == null) {
        problems.add('${item.path}: ${item.error}');
        continue;
      }
      try {
        final map = jsonDecode(text) as Map<String, dynamic>;
        final t = LegalTemplate.fromJson(map);
        final bad = t.undefinedPlaceholders();
        if (bad.isNotEmpty) {
          problems.add('${item.path}: ${bad.join(', ')}');
          continue;
        }
        templates.add(t);
      } catch (e) {
        problems.add('${item.path}: $e');
      }
    }
  }
}

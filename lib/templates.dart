import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle, AssetManifest;

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
    return TemplateField(
      id: j['id'] as String,
      label: (j['label'] ?? j['id']).toString(),
      type: (j['type'] ?? 'text').toString(),
      required: j['required'] == true,
      hint: (j['hint'] ?? '').toString(),
      options: ((j['options'] ?? []) as List).map((e) => e.toString()).toList(),
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
    final rawBody = j['body'];
    final body = rawBody is List
        ? rawBody.map((e) => e.toString()).join('\n')
        : rawBody.toString();
    return LegalTemplate(
      id: j['id'] as String,
      title: j['title'] as String,
      description: (j['description'] ?? '').toString(),
      version: (j['version'] ?? 1) as int,
      reviewed: j['reviewed'] == true,
      reviewNote: (j['reviewNote'] ?? '').toString(),
      tips: ((j['tips'] ?? []) as List).map((e) => e.toString()).toList(),
      keywords:
          ((j['keywords'] ?? []) as List).map((e) => e.toString()).toList(),
      fields: ((j['fields'] ?? []) as List)
          .map((e) => TemplateField.fromJson(e as Map<String, dynamic>))
          .toList(),
      lawRefs: ((j['lawRefs'] ?? []) as List)
          .map((e) => LawRef.fromJson(e as Map<String, dynamic>))
          .toList(),
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
  static const String _faDigits = '۰۱۲۳۴۵۶۷۸۹';
  static final RegExp _ifBlockRe =
      RegExp(r'\{\{\s*#if\s+(\w+)\s*\}\}([\s\S]*?)\{\{\s*/if\s*\}\}');
  static final RegExp _elseRe = RegExp(r'\{\{\s*else\s*\}\}');
  static final RegExp _placeholderRe =
      RegExp(r'\{\{\s*(\w+)(?:\|(\w+))?\s*\}\}');
  static final RegExp _trailingSpaceLineRe = RegExp(r'[ \t]+\n');
  static final RegExp _multiBlankLineRe = RegExp(r'\n{3,}');

  static String toFa(String s) {
    final sb = StringBuffer();
    for (final ch in s.split('')) {
      final d = int.tryParse(ch);
      if (d != null && ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) {
        sb.write(_faDigits[d]);
      } else {
        sb.write(ch);
      }
    }
    return sb.toString();
  }

  static String _asciiDigits(String s) {
    final sb = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0x06F0 && r <= 0x06F9) {
        sb.write(r - 0x06F0);
      } else if (r >= 0x0660 && r <= 0x0669) {
        sb.write(r - 0x0660);
      } else if (r >= 48 && r <= 57) {
        sb.write(String.fromCharCode(r));
      }
    }
    return sb.toString();
  }

  static String money(String v) {
    final d = _asciiDigits(v);
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

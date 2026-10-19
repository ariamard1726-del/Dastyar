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

class LegalTemplate {
  final String id;
  final String title;
  final String description;
  final int version;
  final bool reviewed;
  final String reviewNote;
  final List<String> tips;
  final List<TemplateField> fields;
  final String body;

  LegalTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.version,
    required this.reviewed,
    required this.reviewNote,
    required this.tips,
    required this.fields,
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
      fields: ((j['fields'] ?? []) as List)
          .map((e) => TemplateField.fromJson(e as Map<String, dynamic>))
          .toList(),
      body: body,
    );
  }

  Set<String> undefinedPlaceholders() {
    final defined = fields.map((f) => f.id).toSet();
    final used = <String>{};
    for (final m in RegExp(r'\{\{\s*#if\s+(\w+)\s*\}\}').allMatches(body)) {
      used.add(m.group(1)!);
    }
    for (final m in RegExp(r'\{\{\s*(\w+)(?:\|\w+)?\s*\}\}').allMatches(body)) {
      final id = m.group(1)!;
      if (id != 'else') used.add(id);
    }
    return used.difference(defined);
  }
}

class TemplateRenderer {
  static const String _faDigits = '۰۱۲۳۴۵۶۷۸۹';

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
      RegExp(r'\{\{\s*#if\s+(\w+)\s*\}\}([\s\S]*?)\{\{\s*/if\s*\}\}'),
      (m) {
        final parts = m.group(2)!.split(RegExp(r'\{\{\s*else\s*\}\}'));
        final yes = parts.first;
        final no = parts.length > 1 ? parts.sublist(1).join() : '';
        return _has(values[m.group(1)!]) ? yes : no;
      },
    );

    out = out.replaceAllMapped(
      RegExp(r'\{\{\s*(\w+)(?:\|(\w+))?\s*\}\}'),
      (m) {
        final v = (values[m.group(1)!] ?? '').trim();
        if (v.isEmpty) return blank;
        final f = m.group(2);
        if (f == 'money') return money(v);
        if (f == 'fa') return toFa(v);
        return v;
      },
    );

    return out.replaceAll(RegExp(r'[ \t]+\n'), '\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
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
    for (final p in paths) {
      try {
        final text = await rootBundle.loadString(p);
        final map = jsonDecode(text) as Map<String, dynamic>;
        final t = LegalTemplate.fromJson(map);
        final bad = t.undefinedPlaceholders();
        if (bad.isNotEmpty) {
          problems.add('$p: ${bad.join(', ')}');
          continue;
        }
        templates.add(t);
      } catch (e) {
        problems.add('$p: $e');
      }
    }
  }
}

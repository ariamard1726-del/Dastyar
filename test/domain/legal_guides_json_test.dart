// قفلِ سمتِ دارت: JSON باید همان چیزی باشد که امروز در `legalGuides` است.
//
// این آزمون «بارگذارِ آینده» را جلوتر از خودِ بارگذار می‌سنجد: اگر JSON نتواند
// دقیقاً همان راهنماها را بسازد، مهاجرت بی‌معناست. هیچ رشته‌ای در این فایل
// نوشته نمی‌شود؛ همه از دو منبع خوانده و مقایسه می‌شوند.
import 'dart:convert';
import 'dart:io';

import 'package:dastyar/domain/lawyer/legal_guides.dart';
import 'package:flutter_test/flutter_test.dart';

LegalGuide _guide(Map<String, dynamic> m) {
  List<String> strs(Object? raw) =>
      (raw as List? ?? const []).map((e) => e.toString()).toList();
  List<List<String>> groups(Object? raw) => [
        for (final g in (raw as List? ?? const [])) strs(g),
      ];
  return LegalGuide(
    id: m['id'].toString(),
    title: m['title'].toString(),
    triggers: groups(m['triggers']),
    excludes: strs(m['excludes']),
    priority: (m['priority'] as num?)?.toInt() ?? 0,
    empathy: m['empathy'].toString(),
    brief: m['brief'].toString(),
    answer: m['answer'].toString(),
    steps: strs(m['steps']),
    cautions: strs(m['cautions']),
    refs: [
      for (final r in (m['refs'] as List? ?? const []))
        LegalRef((r as Map)['law'].toString(), r['article'].toString()),
    ],
    followUp: m['followUp'].toString(),
    templateIds: strs(m['templateIds']),
    notes: [
      for (final n in (m['notes'] as List? ?? const []))
        GuideNote(groups((n as Map)['cues']), n['text'].toString()),
    ],
  );
}

void main() {
  final file = File('tools/data/legal_guides.json');
  final guides = () {
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return [
      for (final g in (data['guides'] as List)) _guide(g as Map<String, dynamic>),
    ];
  }();

  test('JSON همان تعداد و همان ترتیبِ راهنماهای کد را دارد', () {
    expect(guides.length, legalGuides.length);
    expect([for (final g in guides) g.id], [for (final g in legalGuides) g.id]);
  });

  test('هر فیلدِ هر راهنما یکی است', () {
    for (var i = 0; i < legalGuides.length; i++) {
      final a = legalGuides[i];
      final b = guides[i];
      expect(b.id, a.id);
      expect(b.title, a.title, reason: a.id);
      expect(b.triggers, a.triggers, reason: a.id);
      expect(b.excludes, a.excludes, reason: a.id);
      expect(b.priority, a.priority, reason: a.id);
      expect(b.empathy, a.empathy, reason: a.id);
      expect(b.brief, a.brief, reason: a.id);
      expect(b.answer, a.answer, reason: a.id);
      expect(b.steps, a.steps, reason: a.id);
      expect(b.cautions, a.cautions, reason: a.id);
      expect([for (final r in b.refs) '${r.lawId}:${r.article}'],
          [for (final r in a.refs) '${r.lawId}:${r.article}'],
          reason: a.id);
      expect(b.followUp, a.followUp, reason: a.id);
      expect(b.templateIds, a.templateIds, reason: a.id);
      expect(b.notes.length, a.notes.length, reason: a.id);
      for (var k = 0; k < a.notes.length; k++) {
        expect(b.notes[k].cues, a.notes[k].cues, reason: '${a.id}#$k');
        expect(b.notes[k].text, a.notes[k].text, reason: '${a.id}#$k');
      }
    }
  });
}

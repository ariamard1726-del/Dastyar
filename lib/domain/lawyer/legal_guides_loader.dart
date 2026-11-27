import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'package:dastyar/domain/lawyer/legal_guides.dart';

/// محلِ فایلِ دادهٔ راهنماها داخلِ APK.
const String legalGuidesAsset = 'assets/brain/guides/legal_guides.json';

/// خواندنِ رشتهٔ JSON به فهرستِ راهنماها. خروجی به همان ترتیبِ فایل است.
List<LegalGuide> parseLegalGuides(String source) {
  final data = jsonDecode(source) as Map<String, dynamic>;
  final raw = data['guides'] as List;
  List<String> strs(Object? v) =>
      (v as List? ?? const []).map((e) => e.toString()).toList();
  List<List<String>> groups(Object? v) => [
        for (final g in (v as List? ?? const [])) strs(g),
      ];
  return [
    for (final item in raw)
      LegalGuide(
        id: (item as Map)['id'].toString(),
        title: item['title'].toString(),
        triggers: groups(item['triggers']),
        excludes: strs(item['excludes']),
        priority: (item['priority'] as num?)?.toInt() ?? 0,
        empathy: item['empathy'].toString(),
        brief: item['brief'].toString(),
        answer: item['answer'].toString(),
        steps: strs(item['steps']),
        cautions: strs(item['cautions']),
        refs: [
          for (final r in (item['refs'] as List? ?? const []))
            LegalRef((r as Map)['law'].toString(), r['article'].toString()),
        ],
        followUp: item['followUp'].toString(),
        templateIds: strs(item['templateIds']),
        notes: [
          for (final n in (item['notes'] as List? ?? const []))
            GuideNote(groups((n as Map)['cues']), n['text'].toString()),
        ],
      ),
  ];
}

/// راهنماها را از فایلِ دارایی می‌خواند و نصب می‌کند.
///
/// این تنها جایی است که مسیرِ دارایی و بارگذاریِ ناهمگام دیده می‌شود؛ خودِ
/// `legal_guides.dart` کتابخانهٔ خالصِ دارت می‌ماند. باید **پیش از** اولین
/// پاسخِ وکیل اجرا شود: `KnowledgeEngine.load()` همین کار را می‌کند و
/// `ChatPage` پیش از نمایش، `load()` را صدا می‌زند.
///
/// اگر فایل نباشد، خطا بالا می‌رود — نه اینکه بی‌صدا فهرست خالی شود.
Future<List<LegalGuide>> loadLegalGuides({AssetBundle? bundle}) async {
  final source = await (bundle ?? rootBundle).loadString(legalGuidesAsset);
  final guides = parseLegalGuides(source);
  if (guides.isEmpty) {
    throw StateError('$legalGuidesAsset خالی است');
  }
  installLegalGuides(guides);
  return guides;
}

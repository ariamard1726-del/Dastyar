import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/draft_models.dart';
import 'package:dastyar/domain/templates.dart';

/// متنِ موادِ قانونیِ ارجاع‌شده در یک قالب، با وضعیتِ بازبینیِ هر متن.
class DraftLaws {
  static List<LawText> lawTexts(KnowledgeEngine e, LegalTemplate t) {
    final out = <LawText>[];
    for (final r in t.lawRefs) {
      final c = e.findArticle(r.law, r.article);
      if (c == null) continue;
      out.add(LawText(c.title, c.source, c.body, r.note,
          status: e.meta[c.lawId]?['status']?.toString() ?? ''));
    }
    return out;
  }
}

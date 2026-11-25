part of 'engine.dart';

// بارگذاریِ دارایی‌ها و ساختنِ ایندکس.
//
// همهٔ `rootBundle` و `jsonDecode` این‌جاست؛ بیرون از این فایل هیچ دارایی‌ای
// خوانده نمی‌شود. اگر فایلی نباشد، خطا در `warnings` می‌ماند و بارگذاری
// بقیهٔ قوانین را متوقف نمی‌کند — همان رفتاری که پیش‌تر داشت.

extension _EngineLoad on KnowledgeEngine {
Future<void> _loadCatalog() async {
  try {
    final t = await rootBundle.loadString('assets/laws_catalog.json');
    final m = jsonDecode(t) as Map<String, dynamic>;
    final cats = (m['categories'] ?? {}) as Map<String, dynamic>;
    cats.forEach((k, v) => categoryNames[k] = v.toString());
    for (final e in (m['laws'] ?? []) as List) {
      final l = e as Map<String, dynamic>;
      catalog.add(CatalogLaw(
        l['id'].toString(),
        l['title'].toString(),
        (l['category'] ?? '').toString(),
        (l['priority'] ?? 3) as int,
        ((l['aliases'] ?? []) as List).map((x) => x.toString()).toList(),
      ));
    }
  } catch (e) {
    warnings.add('laws_catalog.json: $e');
  }
}

Future<void> _loadMeta() async {
  try {
    final t = await rootBundle.loadString('assets/laws/_meta.json');
    final m = jsonDecode(t) as Map<String, dynamic>;
    m.forEach((k, v) {
      if (v is Map<String, dynamic>) meta[k] = v;
    });
  } catch (e) {
    warnings.add('_meta.json: $e');
  }
}

Future<void> _loadReplies() async {
  try {
    final t = await rootBundle.loadString('assets/replies.json');
    final m = jsonDecode(t) as Map<String, dynamic>;
    replies.setOverridesRaw(m);
  } catch (e) {
    warnings.add('replies.json: $e');
  }
}

Future<void> _loadTopicFlows() async {
  _topicFlows = const [];
  try {
    final idx = jsonDecode(await rootBundle.loadString('assets/brain/topics/index.json'))
        as Map<String, dynamic>;
    final out = <Map<String, dynamic>>[];
    for (final name in (idx['topics'] as List).cast<String>()) {
      final t = await rootBundle.loadString('assets/brain/topics/$name');
      out.add(jsonDecode(t) as Map<String, dynamic>);
    }
    _topicFlows = out;
  } catch (e) {
    warnings.add('brain/topics: $e');
  }
}

Future<void> _loadLegalTerms() async {
  _legalTerms = const {};
  try {
    final t = await rootBundle.loadString('assets/brain/legal_terms.json');
    _legalTerms = jsonDecode(t) as Map<String, dynamic>;
  } catch (e) {
    warnings.add('brain/legal_terms.json: $e');
  }
}

Future<void> _loadQa() async {
  _qaBank = QaBank.empty;
  try {
    final t = await rootBundle.loadString('assets/qa/lease_qa.json');
    _qaBank = QaBank.fromJson(jsonDecode(t));
  } catch (e) {
    warnings.add('qa/lease_qa.json: $e');
  }
}

Future<void> _loadLawTopics() async {
  _lawPrior = LawTopicPrior.empty;
  try {
    final t = await rootBundle.loadString('assets/brain/law_topics.json');
    _lawPrior = LawTopicPrior.fromJson(jsonDecode(t));
  } catch (e) {
    warnings.add('law_topics.json: $e');
  }
}

Future<void> _loadRelationships() async {
  try {
    final t = await rootBundle.loadString('assets/relationships.json');
    final m = jsonDecode(t);
    if (m is Map<String, dynamic>) {
      _relationships = m;
    }
  } catch (e) {
    warnings.add('relationships.json: $e');
  }
}

Future<List<String>?> _loadKnowledgeChunk() async {
  try {
    final text = await rootBundle.loadString('assets/knowledge.txt');
    return ['knowledge', 'دانش عمومی', text];
  } catch (e) {
    warnings.add('assets/knowledge.txt: $e');
    return null;
  }
}

Future<void> load() async {
  _index.clear();
  catalog.clear();
  categoryNames.clear();
  meta.clear();
  _relationships = const {};
  warnings.clear();

  final knowledgeFuture = _loadKnowledgeChunk();
  await Future.wait<void>([
    _loadCatalog(),
    _loadMeta(),
    _loadReplies(),
    _loadSynonyms(),
    _loadRelationships(),
    _loadLawTopics(),
    _loadQa(),
    _loadLegalTerms(),
    _loadTopicFlows(),
    knowledgeFuture,
  ]);

  final raw = <List<String>>[];
  final knowledgeRaw = await knowledgeFuture;
  if (knowledgeRaw != null) {
    raw.add(knowledgeRaw);
  }

  final entries = meta.entries.toList();
  final loadedLaws = await Future.wait<List<String>?>(
    entries.map((entry) async {
      final lawId = entry.key;
      final path = entry.value['path'];
      if (path is! String || path.isEmpty) return null;
      final fullPath = 'assets/laws/$path';
      try {
        final text = await rootBundle.loadString(fullPath);
        final fallbackTitle = (entry.value['title'] ?? '').toString().trim();
        return [lawId, fallbackTitle, text];
      } catch (e) {
        warnings.add('$fullPath: $e');
        return null;
      }
    }),
  );

  for (final item in loadedLaws) {
    if (item != null) raw.add(item);
  }

  IndexBuild built;
  try {
    built = await LawIndex.buildAsync(raw);
  } catch (_) {
    built = LawIndex.build(raw); // اگر Isolate شکست خورد، روی همین رشته
  }
  _index.adopt(built);
}

Future<void> _loadSynonyms() async {
  _syn.clear();
  try {
    final t = await rootBundle.loadString('assets/synonyms.txt');
    for (final line in t.split('\n')) {
      final l = line.trim();
      if (l.isEmpty || l.startsWith('#')) continue;
      final i = l.indexOf('|');
      if (i < 0) continue;
      final k = KnowledgeEngine._phrase(l.substring(0, i));
      final v = l.substring(i + 1).trim();
      if (k.isNotEmpty && v.isNotEmpty) _syn.add([k, v]);
    }
  } catch (e) {
    warnings.add('synonyms.txt: $e');
  }
}

/// واژه‌های قانونیِ معادلِ عبارت‌های عامیانهٔ پرسش.
List<String> _expand(String question) {
  final n = ' ${KnowledgeEngine._phrase(question)} ';
  final out = <String>[];
  for (final r in _syn) {
    if (n.contains(' ${r[0]} ')) out.addAll(KnowledgeEngine.tokenizeIndex(r[1]));
  }
  return out;
}

}

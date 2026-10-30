import 'engine.dart' show KnowledgeEngine;

class Chunk {
  final String lawId;
  final String source;
  final String chapter;
  final String title;
  final String body;
  final bool obsolete;
  final Map<String, int> tfT; // واژه‌های عنوان
  final Map<String, int> tfB; // واژه‌های متن
  final Map<String, int> tfC; // واژه‌های فصل و نام قانون
  final int len;
  late final String normTitle = KnowledgeEngine.normalize(title).trim();
  Chunk(
    this.lawId,
    this.source,
    this.chapter,
    this.title,
    this.body,
    this.obsolete,
    this.tfT,
    this.tfB,
    this.tfC,
    this.len,
  );
}

class Hit {
  final Chunk chunk;
  final double score;
  Hit(this.chunk, this.score);
}

class RankResult {
  final List<Hit> hits;
  final String note;
  RankResult(this.hits, [this.note = '']);
}

class CatalogLaw {
  final String id;
  final String title;
  final String category;
  final int priority;
  final List<String> aliases;
  CatalogLaw(this.id, this.title, this.category, this.priority, this.aliases);
}

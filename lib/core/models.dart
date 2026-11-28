import 'package:dastyar/core/persian_text.dart';

class Chunk {
  final String lawId;
  final String source;
  final String chapter;
  final String title;
  final String body;
  final bool obsolete;
  final Map<String, int> tfT;
  final Map<String, int> tfB;
  final Map<String, int> tfC;
  final int len;

  /// عنوان و منبع نرمال‌شده که یک‌بار هنگام ساخت Chunk (در Isolate) محاسبه می‌شوند.
  final String normTitle;
  final String normSource;

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
  )   : normTitle = PersianText.collapse(PersianText.normalize(title)),
        normSource = PersianText.collapse(PersianText.normalize(source));
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

class EngineReply {
  final String text;
  final List<Hit> contextHits;
  final List<String> alternatives;
  final List<String> conflictChains;

  const EngineReply({
    required this.text,
    this.contextHits = const [],
    this.alternatives = const [],
    this.conflictChains = const [],
  });
}

class CatalogLaw {
  final String id;
  final String title;
  final String category;
  final int priority;
  final List<String> aliases;
  CatalogLaw(this.id, this.title, this.category, this.priority, this.aliases);
}

/// سنجه‌های اندازه‌گیری‌شدهٔ بارگذاریِ اخیر موتور دانش (استارت و ایندکس).
class StartupMetrics {
  final int assetsMillis;
  final int indexMillis;
  final int totalMillis;
  final int rawChars;
  final int lawsCount;
  final int chunksCount;
  final int vocabSize;
  final bool withWorker;

  const StartupMetrics({
    required this.assetsMillis,
    required this.indexMillis,
    required this.totalMillis,
    required this.rawChars,
    required this.lawsCount,
    required this.chunksCount,
    required this.vocabSize,
    required this.withWorker,
  });
}

/// پیکربندی زندهٔ خط لولهٔ پاسخ که از `assets/pipeline.json` بارگذاری می‌شود.
class PipelineConfig {
  final List<String> order;
  final double netMin;
  final int topicOpen;
  final int topicStrong;
  final int topicDominant;

  const PipelineConfig({
    required this.order,
    required this.netMin,
    required this.topicOpen,
    required this.topicStrong,
    required this.topicDominant,
  });

  static PipelineConfig? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final ord = raw['order'];
    final th = raw['thresholds'];
    if (ord is! List || ord.isEmpty || th is! Map) return null;
    final orderList = <String>[for (final s in ord) s.toString()];
    final net = th['netMin'];
    final open = th['topicOpen'];
    final strong = th['topicStrong'];
    final dom = th['topicDominant'];
    if (net is! num || open is! int || strong is! int || dom is! int) {
      return null;
    }
    return PipelineConfig(
      order: List<String>.unmodifiable(orderList),
      netMin: net.toDouble(),
      topicOpen: open,
      topicStrong: strong,
      topicDominant: dom,
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import 'package:dastyar/core/asset_loader.dart';
import 'package:dastyar/core/law_topic_prior.dart';
import 'package:dastyar/core/article_query.dart';
import 'package:dastyar/core/engine_rules.dart';
import 'package:dastyar/core/law_index.dart';
import 'package:dastyar/core/law_ranker.dart';
import 'package:dastyar/core/law_text.dart';
import 'package:dastyar/core/law_mention.dart';
import 'package:dastyar/core/models.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/core/qa_bank.dart';
import 'package:dastyar/core/replies.dart';
import 'package:dastyar/core/router.dart';
import 'package:dastyar/core/conflicts_service.dart';

export 'asset_loader.dart';
export 'models.dart';

// موتورِ دانش: وضعیت و API عمومی.
//
// این فایل فقط چیزی را نگه می‌دارد که «وضعیتِ موتور» است: فهرستِ قوانین،
// ایندکس، بردارِ واژه‌ها، پیکربندیِ زندهٔ خط لوله و پاسخ‌های ثابت.
// دو مسئولیتِ سنگین در بخش‌های خودشان‌اند و با `extension` به وضعیت دسترسی
// دارند: `engine_load.dart` (`load`) و `engine_query.dart` (پاسخ‌سازی).

part 'engine_load.dart';
part 'engine_query.dart';
part 'engine_worker.dart';

class KnowledgeEngine {
  KnowledgeEngine({AssetTextLoader? assetLoader}) : _assetLoader = assetLoader;

  final AssetTextLoader? _assetLoader;

  /// پاسخ‌های ثابت؛ از assets/replies.json خوانده می‌شوند.
  final Replies replies = Replies();
  /// متنِ قوانین، نمایهٔ واژه‌ها، ایندکسِ مواد و شمارشِ هر قانون؛
  /// صاحبش `LawIndex` است تا موتور فقط بارگذاری و پاسخ‌سازی کند.
  final LawIndex _index = LawIndex();

  // آستانهٔ پوشش از قرارداد `dev/tools/contracts/engine_rules.json` می‌آید.
  static const double _lowCover = EngineRules.lowCover;

  // الگوهای ازپیش‌کامپایل‌شده برای جلوگیری از ساخت مکرر RegExp
  static final RegExp _punctOnlyRe = RegExp(r'[\p{P}]', unicode: true);
  static final RegExp _articleTitleRe = RegExp(
    r'^(?:ماده|اصل)\s*(?:واحده|\d+(?:\s*مکرر(?:\s*\d{1,2})?)?)$',
  );

  final List<CatalogLaw> catalog = [];
  final Map<String, String> categoryNames = {};
  final Map<String, Map<String, dynamic>> meta = {};
  /// شناسایی نام قانون در متن؛ جدا از ایندکس و رتبه‌بندی.
  late final LawMention _mention =
      LawMention(catalog: catalog, isLoaded: isLoaded);

  /// امتیازدهیِ BM25F و گسترشِ پیشوند؛ منطقش در `law_ranker.dart` است.
  late final LawRanker _ranker = LawRanker(
    index: _index,
    mention: _mention,
    isLoaded: isLoaded,
    topicFactors: (q) => _lawPrior.factors(q),
    expand: _expand,
    synonyms: _syn,
  );

  final ConflictsService _conflictsService = ConflictsService();
  Map<String, dynamic> _relationships = const {};

  /// دادههای خام و worker پاسخسازی؛ [`load`] آنها را پر میکند.
  Map<String, dynamic> _repliesRaw = const {};
  Object? _lawTopicsRaw;
  EngineWorker? _worker;
  StartupMetrics? _startup;
  PipelineConfig? _pipeline;

  /// خطاهای بارگذاری فایل‌های کمکی؛ دیگر بی‌صدا نادیده گرفته نمی‌شوند.
  final List<String> warnings = [];

  int get size => _index.chunks.length;
  StartupMetrics? get startupMetrics => _startup;
  /// پیکربندی زندهٔ خط لولهٔ پاسخ (`assets/pipeline.json`).
  PipelineConfig? get pipeline => _pipeline;

  /// بخش‌های قوانین و فهرست وارونهٔ آن‌ها؛ برای تطبیق واژه‌ها (law_terms.dart).
  List<Chunk> get chunks => _index.chunks;
  Map<String, List<int>> get postings => _index.postings;
  Map<String, double> get idf => _index.idf;
  /// بانک پرسش‌وپاسخ حقوقی (اجاره)؛ پس از [load] پر می‌شود.
  QaBank get qa => _qaBank;
  /// فهرست واژه‌های حقوقی با ماده؛ پس از [load] پر می‌شود.
  Map<String, dynamic> get legalTerms => _legalTerms;
  /// مسیرهای تصمیم موضوعی (assets/brain/topics/index.json)؛ پس از [load] پر می‌شود.
  List<Map<String, dynamic>> get topicFlows => _topicFlows;
  Map<String, int> get lawCounts => _index.lawCounts;
  bool isLoaded(String id) => (_index.lawCounts[id] ?? 0) > 0;

  /// نوشتنِ متنِ ماده و فهرستِ قوانین؛ صاحبش [LawText] است.
  late final LawText _text = LawText(
    meta: meta,
    replies: replies,
    catalog: catalog,
    lawCountOf: (id) => _index.lawCounts[id] ?? 0,
  );

  /// متنِ آمادهٔ یک ماده، با منبع و تاریخ. پاس‌دهنده به [LawText].
  String format(Chunk c) => _text.format(c);

  /// رتبه‌بندیِ پرسش؛ پاس‌دهنده به [LawRanker].
  RankResult rank(String question, {int k = 3}) => _ranker.rank(question, k: k);

  /// چه کسری از وزن واژه‌های پرسش در این ماده پیدا می‌شود (۰ تا ۱).
  double coverage(String question, Chunk c) => _ranker.coverage(question, c);

  // لایهٔ متن به persian_text.dart رفته؛ اینجا فقط نام‌های قدیمی نگه داشته شده‌اند.
  static String normalize(String s) => PersianText.normalize(s);

  static String _collapse(String s) => PersianText.collapse(s);

  static List<String> tokenizeIndex(String s) => PersianText.tokenizeIndex(s);

  static List<String> tokenize(String s) => PersianText.tokenize(s);

  // اینها حالتِ همین نمونهاند، نه متغیرِ سراسری: دو KnowledgeEngine نباید
  // بانک پرسشوپاسخ یا مترادفهای همدیگر را پاک یا جایگزین کنند.
  LawTopicPrior _lawPrior = LawTopicPrior.empty;
  QaBank _qaBank = QaBank.empty;
  /// واژهها و عبارتهای حقوقی با مادهای مشخص (assets/brain/legal_terms.json).
  Map<String, dynamic> _legalTerms = const {};
  /// مسیرهای تصمیم موضوعی، با ترتیب فهرست index.json.
  List<Map<String, dynamic>> _topicFlows = const [];
  final List<List<String>> _syn = [];

  static String _phrase(String s) => PersianText.phrase(s);


  // ---------------------------------------------------------------------------
  // API عمومی. پیاده‌سازی در بخش‌ها است و این‌جا فقط پاس داده می‌شود؛ دلیلش این
  // است که `extension`ِ خصوصی از بیرونِ این کتابخانه دیده نمی‌شود، پس هر چه
  // بیرون لازم است باید در خودِ کلاس امضا داشته باشد. اگر روزی این پاس‌دهنده‌ها
  // منطق گرفتند، همین‌جا است که گاد-آبجکت برمی‌گردد.
  // ---------------------------------------------------------------------------

  /// بارگذاریِ دارایی‌ها و ساختنِ ایندکس؛ پیاده‌سازی در `engine_load.dart`.
  Future<void> load({bool startWorker = false}) =>
      _EngineLoad(this).load(startWorker: startWorker);

  /// ساخت ایندکس را از همان دادههای که worker دارد؛ فقط داخل همان isolate صدا زده
  /// میشود تا پرسشها روی رشتهٔ جدا پاسخ داده شوند.
  IndexBuild adoptWorkerData(Map<String, dynamic> data) =>
      _EngineLoad(this).adoptWorkerData(data);

  /// پاسخِ ازپیشساختهٔ worker، یا `null` وقتی worker در دسترس نیست.
  Future<EngineReply?> prepareQuery(String question) =>
      _worker?.query(question) ?? Future<EngineReply?>.value(null);

  /// اجرای یک تابعِ سطحِ بالا یا static درون isolate دائمی موتور، یا `null`.
  Future<R?> prepareWith<A, R>(
    R Function(KnowledgeEngine engine, A arg) task,
    A arg,
  ) =>
      _worker?.run<A, R>(task, arg) ?? Future<R?>.value(null);

  /// آزادسازی isolate هنگام بستن صفحه.
  void dispose() {
    _worker?.dispose();
    _worker = null;
  }

  /// یافتنِ ماده با ارجاعِ صریح («ماده ۶۷۷» یا ارجاعِ هم‌نام).
  Chunk? findArticle(String law, String article) =>
      _EngineQuery(this).findArticle(law, article);

  int? chunkOf(String lawId, String title) =>
      _EngineQuery(this).chunkOf(lawId, title);

  /// پردازشِ یکپارچهٔ پرسش: پاسخ + پیشنهادهای نزدیک.
  EngineReply query(String question, {int maxAlternatives = 3}) =>
      _EngineQuery(this).query(question, maxAlternatives: maxAlternatives);

  String answer(String question) => _EngineQuery(this).answer(question);

  List<String> alternatives(String question, {int max = 3}) =>
      _EngineQuery(this).alternatives(question, max: max);

  List<String> conflictChainsFor(Chunk c) =>
      _EngineQuery(this).conflictChainsFor(c);

  /// گسترشِ پرسش با مترادف‌ها؛ `LawRanker` این را به‌عنوانِ تابع می‌گیرد.
  List<String> _expand(String question) => _EngineLoad(this)._expand(question);
}

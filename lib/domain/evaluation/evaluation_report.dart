import 'evaluation_dataset.dart';

/// یک مادهٔ بازیابی‌شده در جریان اجرای سناریو.
class RetrievedArticle {
  final String lawId;
  final String article;
  final String source;
  final double score;

  const RetrievedArticle({
    required this.lawId,
    required this.article,
    this.source = '',
    this.score = 0,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'law': lawId,
        'article': article,
        if (source.isNotEmpty) 'source': source,
        'score': score,
      };

  @override
  String toString() => '$lawId/$article';
}

/// نتیجهٔ اجرای یک سناریو، با تفکیک شکست‌ها تا عیب‌یابی ممکن باشد.
class ScenarioOutcome {
  final EvaluationScenario scenario;
  final String? topic;
  final String? route;
  final List<RetrievedArticle> retrieved;
  final List<ExpectedArticle> matched;
  final Set<String> citedArticles;
  final String answer;
  final bool ragMissed;
  final int elapsedMs;
  final List<String> failures;

  const ScenarioOutcome({
    required this.scenario,
    required this.topic,
    required this.route,
    required this.retrieved,
    required this.matched,
    required this.citedArticles,
    required this.answer,
    required this.ragMissed,
    required this.elapsedMs,
    required this.failures,
  });

  bool get hasExpectedTopic => scenario.expectedTopic != null;
  bool get hasExpectedRoute => scenario.expectedRoute != null;
  bool get hasExpectedArticles => scenario.expectedArticles.isNotEmpty;

  bool get topicOk => !hasExpectedTopic || topic == scenario.expectedTopic;
  bool get routeOk => !hasExpectedRoute || route == scenario.expectedRoute;

  /// نسبت مواد درستِ بازیابی‌شده به کلِ مواد انتظاررفته.
  double get articleRecall => !hasExpectedArticles
      ? 1.0
      : matched.length / scenario.expectedArticles.length;

  /// آیا همهٔ مواد انتظاررفته بازیابی شدند؟
  bool get articleOk => articleRecall >= 0.999;

  /// آیا پاسخ، ماده(های) بازیابی‌شدهٔ درست را استناد کرده است؟
  ///
  /// وقتی ماده‌ای اصلاً بازیابی نشده، شکست در همان معیار «بازیابی» ثبت
  /// می‌شود؛ این معیار فقط «امانت‌داری در استناد» را می‌سنجد.
  bool get citationOk {
    if (scenario.expectsNoCitation) return citedArticles.isEmpty;
    if (matched.isEmpty) return true;
    return matched.every((a) => citedArticles.contains(a.citationKey));
  }

  bool get ragMissOk => !scenario.expectsRagMiss || ragMissed;

  /// معیار عبور سناریو: همهٔ انتظارهای قابل‌سنجش برآورده شده باشند.
  bool get passed => failures.isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': scenario.id,
        'query': scenario.query,
        'passed': passed,
        'route': route,
        'expected_route': scenario.expectedRoute,
        'topic': topic,
        'expected_topic': scenario.expectedTopic,
        'retrieved': retrieved.map((r) => r.toJson()).toList(),
        'matched_articles': matched.map((m) => m.toJson()).toList(),
        'expected_articles':
            scenario.expectedArticles.map((a) => a.toJson()).toList(),
        'cited_articles': citedArticles.toList(),
        'elapsed_ms': elapsedMs,
        'failures': failures,
        'answer': answer,
      };
}

/// گزارش تجمیعی ارزیابی.
///
/// معیارها همان‌هایی هستند که برای «کیفیت واقعی پاسخ حقوقی» اهمیت دارند:
/// نیت/موضوع، مسیر تصمیم، بازیابی مادهٔ درست، استناد درست، و صداقت هنگام
/// نبودِ دانش.
class EvaluationReport {
  final List<ScenarioOutcome> outcomes;
  final int datasetSize;

  const EvaluationReport({required this.outcomes, required this.datasetSize});

  List<ScenarioOutcome> get failed =>
      outcomes.where((o) => !o.passed).toList();

  double _mean(bool Function(ScenarioOutcome) test, bool Function(ScenarioOutcome) pick) {
    final selected = outcomes.where(test).toList();
    if (selected.isEmpty) return 1.0;
    final ok = selected.where(pick).length;
    return ok / selected.length;
  }

  /// دقت تشخیص موضوع/نیت در سناریوهای مشاوره.
  double get intentAccuracy => _mean((o) => o.hasExpectedTopic, (o) => o.topicOk);

  /// دقت انتخاب مسیر تصمیم (RAG، گفتگوی کوتاه، مشاوره، پذیرش).
  double get routeAccuracy => _mean((o) => o.hasExpectedRoute, (o) => o.routeOk);

  /// میانگین یادآوری مواد قانونیِ درست (recall).
  double get articleRecall => _mean(
        (o) => o.hasExpectedArticles,
        (o) => o.articleOk,
      );

  /// میانگین نسبت مواد انتظاررفته‌ای که واقعاً بازیابی شدند (نرم، ۰..۱).
  double get articleRecallSoft {
    final selected = outcomes.where((o) => o.hasExpectedArticles).toList();
    if (selected.isEmpty) return 1.0;
    final total = selected.fold<double>(0, (sum, o) => sum + o.articleRecall);
    return total / selected.length;
  }

  /// دقت استناد: پاسخ نهایی ماده(های) درست را نام برده است.
  double get citationAccuracy => _mean(
        (o) => o.hasExpectedArticles || o.scenario.expectsNoCitation,
        (o) => o.citationOk,
      );

  /// صداقت: وقتی دانشی در بانک نیست، پاسخ نساخته و استناد جعلی نزده است.
  double get honestyRate => _mean(
        (o) => o.scenario.expectsNoCitation || o.scenario.expectsRagMiss,
        (o) => o.citationOk && o.ragMissOk,
      );

  double get passRate =>
      outcomes.isEmpty ? 1.0 : outcomes.where((o) => o.passed).length / outcomes.length;

  /// آیا گزارش به آستانه‌های خواسته‌شده می‌رسد؟ (برای دروازهٔ CI)
  bool meets({
    double minIntent = 0.0,
    double minRoute = 0.0,
    double minArticles = 0.0,
    double minCitations = 0.0,
    double minHonesty = 0.0,
  }) =>
      intentAccuracy >= minIntent &&
      routeAccuracy >= minRoute &&
      articleRecallSoft >= minArticles &&
      citationAccuracy >= minCitations &&
      honestyRate >= minHonesty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'dataset_size': datasetSize,
        'executed': outcomes.length,
        'passed': outcomes.where((o) => o.passed).length,
        'metrics': <String, dynamic>{
          'intent_accuracy': intentAccuracy,
          'route_accuracy': routeAccuracy,
          'article_recall': articleRecall,
          'article_recall_soft': articleRecallSoft,
          'citation_accuracy': citationAccuracy,
          'honesty_rate': honestyRate,
          'pass_rate': passRate,
        },
        'outcomes': outcomes.map((o) => o.toJson()).toList(),
      };

  static String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  static String _bar(double v, {int width = 20}) {
    final filled = (v.clamp(0.0, 1.0) * width).round();
    return '${'█' * filled}${'░' * (width - filled)}';
  }

  /// گزارش خوانا برای انسان.
  String toText({bool verbose = false, int maxFailures = 30}) {
    final sb = StringBuffer()
      ..writeln('╭──────────────────────────────────────────────╮')
      ..writeln('│ گزارش ارزیابی دستیار حقوقی (Phase 6)          │')
      ..writeln('╰──────────────────────────────────────────────╯')
      ..writeln('سناریوها: ${outcomes.length} از $datasetSize');
    void line(String name, String fa, double v) {
      sb.writeln(
          '${name.padRight(22)}${fa.padRight(18)}${_bar(v)} ${_pct(v)}');
    }

    line('Intent Accuracy', 'دقت نیت/موضوع', intentAccuracy);
    line('Route Accuracy', 'دقت مسیر', routeAccuracy);
    line('RAG Article Recall', 'یادآوری ماده', articleRecallSoft);
    line('Citation Accuracy', 'دقت استناد', citationAccuracy);
    line('Honesty Rate', 'صداقت', honestyRate);
    line('Scenario Pass', 'عبور سناریو', passRate);
    sb.writeln('سناریوهای ناموفق: ${failed.length}');
    if (verbose && failed.isNotEmpty) {
      sb.writeln('');
      for (final o in failed.take(maxFailures)) {
        sb.writeln('✗ ${o.scenario.id} — «${o.scenario.query}»');
        for (final f in o.failures) {
          sb.writeln('    • $f');
        }
      }
      if (failed.length > maxFailures) {
        sb.writeln('… و ${failed.length - maxFailures} سناریوی ناموفق دیگر');
      }
    }
    return sb.toString();
  }
}

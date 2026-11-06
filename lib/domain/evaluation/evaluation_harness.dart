import 'package:dastyar/core/debug_logger.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/guard/citation_guard.dart';
import 'package:dastyar/domain/intent_net.dart';
import 'package:dastyar/domain/legal_counselor.dart';
import 'package:dastyar/domain/templates.dart';

import 'evaluation_dataset.dart';
import 'evaluation_report.dart';

/// موتور ارزیابی «سرتاسری» دستیار حقوقی.
///
/// چرا این کلاس لازم است؟ تست‌های واحد ثابت می‌کنند هر قطعه درست کار
/// می‌کند؛ این هارنس همان مسیری را می‌پیماید که پیام واقعی کاربر می‌پیماید:
///
/// پیام کاربر → LegalCounselor.step → تشخیص نیت → مسیر (RAG / مشاوره /
/// گفتگوی کوتاه / پذیرش) → بازیابی مواد → پاسخ نهایی
///
/// و سپس پاسخ را با «حقیقت مرجع» (سناریوهای طلایی) مقایسه می‌کند:
/// موضوع درست؟ مسیر درست؟ مادهٔ درست بازیابی شد؟ همان ماده استناد شد؟ و
/// وقتی دانشی نیست، ربات سکوت/صداقت را رعایت کرد؟
///
/// این هارنس هیچ مدل زبانی لازم ندارد: مسیر پاسخِ قطعی (بدون LLM) را
/// می‌سنجد. سنجش خروجی مدل زبانی، لایهٔ بعدیِ همین گزارش است و از طریق
/// [DebugLogger] (پرامپت + خروجی مدل) قابل افزودن است.
class EvaluationHarness {
  final KnowledgeEngine engine;
  final IntentNet? net;
  final List<LegalTemplate> templates;

  /// لاگر مشترک؛ با روشن‌بودن آن، ردِ کامل هر سناریو در گزارش JSON می‌آید.
  final DebugLogger logger;

  /// حداکثر پاسخ‌های بعدی که از سناریو اجرا می‌شود.
  final int maxFollowUps;

  EvaluationHarness(
    this.engine, {
    this.net,
    this.templates = const <LegalTemplate>[],
    DebugLogger? logger,
    this.maxFollowUps = 3,
  }) : logger = logger ?? DebugLogger();

  /// اجرای کل دیتاست (یا [limit] سناریوی نخست).
  EvaluationReport run(
    EvaluationDataset dataset, {
    int? limit,
    void Function(ScenarioOutcome outcome)? onScenario,
  }) {
    final selected = limit == null
        ? dataset.scenarios
        : dataset.scenarios.take(limit).toList();
    final outcomes = <ScenarioOutcome>[];
    for (final scenario in selected) {
      final outcome = runScenario(scenario);
      outcomes.add(outcome);
      if (onScenario != null) onScenario(outcome);
    }
    return EvaluationReport(
      outcomes: List<ScenarioOutcome>.unmodifiable(outcomes),
      datasetSize: dataset.length,
    );
  }

  /// اجرای یک سناریو و ساختن نتیجهٔ قابل‌سنجش.
  ScenarioOutcome runScenario(EvaluationScenario scenario) {
    final sw = Stopwatch()..start();
    final retrieved = <RetrievedArticle>[];
    final answers = <String>[];

    String? route;
    String? topic;
    var ragMissed = false;
    final failures = <String>[];

    if (scenario.entry == ScenarioEntry.counseling) {
      final started = LegalCounselor.start(
        scenario.query,
        engine,
        templates,
        net: net,
        replies: engine.replies,
      );
      if (started == null) {
        return ScenarioOutcome(
          scenario: scenario,
          topic: null,
          route: null,
          retrieved: const <RetrievedArticle>[],
          matched: const <ExpectedArticle>[],
          citedArticles: const <String>{},
          answer: '',
          ragMissed: false,
          elapsedMs: sw.elapsedMilliseconds,
          failures: <String>['موضوع حقوقی از پیام کاربر تشخیص داده نشد'],
        );
      }
      final (startedSession, firstTurn) = started;
      route = 'counseling';
      topic = startedSession.topicId;
      _addHits(firstTurn.ragReply, retrieved);
      answers.add(firstTurn.text);

      final session = startedSession;
      final followUps = scenario.followUps.take(maxFollowUps).toList();
      for (final followUp in followUps) {
        if (session.concluded) break;
        final traced = LegalCounselor.stepTraced(
          session,
          followUp,
          engine,
          templates,
          net: net,
          replies: engine.replies,
          logger: logger,
        );
        _addHits(traced.turn.ragReply, retrieved);
        answers.add(traced.turn.text);
      }
    } else {
      final session = CounselingSession(
        topicId: 'general_intake',
        initialMessage: scenario.query,
      );
      final traced = LegalCounselor.stepTraced(
        session,
        scenario.query,
        engine,
        templates,
        net: net,
        replies: engine.replies,
        logger: logger,
      );
      route = traced.route?.name;
      topic = session.topicId;
      ragMissed = traced.route == CounselorRoute.rag &&
          traced.turn.ragReply == null;
      _addHits(traced.turn.ragReply, retrieved);
      answers.add(traced.turn.text);

      final followUps = scenario.followUps.take(maxFollowUps).toList();
      for (final followUp in followUps) {
        if (session.concluded) break;
        final next = LegalCounselor.stepTraced(
          session,
          followUp,
          engine,
          templates,
          net: net,
          replies: engine.replies,
          logger: logger,
        );
        _addHits(next.turn.ragReply, retrieved);
        answers.add(next.turn.text);
      }
    }

    final answer = answers.isEmpty ? '' : answers.last;
    final cited = CitationGuard.citedArticles(answer);
    final matched = scenario.expectedArticles
        .where((expected) => retrieved.any((hit) =>
            hit.lawId == expected.lawId &&
            ExpectedArticle.canonicalArticle(hit.article) == expected.article))
        .toList();

    if (scenario.expectedTopic != null && topic != scenario.expectedTopic) {
      failures.add(
        'موضوع: انتظار «${scenario.expectedTopic}» ولی «$topic» تشخیص داده شد',
      );
    }
    if (scenario.expectedRoute != null && route != scenario.expectedRoute) {
      failures.add(
        'مسیر: انتظار «${scenario.expectedRoute}» ولی «${route ?? 'نامشخص'}» انتخاب شد',
      );
    }
    for (final expected in scenario.expectedArticles) {
      if (!matched.contains(expected)) {
        failures.add(
            'بازیابی: «${expected.lawId}/${expected.article}» پیدا نشد');
      } else if (!cited.contains(expected.citationKey)) {
        failures.add(
            'استناد: «${expected.article}» بازیابی شد ولی در پاسخ نیامد');
      }
    }
    if (scenario.expectsNoCitation && cited.isNotEmpty) {
      failures.add(
          'صداقت: پاسخ بدون پشتوانه، استناد ساخت (${cited.join('، ')})');
    }
    if (scenario.expectsRagMiss && !ragMissed) {
      failures.add('صداقت: بانک قوانین صریحاً نگفت «پیدا نکردم»');
    }

    return ScenarioOutcome(
      scenario: scenario,
      topic: topic,
      route: route,
      retrieved: List<RetrievedArticle>.unmodifiable(retrieved),
      matched: List<ExpectedArticle>.unmodifiable(matched),
      citedArticles: cited,
      answer: answer,
      ragMissed: ragMissed,
      elapsedMs: sw.elapsedMilliseconds,
      failures: List<String>.unmodifiable(failures),
    );
  }

  void _addHits(EngineReply? reply, List<RetrievedArticle> out) {
    if (reply == null) return;
    for (final hit in reply.contextHits) {
      final article = ExpectedArticle.canonicalArticle(hit.chunk.title);
      final duplicate = out.any(
          (r) => r.lawId == hit.chunk.lawId && r.article == article);
      if (duplicate) continue;
      out.add(RetrievedArticle(
        lawId: hit.chunk.lawId,
        article: article,
        source: hit.chunk.source,
        score: hit.score,
      ));
    }
  }
}
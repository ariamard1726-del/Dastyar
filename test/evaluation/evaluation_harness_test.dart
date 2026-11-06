import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/debug_logger.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/evaluation/evaluation_dataset.dart';
import 'package:dastyar/domain/evaluation/evaluation_harness.dart';
import 'package:dastyar/domain/intent_net.dart';
import 'package:dastyar/domain/legal_counselor.dart';
import 'package:dastyar/domain/templates.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;
  late IntentNet net;
  late EvaluationDataset dataset;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
    net = IntentNet.fromJson(
      jsonDecode(
        File('assets/brain/intent_model.json').readAsStringSync(),
      ) as Map<String, dynamic>,
    );
    dataset = EvaluationDataset.fromJsonString(
      File(EvaluationDataset.defaultPath).readAsStringSync(),
    );
  });

  EvaluationHarness harness({DebugLogger? logger}) => EvaluationHarness(
        engine,
        net: net,
        logger: logger,
      );

  group('دیتاست طلایی', () {
    test('حداقل ۲۰ سناریو با شناسهٔ یکتا و انتظارهای معتبر دارد', () {
      expect(dataset.length, greaterThanOrEqualTo(20));
      expect(
        dataset.validate(knownLawIds: engine.catalog.map((l) => l.id).toSet()),
        isEmpty,
      );
    });

    test('هر مادهٔ انتظاررفته در بستهٔ قوانین واقعاً وجود دارد', () {
      for (final scenario in dataset.scenarios) {
        for (final article in scenario.expectedArticles) {
          final chunk = engine.findArticle(article.lawId, article.article);
          expect(
            chunk,
            isNotNull,
            reason: '${scenario.id}: ${article.lawId}/${article.article}',
          );
        }
      }
    });

    test('عنوان مواد در دیتاست با عنوان چانک موتور یکسان است', () {
      for (final scenario in dataset.scenarios) {
        for (final article in scenario.expectedArticles) {
          final chunk = engine.findArticle(article.lawId, article.article);
          expect(
            ExpectedArticle.canonicalArticle(chunk!.title),
            article.article,
            reason: '${scenario.id}: canonical mismatch',
          );
        }
      }
    });
  });

  group('EvaluationHarness — یک سناریو', () {
    test('پرسش مستقیم ماده، مسیر RAG و بازیابی درست را می‌سنجد', () {
      const scenario = EvaluationScenario(
        id: 'smoke-article-lookup',
        query: 'ماده ۴۶۶ قانون مدنی چه می‌گوید؟',
        expectedRoute: 'rag',
        expectedArticles: <ExpectedArticle>[
          ExpectedArticle(lawId: 'civil', article: 'ماده 466'),
        ],
      );

      final outcome = harness().runScenario(scenario);

      expect(outcome.route, 'rag');
      expect(outcome.hasExpectedArticles, isTrue);
      expect(outcome.matched, hasLength(1));
      expect(outcome.articleRecall, 1.0);
      expect(
        outcome.failures,
        isEmpty,
        reason: outcome.failures.join(' | '),
      );
      expect(outcome.passed, isTrue);
    });

    test('پرسش بی‌ربط هیچ استناد قانونی تولید نمی‌کند', () {
      const scenario = EvaluationScenario(
        id: 'smoke-greeting',
        query: 'سلام، وقت بخیر',
        expectedRoute: 'smallTalk',
        expectsNoCitation: true,
      );

      final outcome = harness().runScenario(scenario);

      expect(outcome.route, 'smallTalk');
      expect(outcome.citedArticles, isEmpty);
      expect(outcome.passed, isTrue, reason: outcome.failures.join(' | '));
    });

    test('رونوشت نوبت‌ها در لاگر ثبت می‌شود', () {
      final logger = DebugLogger(enabled: true);
      const scenario = EvaluationScenario(
        id: 'smoke-trace',
        query: 'ماده ۴۶۶ قانون مدنی چه می‌گوید؟',
      );

      harness(logger: logger).runScenario(scenario);

      expect(logger.traces, hasLength(1));
      final stages = logger.traces.first.events.map((e) => e.stage).toSet();
      expect(stages, contains(TurnStage.input));
      expect(stages, contains(TurnStage.retrieval));
      expect(stages, contains(TurnStage.response));
      expect(logger.traces.first.route, isNotNull);
    });
  });

  group('EvaluationHarness — گزارش', () {
    test('معیارهای تجمیعی در بازهٔ ۰..۱ و قابل تبدیل به JSON هستند', () {
      final report = harness().run(dataset, limit: 5);

      expect(report.outcomes, hasLength(5));
      expect(report.datasetSize, dataset.length);
      for (final metric in <double>[
        report.intentAccuracy,
        report.routeAccuracy,
        report.articleRecall,
        report.articleRecallSoft,
        report.citationAccuracy,
        report.honestyRate,
        report.passRate,
      ]) {
        expect(metric, inInclusiveRange(0.0, 1.0));
      }

      final json = report.toJson();
      expect(json['dataset_size'], dataset.length);
      expect((json['metrics'] as Map).containsKey('intent_accuracy'), isTrue);
      final text = report.toText();
      expect(text, contains('Intent Accuracy'));
      expect(text, contains('RAG Article Recall'));
    });

    test('گزارش کامل دیتاست را بدون خطا اجرا می‌کند', () {
      final report = harness().run(dataset);

      expect(report.outcomes, hasLength(dataset.length));
      expect(report.toText(verbose: true), contains('سناریوها: ${dataset.length}'));
      expect(report.passRate, greaterThan(0.0));
    });
  });

  group('LegalCounselor.stepTraced', () {
    test('مسیر و مراحل را برای یک پرسش حقوقی ثبت می‌کند', () {
      final logger = DebugLogger(enabled: true);
      final session = CounselingSession(
        topicId: 'general_intake',
        initialMessage: 'ماده ۴۶۶ قانون مدنی چه می‌گوید؟',
      );

      final traced = LegalCounselor.stepTraced(
        session,
        'ماده ۴۶۶ قانون مدنی چه می‌گوید؟',
        engine,
        const <LegalTemplate>[],
        net: net,
        logger: logger,
      );

      expect(traced.route, CounselorRoute.rag);
      expect(traced.turn.text, isNotEmpty);
      final stages = traced.trace.events.map((e) => e.stage).toList();
      expect(stages, contains(TurnStage.intent));
      expect(stages, contains(TurnStage.slots));
      expect(stages, contains(TurnStage.retrieval));
      expect(stages, contains(TurnStage.response));
      expect(traced.trace.route, 'rag');
      expect(logger.traces, hasLength(1));
    });

    test('اگر لاگر خاموش باشد، رفتار step تغییر نمی‌کند', () {
      final logs = DebugLogger(enabled: true);
      final silent = DebugLogger();

      final a = CounselingSession(topicId: 'general_intake', initialMessage: 'چک');
      final b = CounselingSession(topicId: 'general_intake', initialMessage: 'چک');
      const query = 'ماده ۴۶۶ قانون مدنی چه می‌گوید؟';

      final tracedOn = LegalCounselor.stepTraced(
        a, query, engine, const <LegalTemplate>[], net: net, logger: logs);
      final tracedOff = LegalCounselor.stepTraced(
        b, query, engine, const <LegalTemplate>[], net: net, logger: silent);

      expect(tracedOff.turn.text, tracedOn.turn.text);
      expect(tracedOff.route, tracedOn.route);
      expect(tracedOff.trace.events, isEmpty);
      expect(silent.traces, isEmpty);
      expect(logs.traces, hasLength(1));
    });
  });
}
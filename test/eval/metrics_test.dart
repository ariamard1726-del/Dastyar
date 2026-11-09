import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/tool/eval/metrics.dart';

void main() {
  group('Metrics', () {
    test('Wilson interval for proportions', () {
      // Arithmetic: successes=8, total=10 -> p=0.8
      // z=1.96, denominator = 1 + 3.8416/10 = 1.38416
      // center = (0.8 + 3.8416/20) / 1.38416 = (0.8 + 0.19208) / 1.38416 = 0.99208 / 1.38416 = 0.7167
      // halfWidth = 1.96 * sqrt(0.8*0.2/10 + 3.8416/400) / 1.38416 = 1.96 * sqrt(0.016 + 0.009604) / 1.38416
      // = 1.96 * sqrt(0.025604) / 1.38416 = 1.96 * 0.16001 / 1.38416 = 0.31362 / 1.38416 = 0.22658
      // Interval: [0.7167 - 0.22658, 0.7167 + 0.22658] = [0.4901, 0.9433]
      List<double> interval = Metrics.wilsonInterval(8, 10);
      expect(interval[0], greaterThanOrEqualTo(0.49));
      expect(interval[1], lessThanOrEqualTo(0.95));
    });

    test('Bootstrap F1 with fixed seed', () {
      // Matches: [true, true, false, true] -> 3/4 = 0.75
      List<bool> matches = [true, true, false, true];
      double f1 = Metrics.bootstrapF1(matches, iterations: 100, seed: 42);
      expect(f1, greaterThan(0.0));
      expect(f1, lessThan(1.0));
    });

    test('Topic retention', () {
      List<bool> keptTopic = [true, false, true, true];
      List<String> goldRelevance = ["continue", "related_side", "continue", "continue"];
      // total=3 (indices 0,2,3), success=2 (indices 0,2) -> p=0.666
      List<double> interval = Metrics.topicRetention(keptTopic, goldRelevance);
      expect(interval[0], greaterThan(0.0));
      expect(interval[1], lessThan(1.0));
    });

    test('False-link rate', () {
      List<bool> linkedIncorrectly = [false, true, true, false];
      List<String> goldRelevance = ["continue", "related_side", "topic_switch", "out_of_domain"];
      // total=2 (indices 1,2), success=2 (indices 1,2) -> p=1.0
      List<double> interval = Metrics.falseLinkRate(linkedIncorrectly, goldRelevance);
      expect(interval[0], greaterThan(0.9));
      expect(interval[1], equalTo(1.0));
    });

    test('OOD precision/recall', () {
      List<bool> predictedOod = [true, false, true, false];
      List<bool> goldOod = [true, false, false, true];
      // Precision: tp=1, fp=1 -> p=0.5
      List<double> prec = Metrics.oodPrecision(predictedOod, goldOod);
      expect(prec[0], greaterThan(0.0));
      // Recall: tp=1, fn=1 -> p=0.5
      List<double> rec = Metrics.oodRecall(predictedOod, goldOod);
      expect(rec[0], greaterThan(0.0));
    });

    test('Slot F1 bootstrap', () {
      List<bool> matches = [true, false, true, true, false];
      double f1 = Metrics.slotF1(matches);
      expect(f1, greaterThan(0.0));
    });

    test('Exact-article accuracy', () {
      List<bool> matches = [true, false, true];
      List<double> interval = Metrics.exactArticleAccuracy(matches, 3);
      expect(interval[0], greaterThan(0.0));
    });

    test('Law top-1', () {
      List<bool> matches = [true, true, false];
      List<double> interval = Metrics.lawTop1(matches, 3);
      expect(interval[0], greaterThan(0.0));
    });

    test('Article-in-top-3', () {
      List<bool> matches = [false, true, true];
      List<double> interval = Metrics.articleInTop3(matches, 3);
      expect(interval[0], greaterThan(0.0));
    });

    test('Risk-coverage points', () {
      List<bool> covered = [true, false, true, true];
      int points = Metrics.riskCoveragePoints(covered);
      expect(points, equals(3));
    });
  });
}

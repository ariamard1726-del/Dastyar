import 'dart:convert';
import 'dart:math';

class Metrics {
  // Wilson 95% interval for proportions
  static List<double> wilsonInterval(int successes, int total, double confidence = 0.95) {
    if (total == 0) return [0.0, 0.0];
    double p = successes / total;
    double z = 1.96; // for 95%
    double denominator = 1 + z * z / total;
    double center = (p + z * z / (2 * total)) / denominator;
    double halfWidth = z * sqrt(p * (1 - p) / total + z * z / (4 * total * total)) / denominator;
    return [(center - halfWidth).clamp(0.0, 1.0), (center + halfWidth).clamp(0.0, 1.0)];
  }

  // Bootstrap with FIXED seed for F1
  static double bootstrapF1(List<bool> matches, int iterations = 1000, int seed = 42) {
    if (matches.isEmpty) return 0.0;
    Random rng = Random(seed);
    List<double> f1s = [];
    int n = matches.length;
    for (int i = 0; i < iterations; i++) {
      int success = 0;
      for (int j = 0; j < n; j++) {
        int idx = rng.nextInt(n);
        if (matches[idx]) success++;
      }
      f1s.add(success / n);
    }
    f1s.sort();
    return f1s[iterations ~/ 2]; // median
  }

  // Topic retention: proportion of turns where gold_relevance == "continue" and engine kept topic
  static List<double> topicRetention(List<bool> keptTopic, List<String> goldRelevance) {
    int total = 0;
    int success = 0;
    for (int i = 0; i < keptTopic.length; i++) {
      if (goldRelevance[i] == "continue") {
        total++;
        if (keptTopic[i]) success++;
      }
    }
    return wilsonInterval(success, total);
  }

  // False-link rate: proportion of "related_side" or "topic_switch" that engine linked incorrectly
  static List<double> falseLinkRate(List<bool> linkedIncorrectly, List<String> goldRelevance) {
    int total = 0;
    int success = 0; // success here means "linked incorrectly" (false link)
    for (int i = 0; i < linkedIncorrectly.length; i++) {
      if (goldRelevance[i] == "related_side" || goldRelevance[i] == "topic_switch") {
        total++;
        if (linkedIncorrectly[i]) success++;
      }
    }
    return wilsonInterval(success, total);
  }

  // OOD precision/recall
  static List<double> oodPrecision(List<bool> predictedOod, List<bool> goldOod) {
    int tp = 0, fp = 0;
    for (int i = 0; i < predictedOod.length; i++) {
      if (predictedOod[i]) {
        if (goldOod[i]) tp++;
        else fp++;
      }
    }
    if (tp + fp == 0) return [0.0, 0.0];
    return wilsonInterval(tp, tp + fp);
  }

  static List<double> oodRecall(List<bool> predictedOod, List<bool> goldOod) {
    int tp = 0, fn = 0;
    for (int i = 0; i < predictedOod.length; i++) {
      if (goldOod[i]) {
        if (predictedOod[i]) tp++;
        else fn++;
      }
    }
    if (tp + fn == 0) return [0.0, 0.0];
    return wilsonInterval(tp, tp + fn);
  }

  // Slot F1 (bootstrap)
  static double slotF1(List<bool> slotMatches) {
    return bootstrapF1(slotMatches);
  }

  // Exact-article accuracy
  static List<double> exactArticleAccuracy(List<bool> matches, int total) {
    int success = matches.where((m) => m).length;
    return wilsonInterval(success, total);
  }

  // Law top-1
  static List<double> lawTop1(List<bool> matches, int total) {
    int success = matches.where((m) => m).length;
    return wilsonInterval(success, total);
  }

  // Article-in-top-3
  static List<double> articleInTop3(List<bool> matches, int total) {
    int success = matches.where((m) => m).length;
    return wilsonInterval(success, total);
  }

  // Risk-coverage points (simple count)
  static int riskCoveragePoints(List<bool> covered) {
    return covered.where((c) => c).length;
  }
}

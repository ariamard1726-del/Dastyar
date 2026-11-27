import 'package:dastyar/domain/advocate/text_sense.dart';

/// قاعده‌های خواندن واقعیت از پیام کاربر ([Slot.read] / [Slot.readPending])
/// و دروازهٔ موضوع ([Topic.gate]) بدون کلوژرهای بی‌نام.
abstract class ReadRule {
  const ReadRule();
  String? evalRead(String n);
  Map<String, dynamic> toJson();
}

class ReadYn extends ReadRule {
  final String yesPattern;
  final String noPattern;
  const ReadYn(this.yesPattern, this.noPattern);

  @override
  String? evalRead(String n) => Sense.yn(n, yesPattern, noPattern);

  @override
  Map<String, dynamic> toJson() =>
      {'op': 'yn', 'yes': yesPattern, 'no': noPattern};
}

class ReadCase {
  final String pattern;
  final String value;
  final bool word;
  const ReadCase(this.pattern, this.value, {this.word = false});

  Map<String, dynamic> toJson() =>
      {'pattern': pattern, 'value': value, if (word) 'word': true};
}

class ReadCases extends ReadRule {
  final List<ReadCase> cases;
  const ReadCases(this.cases);

  @override
  String? evalRead(String n) {
    for (final c in cases) {
      final hit = c.word ? Sense.word(n, c.pattern) : Sense.has(n, c.pattern);
      if (hit) return c.value;
    }
    return null;
  }

  @override
  Map<String, dynamic> toJson() =>
      {'op': 'cases', 'cases': [for (final c in cases) c.toJson()]};
}

class ReadAmount extends ReadRule {
  final bool loose;
  const ReadAmount({this.loose = false});

  @override
  String? evalRead(String n) =>
      (loose ? Sense.looseAmount(n) : Sense.amount(n))?.toString();

  @override
  Map<String, dynamic> toJson() => {'op': 'amount', 'loose': loose};
}

class ReadNumBefore extends ReadRule {
  final String unitPattern;
  final int min;
  final int max;
  final bool fallbackLoose;
  const ReadNumBefore(this.unitPattern,
      {this.min = 1, this.max = 100, this.fallbackLoose = false});

  @override
  String? evalRead(String n) {
    final v = Sense.numberBefore(n, unitPattern) ??
        (fallbackLoose ? Sense.looseAmount(n) : null);
    if (v == null || v < min || v > max) return null;
    return '$v';
  }

  @override
  Map<String, dynamic> toJson() => {
        'op': 'numBefore',
        'unit': unitPattern,
        'min': min,
        'max': max,
        'fallbackLoose': fallbackLoose,
      };
}

class ReadSaysNoOrHas extends ReadRule {
  final String pattern;
  final String value;
  const ReadSaysNoOrHas(this.pattern, this.value);

  @override
  String? evalRead(String n) =>
      Sense.saysNo(n) || Sense.has(n, pattern) ? value : null;

  @override
  Map<String, dynamic> toJson() =>
      {'op': 'saysNoOrHas', 'pattern': pattern, 'value': value};
}

class ReadShortNonQuestion extends ReadRule {
  final String value;
  final int maxWords;
  const ReadShortNonQuestion(this.value, {this.maxWords = 6});

  @override
  String? evalRead(String n) =>
      Sense.words(n) <= maxWords && !Sense.isQuestion(n) ? value : null;

  @override
  Map<String, dynamic> toJson() =>
      {'op': 'shortNonQuestion', 'value': value, 'maxWords': maxWords};
}

class ReadSeq extends ReadRule {
  final List<ReadRule> steps;
  const ReadSeq(this.steps);

  @override
  String? evalRead(String n) {
    for (final s in steps) {
      final v = s.evalRead(n);
      if (v != null) return v;
    }
    return null;
  }

  @override
  Map<String, dynamic> toJson() =>
      {'op': 'seq', 'steps': [for (final s in steps) s.toJson()]};
}

abstract class GateRule {
  const GateRule();
  bool evalGate(String n);
  Map<String, dynamic> toJson();
}

class GateReadMatches extends GateRule {
  final ReadRule rule;
  const GateReadMatches(this.rule);

  @override
  bool evalGate(String n) => rule.evalRead(n) != null;

  @override
  Map<String, dynamic> toJson() =>
      {'op': 'readMatches', 'rule': rule.toJson()};
}

class GateWord extends GateRule {
  final String pattern;
  const GateWord(this.pattern);

  @override
  bool evalGate(String n) => Sense.word(n, pattern);

  @override
  Map<String, dynamic> toJson() => {'op': 'word', 'pattern': pattern};
}

class GateAllHas extends GateRule {
  final List<String> patterns;
  const GateAllHas(this.patterns);

  @override
  bool evalGate(String n) => patterns.every((p) => Sense.has(n, p));

  @override
  Map<String, dynamic> toJson() => {'op': 'allHas', 'patterns': patterns};
}

class GateAny extends GateRule {
  final List<GateRule> rules;
  const GateAny(this.rules);

  @override
  bool evalGate(String n) => rules.any((r) => r.evalGate(n));

  @override
  Map<String, dynamic> toJson() =>
      {'op': 'any', 'rules': [for (final r in rules) r.toJson()]};
}

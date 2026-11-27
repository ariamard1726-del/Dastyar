import 'package:dastyar/domain/advocate/case_model.dart';
import 'package:dastyar/domain/advocate/case_state.dart';
import 'package:dastyar/domain/advocate/reasoner.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';

class TextCase {
  final FactExpr when;
  final TextExpr thenText;
  const TextCase(this.when, this.thenText);
  Map<String, dynamic> toJson() =>
      {'when': when.toJson(), 'then': thenText.toJson()};
}

class TxCases extends TextExpr {
  final List<TextCase> cases;
  final TextExpr? fallback;
  const TxCases(this.cases, {this.fallback});

  @override
  String evalText(CaseFile f) {
    for (final c in cases) {
      if (c.when.evalCond(f)) return c.thenText.evalText(f);
    }
    return fallback?.evalText(f) ?? '';
  }

  @override
  Map<String, dynamic> toJson() => {
        'op': 'cases',
        'cases': [for (final c in cases) c.toJson()],
        if (fallback != null) 'fallback': fallback!.toJson(),
      };
}

/// قاعدهٔ رتبه‌بندی بحث (`Issue.rank`) بدون کلوژر.
abstract class RankRule {
  const RankRule();
  int evalRank(CaseFile f);
  Map<String, dynamic> toJson();
}

class RankConst extends RankRule {
  final int value;
  const RankConst(this.value);

  @override
  int evalRank(CaseFile f) => value;

  @override
  Map<String, dynamic> toJson() => {'op': 'const', 'value': value};
}

class RankCase {
  final FactExpr when;
  final int value;
  const RankCase(this.when, this.value);

  Map<String, dynamic> toJson() => {'when': when.toJson(), 'value': value};
}

class RankCases extends RankRule {
  final List<RankCase> cases;
  final int fallback;
  const RankCases(this.cases, {this.fallback = 0});

  @override
  int evalRank(CaseFile f) {
    for (final c in cases) {
      if (c.when.evalCond(f)) return c.value;
    }
    return fallback;
  }

  @override
  Map<String, dynamic> toJson() => {
        'op': 'cases',
        'cases': [for (final c in cases) c.toJson()],
        'fallback': fallback,
      };
}

/// قاعدهٔ انتخاب دادخواست/لایحه (`Topic.petition` / `Topic.brief`).
abstract class FilingRule {
  const FilingRule();
  Filing? evalFiling(CaseFile f);
  Map<String, dynamic> toJson();
}

class FilingSpec extends FilingRule {
  final String template;
  final TextExpr chip;
  final TextExpr name;
  const FilingSpec(this.template, this.chip, this.name);

  @override
  Filing evalFiling(CaseFile f) =>
      Filing(template, chip.evalText(f), name.evalText(f));

  @override
  Map<String, dynamic> toJson() => {
        'op': 'spec',
        'template': template,
        'chip': chip.toJson(),
        'name': name.toJson(),
      };
}

class FilingCase {
  final FactExpr when;
  final FilingRule? filing;
  const FilingCase(this.when, this.filing);

  Map<String, dynamic> toJson() => {
        'when': when.toJson(),
        if (filing != null) 'filing': filing!.toJson(),
      };
}

class FilingCases extends FilingRule {
  final List<FilingCase> cases;
  final FilingRule? fallback;
  const FilingCases(this.cases, {this.fallback});

  @override
  Filing? evalFiling(CaseFile f) {
    for (final c in cases) {
      if (c.when.evalCond(f)) return c.filing?.evalFiling(f);
    }
    return fallback?.evalFiling(f);
  }

  @override
  Map<String, dynamic> toJson() => {
        'op': 'cases',
        'cases': [for (final c in cases) c.toJson()],
        if (fallback != null) 'fallback': fallback!.toJson(),
      };
}

/// قاعدهٔ پرسش جایگزین موضوع (`Topic.askReply`).
abstract class PromptRule {
  const PromptRule();
  Prompt? evalPrompt(CaseFile f);
  Map<String, dynamic> toJson();
}

class PromptNone extends PromptRule {
  const PromptNone();

  @override
  Prompt evalPrompt(CaseFile f) => Prompt.none;

  @override
  Map<String, dynamic> toJson() => {'op': 'none'};
}

class PromptSpec extends PromptRule {
  final TextExpr text;
  final List<TextExpr> chips;
  const PromptSpec(this.text, this.chips);

  @override
  Prompt evalPrompt(CaseFile f) =>
      Prompt(text.evalText(f), [for (final c in chips) c.evalText(f)]);

  @override
  Map<String, dynamic> toJson() => {
        'op': 'spec',
        'text': text.toJson(),
        'chips': [for (final c in chips) c.toJson()],
      };
}

class PromptCase {
  final FactExpr when;
  final PromptRule? prompt;
  const PromptCase(this.when, this.prompt);

  Map<String, dynamic> toJson() => {
        'when': when.toJson(),
        if (prompt != null) 'prompt': prompt!.toJson(),
      };
}

class PromptCases extends PromptRule {
  final List<PromptCase> cases;
  final PromptRule? fallback;
  const PromptCases(this.cases, {this.fallback});

  @override
  Prompt? evalPrompt(CaseFile f) {
    for (final c in cases) {
      if (c.when.evalCond(f)) return c.prompt?.evalPrompt(f);
    }
    return fallback?.evalPrompt(f);
  }

  @override
  Map<String, dynamic> toJson() => {
        'op': 'cases',
        'cases': [for (final c in cases) c.toJson()],
        if (fallback != null) 'fallback': fallback!.toJson(),
      };
}

/// قاعدهٔ پرکردن فیلدهای قالب (`Topic.fill`).
class FillAssign {
  final String field;
  final TextExpr value;
  final FactExpr? when;
  const FillAssign(this.field, this.value, {this.when});

  Map<String, dynamic> toJson() => {
        'field': field,
        if (when != null) 'when': when!.toJson(),
        'value': value.toJson(),
      };
}

class FillRule {
  final Map<String, List<FillAssign>> templates;
  const FillRule(this.templates);

  Map<String, String> evalFill(CaseFile f, String template) {
    final rules = templates[template];
    if (rules == null) return <String, String>{};
    final out = <String, String>{};
    for (final a in rules) {
      if (a.when != null && !a.when!.evalCond(f)) continue;
      final v = a.value.evalText(f);
      if (v.isEmpty) {
        out.remove(a.field);
      } else {
        out[a.field] = v;
      }
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
        for (final e in templates.entries)
          e.key: [for (final a in e.value) a.toJson()],
      };
}

/// جمع‌بندی خواسته‌های زندهٔ موضوع بر پایهٔ `Reasoner.assessClaims`.
class TxAssessDemands extends TextExpr {
  final List<Claim> claims;
  final TextExpr replaceLabel;
  final TextExpr replacedText;
  final TextExpr extra;
  final TextExpr separator;
  const TxAssessDemands({
    required this.claims,
    required this.replaceLabel,
    required this.replacedText,
    required this.extra,
    required this.separator,
  });

  @override
  String evalText(CaseFile f) {
    final out = <String>[];
    final target = replaceLabel.evalText(f);
    for (final v in Reasoner.assessClaims(claims, f)) {
      if (v.standing == Standing.weak) continue;
      final l = v.claim.label;
      if (l.isEmpty) continue;
      out.add(l == target ? replacedText.evalText(f) : l);
    }
    out.add(extra.evalText(f));
    return out.join(separator.evalText(f));
  }

  @override
  Map<String, dynamic> toJson() => {
        'op': 'assessDemands',
        'claimsCount': claims.length,
        'replaceLabel': replaceLabel.toJson(),
        'replacedText': replacedText.toJson(),
        'extra': extra.toJson(),
        'separator': separator.toJson(),
      };
}

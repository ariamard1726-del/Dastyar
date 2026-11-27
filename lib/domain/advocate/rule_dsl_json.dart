import 'package:dastyar/domain/advocate/case_model.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';

/// نگهداری AST قواعد DSL برای هر سازنده و سریال‌سازی JSON آن.
class ElementRules {
  final FactExpr test;
  final TextExpr? because;
  const ElementRules(this.test, {this.because});
}

class ClaimRules {
  final FactExpr? when;
  final TextExpr win;
  final TextExpr? counter;
  const ClaimRules({this.when, required this.win, this.counter});
}

class SlotRules {
  final ReadRule read;
  final ReadRule? readPending;
  final TextExpr? effect;
  final FactExpr? when;
  final ReadRule? readSure;
  const SlotRules({
    required this.read,
    this.readPending,
    this.effect,
    this.when,
    this.readSure,
  });
}

class IssueRules {
  final TextExpr body;
  final FactExpr? when;
  final RankRule? rank;
  const IssueRules({required this.body, this.when, this.rank});
}

class TopicRules {
  final GateRule? gate;
  final TextExpr opening;
  final Map<String, TextExpr> follow;
  final DraftRule? drafts;
  final List<RecapItem>? recap;
  final FilingRule? petition;
  final FilingRule? brief;
  final FillRule? fill;
  final PromptRule? askReply;
  const TopicRules({
    this.gate,
    required this.opening,
    required this.follow,
    this.drafts,
    this.recap,
    this.petition,
    this.brief,
    this.fill,
    this.askReply,
  });
}

extension ElementRuleJson on Element {
  Map<String, dynamic> toJson() => {
        'text': text,
        if (ifNo.isNotEmpty) 'ifNo': ifNo,
        if (needs.isNotEmpty) 'needs': needs,
        if (rules != null) 'test': rules!.test.toJson(),
        if (rules?.because != null) 'because': rules!.because!.toJson(),
      };
}

extension ClaimRuleJson on Claim {
  Map<String, dynamic> toJson() => {
        if (label.isNotEmpty) 'label': label,
        'goal': goal,
        if (cues.isNotEmpty) 'cues': cues,
        if (uses.isNotEmpty) 'uses': uses,
        if (rules?.when != null) 'when': rules!.when!.toJson(),
        'elements': [for (final e in elements) e.toJson()],
        if (rules != null) 'win': rules!.win.toJson(),
        if (rules?.counter != null) 'counter': rules!.counter!.toJson(),
      };
}

extension SlotRuleJson on Slot {
  Map<String, dynamic> toJson() => {
        'id': id,
        'ask': ask,
        if (options.isNotEmpty) 'options': options,
        if (sticky) 'sticky': true,
        if (priority.isNotEmpty) 'priority': priority,
        if (rules != null) 'read': rules!.read.toJson(),
        if (rules?.readPending != null) 'readPending': rules!.readPending!.toJson(),
        if (rules?.readSure != null) 'readSure': rules!.readSure!.toJson(),
        if (rules?.effect != null) 'effect': rules!.effect!.toJson(),
        if (rules?.when != null) 'when': rules!.when!.toJson(),
      };
}

extension IssueRuleJson on Issue {
  Map<String, dynamic> toJson() => {
        'id': id,
        'chip': chip,
        'cues': cues,
        if (covers.isNotEmpty) 'covers': covers.toList(),
        if (rules != null) 'body': rules!.body.toJson(),
        if (rules?.when != null) 'when': rules!.when!.toJson(),
        if (rules?.rank != null) 'rank': rules!.rank!.toJson(),
      };
}

extension TopicRuleJson on Topic {
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cues': cues,
        if (anti.isNotEmpty) 'anti': anti,
        if (rules?.gate != null) 'gate': rules!.gate!.toJson(),
        if (rules != null) 'opening': rules!.opening.toJson(),
        if (rules != null)
          'follow': {for (final e in rules!.follow.entries) e.key: e.value.toJson()},
        if (rules?.drafts != null) 'drafts': rules!.drafts!.toJson(),
        if (rules?.recap != null) 'recap': [for (final r in rules!.recap!) r.toJson()],
        if (rules?.petition != null) 'petition': rules!.petition!.toJson(),
        if (rules?.brief != null) 'brief': rules!.brief!.toJson(),
        if (rules?.fill != null) 'fill': rules!.fill!.toJson(),
        if (rules?.askReply != null) 'askReply': rules!.askReply!.toJson(),
        'slots': [for (final s in slots) s.toJson()],
        'issues': [for (final i in issues) i.toJson()],
        if (claims.isNotEmpty) 'claims': [for (final c in claims) c.toJson()],
      };
}

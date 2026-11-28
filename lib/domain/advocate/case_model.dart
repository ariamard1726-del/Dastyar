import 'package:dastyar/domain/advocate/case_state.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';

// زبانِ موضوع: شرط (`Element`)، ادعا (`Claim`)، واقعیت (`Slot`)، بحث
// (`Issue`)، سند (`Filing`)، پرسشِ موضوع (`Prompt`) و خودِ موضوع (`Topic`).
// فایل‌های داده‌ای موضوع فقط همین مدل‌ها را می‌سازند و کاری با مکانِ
// ذخیرهٔ پرونده ندارند.
typedef Body = String Function(CaseFile f);
typedef Reader = String? Function(String n);
typedef Cond = bool Function(CaseFile f);
typedef Tri = bool? Function(CaseFile f);

/// یک شرط قانونی که برای رسیدن به یک نتیجه باید برقرار باشد.
class Element {
  final String text;
  final Tri test;
  final String ifNo;
  final List<String> needs;
  final Body? because;
  final ElementRules? rules;

  const Element(
    this.text,
    this.test, {
    this.ifNo = '',
    this.needs = const [],
    this.because,
  }) : rules = null;

  Element.dsl(
    this.text,
    FactExpr rule, {
    this.ifNo = '',
    this.needs = const [],
    TextExpr? because,
  })    : test = rule.evalTri,
        because = because == null ? null : because.evalText,
        rules = ElementRules(rule, because: because);
}

/// یک ادعای حقوقی و شرط‌هایش: کدام شواهد چه نتیجه‌ای می‌دهند.
class Claim {
  final String label;
  final String goal;
  final Cond? when;
  final List<Element> elements;
  final Body win;
  final Body? counter;
  final List<String> uses;
  final String cues;
  final ClaimRules? rules;

  const Claim({
    required this.goal,
    required this.elements,
    required this.win,
    this.label = '',
    this.when,
    this.counter,
    this.uses = const [],
    this.cues = '',
  }) : rules = null;

  Claim.dsl({
    required this.goal,
    required this.elements,
    required TextExpr win,
    this.label = '',
    FactExpr? when,
    TextExpr? counter,
    this.uses = const [],
    this.cues = '',
  })    : win = win.evalText,
        when = when == null ? null : when.evalCond,
        counter = counter == null ? null : counter.evalText,
        rules = ClaimRules(when: when, win: win, counter: counter);
}

/// یک واقعیتِ مهم پرونده که وکیل باید بداند و اگر کاربر نگفت، بپرسد.
class Slot {
  final String id;
  final String ask;
  final String why;
  final List<String> options;
  final Reader read;
  final Reader? readPending;
  final String yesValue;
  final String noValue;
  final Body? effect;
  final Cond? when;
  final bool first;
  final bool sticky;
  final List<String> priority;
  final String? Function(String n)? readSure;
  final SlotRules? rules;

  Slot({
    required this.id,
    required this.ask,
    required this.why,
    required this.read,
    this.readPending,
    this.options = const [],
    this.yesValue = 'yes',
    this.noValue = 'no',
    this.effect,
    this.when,
    this.first = false,
    this.sticky = false,
    this.priority = const [],
    this.readSure,
  }) : rules = null;

  Slot.dsl({
    required this.id,
    required this.ask,
    required this.why,
    required ReadRule read,
    ReadRule? readPending,
    this.options = const [],
    this.yesValue = 'yes',
    this.noValue = 'no',
    TextExpr? effect,
    FactExpr? when,
    this.first = false,
    this.sticky = false,
    this.priority = const [],
    ReadRule? readSure,
  })    : read = read.evalRead,
        readPending = readPending == null ? null : readPending.evalRead,
        effect = effect == null ? null : effect.evalText,
        when = when == null ? null : when.evalCond,
        readSure = readSure == null ? null : readSure.evalRead,
        rules = SlotRules(
          read: read,
          readPending: readPending,
          effect: effect,
          when: when,
          readSure: readSure,
        );
}

/// پرسشی که کاربر ممکن است در این موضوع بپرسد و پاسخ وکیل به آن.
class Issue {
  final String id;
  final String chip;
  final String cues;
  final Body body;
  final Cond? when;
  final Set<String> covers;
  final int Function(CaseFile f)? rank;
  final IssueRules? rules;

  Issue({
    required this.id,
    required this.chip,
    required this.cues,
    required this.body,
    this.when,
    this.covers = const {},
    this.rank,
  }) : rules = null;

  Issue.dsl({
    required this.id,
    required this.chip,
    required this.cues,
    required TextExpr body,
    FactExpr? when,
    this.covers = const {},
    RankRule? rank,
  })    : body = body.evalText,
        when = when == null ? null : when.evalCond,
        rank = rank == null ? null : rank.evalRank,
        rules = IssueRules(body: body, when: when, rank: rank);
}

/// سندی که وکیل برای همین پرونده پیشنهاد می‌کند.
class Filing {
  final String template;
  final String chip;
  final String name;
  const Filing(this.template, this.chip, this.name);
}

/// پرسشی که خودِ موضوع به‌جای پرسشِ عمومیِ وکیل می‌پرسد، با گزینه‌های جوابش.
class Prompt {
  final String text;
  final List<String> chips;
  const Prompt(this.text, [this.chips = const []]);
  static const Prompt none = Prompt('');
}

class Topic {
  final String id;
  final String title;
  final Map<String, int> cues;
  final String anti;
  final bool Function(String n)? gate;
  final List<Slot> slots;
  final List<Issue> issues;
  final Body opening;
  final Map<String, Body> follow;
  final List<String> Function(CaseFile f)? drafts;
  final List<Claim> claims;
  final List<String> Function(CaseFile f)? recap;
  final Filing? Function(CaseFile f)? petition;
  final Filing? Function(CaseFile f)? brief;
  final Map<String, String> Function(CaseFile f, String template)? fill;
  final Prompt? Function(CaseFile f)? askReply;
  final TopicRules? rules;

  Topic({
    required this.id,
    required this.title,
    required this.cues,
    required this.slots,
    required this.issues,
    required this.opening,
    required this.follow,
    this.anti = '',
    this.gate,
    this.drafts,
    this.claims = const [],
    this.recap,
    this.petition,
    this.brief,
    this.fill,
    this.askReply,
  }) : rules = null;

  Topic.dsl({
    required this.id,
    required this.title,
    required this.cues,
    required this.slots,
    required this.issues,
    required TextExpr opening,
    required Map<String, TextExpr> follow,
    this.anti = '',
    GateRule? gate,
    DraftRule? drafts,
    this.claims = const [],
    List<RecapItem>? recap,
    FilingRule? petition,
    FilingRule? brief,
    FillRule? fill,
    PromptRule? askReply,
  })    : gate = gate == null ? null : gate.evalGate,
        opening = opening.evalText,
        follow = {for (final e in follow.entries) e.key: e.value.evalText},
        drafts = drafts == null ? null : drafts.evalDrafts,
        recap = recap == null ? null : RecapRule(recap).evalRecap,
        petition = petition == null ? null : petition.evalFiling,
        brief = brief == null ? null : brief.evalFiling,
        fill = fill == null ? null : fill.evalFill,
        askReply = askReply == null ? null : askReply.evalPrompt,
        rules = TopicRules(
          gate: gate,
          opening: opening,
          follow: follow,
          drafts: drafts,
          recap: recap,
          petition: petition,
          brief: brief,
          fill: fill,
          askReply: askReply,
        );

  bool get isDeclarative => rules != null;
}

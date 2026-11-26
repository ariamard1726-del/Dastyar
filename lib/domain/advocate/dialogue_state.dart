import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/dialogue_sections.dart';
import 'package:dastyar/domain/lawyer/legal_guides.dart';

/// آنچه در این نوبت «روی میز» است، بهصورت یک نمایندهٔ نازک.
///
/// پیشتر این ۲۵ فیلد مستقیم روی همین کلاس بودند (گاد-آبجکت). اکنون پنج تکهٔ
/// مستقل دارند (`QuestionState`، `ChoiceState`، `GuideState`، `SafetyState`،
/// `UnclearState`) و این کلاس فقط delegating میکند تا صدها فراخوانِ موجود
/// (`dialog.askText = ...`) بی تغییر بمانند. همین تکهها قابل ذخیرهاند و
/// زمینهٔ قالب ۴ تاریخچهاند.
class DialogueState {
  DialogueState();

  QuestionState question = QuestionState();
  ChoiceState choice = ChoiceState();
  GuideState guideState = GuideState();
  SafetyState safety = SafetyState();
  UnclearState unclear = UnclearState();

  /// حرفهای کاربر پیش از بازشدن پرونده (حداکثر سه تای آخر).
  final List<String> loose = [];

  String get askText => question.askText;
  set askText(String v) => question.askText = v;
  List<String> get askChips => question.askChips;
  set askChips(List<String> v) => question.askChips = v;
  String get offer => question.offer;
  set offer(String v) => question.offer = v;
  String get offerDraft => question.offerDraft;
  set offerDraft(String v) => question.offerDraft = v;

  List<Topic> get choices => choice.choices;
  set choices(List<Topic> v) => choice.choices = v;
  String get choiceText => choice.choiceText;
  set choiceText(String v) => choice.choiceText = v;
  bool get guessed => choice.guessed;
  set guessed(bool v) => choice.guessed = v;
  Topic? get pendingTopic => choice.pendingTopic;
  set pendingTopic(Topic? v) => choice.pendingTopic = v;
  String get pendingText => choice.pendingText;
  set pendingText(String v) => choice.pendingText = v;
  Topic? get side => choice.side;
  set side(Topic? v) => choice.side = v;
  String get sideText => choice.sideText;
  set sideText(String v) => choice.sideText = v;
  Topic? get also => choice.also;
  set also(Topic? v) => choice.also = v;
  bool get branchAsked => choice.branchAsked;
  set branchAsked(bool v) => choice.branchAsked = v;

  LegalGuide? get guide => guideState.guide;
  set guide(LegalGuide? v) => guideState.guide = v;
  bool get guideAsked => guideState.guideAsked;
  set guideAsked(bool v) => guideState.guideAsked = v;
  bool get guideStepped => guideState.guideStepped;
  set guideStepped(bool v) => guideState.guideStepped = v;
  String get deferred => guideState.deferred;
  set deferred(String v) => guideState.deferred = v;
  String get lastServed => guideState.lastServed;
  set lastServed(String v) => guideState.lastServed = v;
  String get arguedOn => guideState.arguedOn;
  set arguedOn(String v) => guideState.arguedOn = v;
  String get heard => guideState.heard;
  set heard(String v) => guideState.heard = v;
  bool get roomy => guideState.roomy;
  set roomy(bool v) => guideState.roomy = v;

  String get safetyCarry => safety.safetyCarry;
  set safetyCarry(String v) => safety.safetyCarry = v;
  bool get safetyShown => safety.safetyShown;
  set safetyShown(bool v) => safety.safetyShown = v;
  String get lastSafetyText => safety.lastSafetyText;
  set lastSafetyText(String v) => safety.lastSafetyText = v;

  String get unclearPhrase => unclear.unclearPhrase;
  set unclearPhrase(String v) => unclear.unclearPhrase = v;
  int get unclearTurn => unclear.unclearTurn;
  set unclearTurn(int v) => unclear.unclearTurn = v;

  void clearOffer() => question.clearOffer();

  /// با بستهشدن پرونده: هرچه به همان پرونده مربوط بود پاک میشود.
  /// ترتیب و فیلدهای پاکشده عیناً همان رفتار پیشین است (رفتار تغییر نکرد).
  void clearCase() {
    choice.clearCase();
    guideState.clearCase();
    safety.clearCase();
    question.clearCase();
  }

  /// آغاز گفتگوی تازه.
  void reset() {
    clearCase();
    choice.reset();
    guideState.reset();
    safety.reset();
    unclear.reset();
    loose.clear();
  }

  static const int schemaVersion = 1;

  Map<String, dynamic> toJson() => {
        'v': schemaVersion,
        'question': question.toJson(),
        'choice': choice.toJson(),
        'guide': guideState.toJson(),
        'safety': safety.toJson(),
        'unclear': unclear.toJson(),
        'loose': List<String>.from(loose),
      };

  /// بازیابی از محمولهٔ تاریخچه. موضوعها و راهنماها با شناسهشان برگردانده
  /// میشوند؛ شناسهٔ ناشناخته دور ریخته میشود، نه اینکه پرونده را کراش دهد.
  factory DialogueState.fromJson(
    Map<String, dynamic> j, {
    Map<String, Topic>? topicById,
    Map<String, LegalGuide>? guideById,
  }) =>
      DialogueState()
        ..applyJson(j, topicById: topicById, guideById: guideById);

  void applyJson(
    Map<String, dynamic> j, {
    Map<String, Topic>? topicById,
    Map<String, LegalGuide>? guideById,
  }) {
    reset();
    final v = j['v'];
    if (v is int && v != schemaVersion) return;
    Map<String, dynamic> part(Object? key) =>
        j[key] is Map ? Map<String, dynamic>.from(j[key] as Map) : const {};
    question.absorb(QuestionState.fromJson(part('question')));
    choice.absorb(
        ChoiceState.fromJson(part('choice'), topicById: topicById));
    guideState.absorb(
        GuideState.fromJson(part('guide'), guideById: guideById));
    safety.absorb(SafetyState.fromJson(part('safety')));
    unclear.absorb(UnclearState.fromJson(part('unclear')));
    final rawLoose = j['loose'];
    if (rawLoose is List) {
      loose.addAll(rawLoose.whereType<String>().take(3));
    }
  }
}

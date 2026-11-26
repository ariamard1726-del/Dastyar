import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/lawyer/legal_guides.dart';

/// تکههای مستقلِ «آنچه روی میز است».
///
/// پیشتر ۲۵ فیلد روی [DialogueState] بود و هر کدام از دهها متد میتوانستند
/// هر کدام را عوض کنند. حالا هر گروه صاحبِ خودش را دارد و [DialogueState]
/// تنها یک نمایندهٔ نازک است. علاوه بر جدایی مسئولیت، همین تقسیم امکان
/// ذخیرهٔ وضعیت واقعی گفتگو را هم فراهم میکند (قالب ۴ تاریخچه).

/// پرسشی که پرسیدهایم، دکمههایش و پیشنهادِ معلق.
class QuestionState {
  QuestionState();
  String askText = '';
  List<String> askChips = const [];
  String offer = '';
  String offerDraft = '';

  void clearOffer() {
    offer = '';
    offerDraft = '';
  }

  void clearCase() {
    askText = '';
    askChips = const [];
    clearOffer();
  }

  void reset() => clearCase();

  Map<String, dynamic> toJson() => {
        'ask': askText,
        'chips': askChips,
        'offer': offer,
        'offerDraft': offerDraft,
      };

  factory QuestionState.fromJson(Map<String, dynamic> j) => QuestionState()
    ..askText = (j['ask'] ?? '').toString()
    ..askChips = _strings(j['chips'])
    ..offer = (j['offer'] ?? '').toString()
    ..offerDraft = (j['offerDraft'] ?? '').toString();

  void absorb(QuestionState o) {
    askText = o.askText;
    askChips = o.askChips;
    offer = o.offer;
    offerDraft = o.offerDraft;
  }
}

/// موضوعِ شناختهشده، موضوعِ منتظرِ تأیید، و موضوع دومی که وسط پرونده آمد.
class ChoiceState {
  ChoiceState();
  List<Topic> choices = const [];
  String choiceText = '';
  bool guessed = false;
  Topic? pendingTopic;
  String pendingText = '';
  Topic? side;
  String sideText = '';
  Topic? also;
  bool branchAsked = false;

  void clearCase() {
    pendingTopic = null;
    pendingText = '';
  }

  void reset() {
    choices = const [];
    choiceText = '';
    guessed = false;
    side = null;
    sideText = '';
    also = null;
    branchAsked = false;
    clearCase();
  }

  Map<String, dynamic> toJson() => {
        'choices': [for (final t in choices) t.id],
        'choiceText': choiceText,
        'guessed': guessed,
        'pendingTopic': pendingTopic?.id ?? '',
        'pendingText': pendingText,
        'side': side?.id ?? '',
        'sideText': sideText,
        'also': also?.id ?? '',
        'branchAsked': branchAsked,
      };

  factory ChoiceState.fromJson(Map<String, dynamic> j,
          {Map<String, Topic>? topicById}) =>
      ChoiceState()
        ..choices = _topics(j['choices'], topicById)
        ..choiceText = (j['choiceText'] ?? '').toString()
        ..guessed = j['guessed'] == true
        ..pendingTopic = _topic(j['pendingTopic'], topicById)
        ..pendingText = (j['pendingText'] ?? '').toString()
        ..side = _topic(j['side'], topicById)
        ..sideText = (j['sideText'] ?? '').toString()
        ..also = _topic(j['also'], topicById)
        ..branchAsked = j['branchAsked'] == true;

  void absorb(ChoiceState o) {
    choices = o.choices;
    choiceText = o.choiceText;
    guessed = o.guessed;
    pendingTopic = o.pendingTopic;
    pendingText = o.pendingText;
    side = o.side;
    sideText = o.sideText;
    also = o.also;
    branchAsked = o.branchAsked;
  }
}

/// راهنمای باز، آخرین بحث توضیح دادهشده و حافظهٔ مختصر پرونده.
class GuideState {
  GuideState();
  LegalGuide? guide;
  bool guideAsked = false;
  bool guideStepped = false;
  String deferred = '';
  String lastServed = '';
  String arguedOn = '';
  String heard = '';
  bool roomy = false;

  void clearCase() {
    guide = null;
    lastServed = '';
    deferred = '';
    arguedOn = '';
    heard = '';
    guideAsked = false;
  }

  void reset() {
    clearCase();
    guideStepped = false;
    roomy = false;
  }

  Map<String, dynamic> toJson() => {
        'guide': guide?.id ?? '',
        'guideAsked': guideAsked,
        'guideStepped': guideStepped,
        'deferred': deferred,
        'lastServed': lastServed,
        'arguedOn': arguedOn,
        'heard': heard,
        'roomy': roomy,
      };

  factory GuideState.fromJson(Map<String, dynamic> j,
          {Map<String, LegalGuide>? guideById}) =>
      GuideState()
        ..guide = _guide(j['guide'], guideById)
        ..guideAsked = j['guideAsked'] == true
        ..guideStepped = j['guideStepped'] == true
        ..deferred = (j['deferred'] ?? '').toString()
        ..lastServed = (j['lastServed'] ?? '').toString()
        ..arguedOn = (j['arguedOn'] ?? '').toString()
        ..heard = (j['heard'] ?? '').toString()
        ..roomy = j['roomy'] == true;

  void absorb(GuideState o) {
    guide = o.guide;
    guideAsked = o.guideAsked;
    guideStepped = o.guideStepped;
    deferred = o.deferred;
    lastServed = o.lastServed;
    arguedOn = o.arguedOn;
    heard = o.heard;
    roomy = o.roomy;
  }
}

/// پیام ایمنی و متنی که پاسخ ایمنی جایش را گرفت.
class SafetyState {
  SafetyState();
  String safetyCarry = '';
  bool safetyShown = false;

  /// متن دقیقی که آخرین بار هشدار ایمنی برایش داده شد. تنها همان متن تکراری
  /// سرکوب میشود؛ یک گزارش تازهٔ خشونت باید دوباره هشدار بگیرد.
  String lastSafetyText = '';

  void clearCase() {
    safetyShown = false;
    safetyCarry = '';
    lastSafetyText = '';
  }

  void reset() => clearCase();

  Map<String, dynamic> toJson() => {
        'carry': safetyCarry,
        'shown': safetyShown,
        'last': lastSafetyText,
      };

  factory SafetyState.fromJson(Map<String, dynamic> j) => SafetyState()
    ..safetyCarry = (j['carry'] ?? '').toString()
    ..safetyShown = j['shown'] == true
    ..lastSafetyText = (j['last'] ?? '').toString();

  void absorb(SafetyState o) {
    safetyCarry = o.safetyCarry;
    safetyShown = o.safetyShown;
    lastSafetyText = o.lastSafetyText;
  }
}

/// پیام نامفهومِ قبلی و نوبتِ آن.
class UnclearState {
  UnclearState();
  String unclearPhrase = '';
  int unclearTurn = -10;

  void reset() {
    unclearPhrase = '';
    unclearTurn = -10;
  }

  Map<String, dynamic> toJson() => {
        'phrase': unclearPhrase,
        'turn': unclearTurn,
      };

  factory UnclearState.fromJson(Map<String, dynamic> j) => UnclearState()
    ..unclearPhrase = (j['phrase'] ?? '').toString()
    ..unclearTurn = j['turn'] is int ? j['turn'] as int : -10;

  void absorb(UnclearState o) {
    unclearPhrase = o.unclearPhrase;
    unclearTurn = o.unclearTurn;
  }
}

List<String> _strings(Object? raw) {
  if (raw is! List) return const [];
  return [for (final e in raw) if (e != null) e.toString()];
}

Topic? _topic(Object? id, Map<String, Topic>? byId) =>
    id is String && id.isNotEmpty ? (byId?[id]) : null;

List<Topic> _topics(Object? raw, Map<String, Topic>? byId) {
  if (raw is! List || byId == null) return const [];
  // شناسهای ناشناخته دور ریخته میشود؛ موضوعِ ساختگی نباید وارد پرونده شود.
  return [for (final id in raw) if (id is String && byId.containsKey(id)) byId[id]!];
}

LegalGuide? _guide(Object? id, Map<String, LegalGuide>? byId) =>
    id is String && id.isNotEmpty ? (byId?[id]) : null;

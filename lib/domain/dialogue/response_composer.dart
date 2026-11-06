import 'dart:convert';

import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/core/utils/persian_normalizer.dart';
import 'package:dastyar/domain/dialogue/dialogue_action.dart';
import 'package:dastyar/domain/dialogue/dialogue_state.dart';
import 'package:dastyar/domain/dialogue/domain_slot_schemas.dart';
import 'package:dastyar/domain/dialogue/evidence.dart';
import 'package:dastyar/domain/dialogue/slots.dart';

/// خروجی Composer: متن فارسی + chips دکمه‌ها + variantId برای تست.
///
/// [text] همیشه فارسی است (بدون Latin، بدون ایموجی اضافی).
/// [chips] فهرست دکمه‌های چت برای این نوبت (اگر پاسخ نهایی باشد خالی).
/// [variantId] شناسه‌ای که تست‌ها می‌توانند بر اساس آن تکرار را تشخیص
/// دهند. در پاسخ‌های نهایی و خطاها `null` است.
class ComposedReply {
  final String text;
  final List<String> chips;
  final String? variantId;

  const ComposedReply({
    required this.text,
    this.chips = const [],
    this.variantId,
  });

  @override
  String toString() =>
      'ComposedReply(len: ${text.length}, chips: ${chips.length})';
}

/// ساخت پاسخ طبیعی فارسی از یک `DialogueAction` و وضعیت جاری.
///
/// این کلاس چهار مسئولیت دارد:
///   ۱. برای `AskForSlot`، یک سؤال طبیعی می‌سازد (با acknowledgment،
///      rationale، و نقل قول از کلمات کاربر).
///   ۲. برای `GiveAnswer`، پاسخ نهایی (بدون تکرار) می‌سازد.
///   ۳. برای `ExplainConflict`، تعارض را توضیح می‌دهد و گزینه‌ها را
///      به کاربر نشان می‌دهد.
///   ۴. برای `DisambiguateDomain`، از کاربر می‌خواهد دامنه را انتخاب
///      کند.
///
/// [composeAcknowledged] نیز مسیر گفتوگوییِ تکخطِ میان دو اسلات را
/// میسازد و برخلاف نسخهٔ پایه، rationale و شمارهگذاری ندارد.
///
/// **اصل anticedent variation**: انتخاب variant بر اساس
/// `hash(conversationId, variantFamily)` است. این کار deterministic
/// است (در دو اجرای مختلف، همان مکالمه → همان variant) و در ۳ turn
/// متوالی، هیچ variantId تکرار نمی‌شود (چون bank دقیقاً ۳ عضو دارد
/// و perm یک bijection است).
class ResponseComposer {
  const ResponseComposer();

  /// ترکیب یک `DialogueAction` به `ComposedReply`.
  ComposedReply compose(
    DialogueAction action,
    DialogueState state,
    EvidenceSet evidence,
  ) {
    switch (action) {
      case AskForSlot():
        return _composeAskForSlotBase(action, state);
      case GiveAnswer():
        return _composeGiveAnswer(action);
      case ExplainConflict():
        return _composeExplainConflict(action, state);
      case DisambiguateDomain():
        return _composeDisambiguateDomain(action, state);
    }
  }

  // ── AskForSlot ──────────────────────────────────────────────────

  /// نسخهٔ پایه و رسمی پرسش اسلات. رفتارش در Phase 3 دستنخورده ماند؛
  /// فقط نام آن به [_composeAskForSlotBase] تغییر کرد تا مسیر گفتوگویی
  /// [composeAcknowledged] از آن متمایز باشد.
  ComposedReply _composeAskForSlotBase(AskForSlot action, DialogueState state) {
    final schema = DomainSchemaRegistry.forDomain(state.domain);
    final slot = schema?.slotByName(action.slotKey);

    // acknowledgment بر اساس اطلاعات موجود در slot
    final acknowledgment = _pickAcknowledgment(state);
    final echo = _buildEcho(state);
    final rationaleText = action.rationale.isNotEmpty
        ? action.rationale
        : (slot?.rationale ?? '');
    final questionText = slot?.prompt ?? 'لطفاً اطلاعات بیشتری بدهید.';

    // ساخت متن نهایی
    final sb = StringBuffer();
    sb.write(acknowledgment);
    if (echo.isNotEmpty) {
      sb.write(' ');
      sb.write(echo);
    }
    sb.write('\n\n');
    if (rationaleText.isNotEmpty) {
      sb.write(rationaleText);
      sb.write('\n\n');
    }
    sb.write(questionText);

    // chips: options + دلیل بازگشت
    final chips = <String>[
      ...action.options,
      if (action.options.isEmpty) 'لغو',
    ];

    return ComposedReply(
      text: sb.toString().trim(),
      chips: chips,
      variantId: _variantIdFor('ack', state),
    );
  }

  // ── Acknowledged slot transition (Phase 3) ─────────────────────
  //
  // هدف: به جای «پرش رباتی» از یک اسلات به اسلات بعدی، نخست گفتهٔ
  // کاربر تأیید شود، سپس با یک اتصال نرم و انسانی سراغ پرسش بعدی برویم.
  // برخلاف [_composeAskForSlotBase] اینجا خبری از rationale حقوقی،
  // شمارهگذاری سؤال، تکرار پاراگراف و بلوک دوسطرنی نیست؛ خروجی یک
  // جملهٔ روان و تکخط است.

  /// قالبهای تأیید همراه با بازتاب گفتهٔ کاربر.
  static const List<String> _ackTemplates = <String>[
    'بسیار خب، «{echo}» را یادداشت کردم. {connector} {question}',
    'خب، پس «{echo}»؛ این را در نظر گرفتم. {connector} {question}',
    'ممنون که گفتید «{echo}». {connector} {question}',
    'درست است، «{echo}»؛ این نکته را در نظر گرفتم. {connector} {question}',
  ];

  /// وقتی ورودی قابل بازتاب نباشد (خالی یا لاتین) همچنان طبیعی پاسخ میدهیم.
  static const List<String> _ackNoEchoTemplates = <String>[
    'بسیار خب، ادامه دهیم. {connector} {question}',
    'خب، متوجه شدم. {connector} {question}',
    'درست است، سراغ قدم بعدی برویم. {connector} {question}',
    'ممنون، همراهتان هستم. {connector} {question}',
  ];

  static const List<String> _ackConnectors = <String>[
    'حالا بفرمایید',
    'حالا لطفاً بگویید',
    'ادامه دهیم؛ بفرمایید',
    'برای قدم بعدی بفرمایید',
  ];

  /// پرسش پیشفرض برای اسلاتهای پرتکرار، وقتی نه سؤال صریحی داده شده
  /// باشد و نه دامنهای برای مراجعه به [DomainSchemaRegistry].
  static const Map<String, String> _ackDefaultQuestions = <String, String>{
    Slots.role: 'نقش شما در این موضوع چیست؟',
    Slots.nature: 'ماهیت دقیق آن چه بوده است؟',
    Slots.certTime: 'چه مدت از آن گذشته است؟',
    Slots.amount: 'مبلغ آن چقدر است؟',
    Slots.dueDate: 'تاریخ آن چه زمانی بوده است؟',
    Slots.proof: 'چه مدرکی در دست دارید؟',
    Slots.time: 'زمان دقیق آن کی بوده است؟',
    Slots.stage: 'پرونده در چه مرحلهای است؟',
    Slots.harmType: 'دقیقاً چه اتفاقی افتاده است؟',
  };

  static const List<String> _ackFillers = <String>[
    'بله ', 'بلی ', 'آره ', 'اره ', 'خیر ', 'نه ', 'باشه ', 'اوکی ',
  ];

  // بلندترینها نخست، تا «شده است» پیش از «است» بریده نشود.
  static const List<String> _ackCopulas = <String>[
    ' شده است', ' هستم', ' هست', ' است', ' بود', ' شد',
  ];

  /// ساخت پاسخ «تأیید گفتهٔ کاربر ← گذار نرم ← پرسش اسلات بعدی».
  ///
  /// * [previousInput] همان چیزی است که کاربر همین حالا گفته (مثلاً
  ///   «چک تضمینی»).
  /// * [nextSlotKey] کلید اسلاتی است که باید بعداً پرسیده شود
  ///   (مثلاً `amount`). از آن هم برای پرسش پیشفرض و هم برای بذر
  ///   تنوع قالبها استفاده میشود.
  /// * [nextQuestion] در صورت وجود، پرسش آمادهٔ فراخواننده است
  ///   (مثلاً پیام شمارهدار قدیمی); در غیر این صورت از
  ///   [DomainSchemaRegistry] یا [_ackDefaultQuestions] گرفته میشود.
  /// * [state] اختیاری است و فقط برای بذر گفتگو/شمارهٔ دور جهت
  ///   جلوگیری از تکرار قالبها به کار میرود؛ [turnIndex] جایگزین آن
  ///   در مسیر قدیمی `LegalCounselor.step` است.
  ///
  /// خروجی قطعی (deterministic) است و هیچ وابستگی به مدل زبانی،
  /// شبکه یا Planner ندارد.
  ComposedReply composeAcknowledged(
    String previousInput,
    String nextSlotKey, {
    String? nextQuestion,
    List<String> options = const <String>[],
    String domain = '',
    DialogueState? state,
    int turnIndex = 0,
  }) {
    final schema = domain.isEmpty ? null : DomainSchemaRegistry.forDomain(domain);
    final slot = schema?.slotByName(nextSlotKey);
    final question = _ackQuestion(nextSlotKey, nextQuestion, slot?.prompt);
    final echo = _ackEcho(previousInput);

    // بذر پایدار در طول گفتگو + شمارهٔ دور: قالبها میچرخند تا پشت
    // سر هم تکرار نشوند، ولی برای ورودی یکسان همیشه یک نتیجه بدهند.
    final seed = '${state?.conversationId ?? domain}|$nextSlotKey';
    final turn = state?.turnIndex ?? turnIndex;
    final templateIndex = _ackIndex(seed, turn, _ackTemplates.length);
    final connectorIndex = _ackIndex(seed, turn + 1, _ackConnectors.length);

    final template = echo.isEmpty
        ? _ackNoEchoTemplates[templateIndex]
        : _ackTemplates[templateIndex];
    final connector = _ackConnectors[connectorIndex];

    final text = PersianText.collapse(template
        .replaceFirst('{echo}', echo)
        .replaceFirst('{connector}', connector)
        .replaceFirst('{question}', question));

    final resolvedOptions = <String>[
      ...options,
      if (options.isEmpty) ...(slot?.options ?? const <String>[]),
    ];

    return ComposedReply(
      text: text,
      chips: resolvedOptions.isEmpty ? const <String>['لغو'] : resolvedOptions,
      variantId: 'ackTransition:${_fnv1a32("$seed|$echo|$question")}',
    );
  }

  /// پرسش اسلات بعدی را تمیز میکند: حذف شمارهگذاری آغازین، «لطفاً»
  /// اضافی، پرانتز/دونقطهٔ انتهایی و خطوط جدید؛ سپس علامت سؤال.
  static String _ackQuestion(String slotKey, String? explicit, String? schemaPrompt) {
    final raw = (explicit != null && explicit.trim().isNotEmpty)
        ? explicit
        : (schemaPrompt != null && schemaPrompt.trim().isNotEmpty
            ? schemaPrompt
            : (_ackDefaultQuestions[slotKey] ?? 'دربارهٔ آن کمی بیشتر توضیح دهید.'));

    var q = PersianText.collapse(PersianText.normalize(raw));
    q = q.replaceFirst(RegExp(r'^\d+[.)]\s*'), '').trim();
    q = q.replaceFirst(RegExp(r'^لطفا\s+'), '').trim();
    q = q.replaceAll(RegExp(r'[؛:،,]+$'), '').trim();
    if (q.isEmpty) q = 'دربارهٔ آن کمی بیشتر توضیح دهید';
    if (!q.contains('؟') && !q.contains('?') && !RegExp(r'[.!]$').hasMatch(q)) {
      q = '$q؟';
    }
    // normalize ارقام فارسی را به ASCII تبدیل کرده؛ دوباره فارسیشان کنیم.
    return PersianText.toFaDigits(q);
  }

  /// بازتاب کوتاه و تمیز از گفتهٔ کاربر؛ لاتین و متن خالی حذف میشوند
  /// تا خروجی همچنان کاملاً فارسی و روان بماند.
  static String _ackEcho(String raw) {
    var echo = PersianText.phrase(raw);
    if (echo.isEmpty || _containsLatin(echo)) return '';

    for (final filler in _ackFillers) {
      if (echo.startsWith(filler)) {
        echo = echo.substring(filler.length).trim();
        break;
      }
    }
    for (final copula in _ackCopulas) {
      if (echo.endsWith(copula)) {
        echo = echo.substring(0, echo.length - copula.length).trim();
        break;
      }
    }
    if (echo.isEmpty) return '';
    return PersianText.toFaDigits(PersianText.truncate(echo, 45, ellipsis: '…'));
  }

  /// چرخش قطعی قالبها: دو دور پیاپی هرگز قالب یکسانی نمیگیرند.
  static int _ackIndex(String seed, int turn, int bankSize) =>
      (_fnv1a32(seed) + turn) % bankSize;

  // ── GiveAnswer ──────────────────────────────────────────────────

  ComposedReply _composeGiveAnswer(GiveAnswer action) {
    final sb = StringBuffer();
    for (final c in action.conclusions) {
      sb.write(c);
      sb.write('\n\n');
    }
    return ComposedReply(
      text: sb.toString().trim(),
      chips: const [],
    );
  }

  // ── ExplainConflict ─────────────────────────────────────────────

  ComposedReply _composeExplainConflict(
    ExplainConflict action,
    DialogueState state,
  ) {
    final sb = StringBuffer();
    sb.write('بین شواهد موجود تعارض هست و نمی‌توانم بدون انتخاب شما '
        'پاسخ قطعی بدهم.');
    sb.write('\n\n');
    if (action.rationale != null && action.rationale!.isNotEmpty) {
      sb.write(action.rationale);
      sb.write('\n\n');
    }
    if (action.alternatives.isNotEmpty) {
      sb.write('گزینه‌های موجود:\n');
      for (var i = 0; i < action.alternatives.length; i++) {
        sb.write('${i + 1}. ${action.alternatives[i]}\n');
      }
    }
    return ComposedReply(
      text: sb.toString().trim(),
      chips: action.alternatives,
    );
  }

  // ── DisambiguateDomain ──────────────────────────────────────────

  ComposedReply _composeDisambiguateDomain(
    DisambiguateDomain action,
    DialogueState state,
  ) {
    final sb = StringBuffer();
    sb.write('موضوع حقوقی شما دقیقاً مشخص نیست. ');
    sb.write('لطفاً یکی از حوزه‌های زیر را انتخاب کنید:');

    final chips = <String>[];
    for (final id in action.candidates) {
      final schema = DomainSchemaRegistry.forDomain(id);
      if (schema != null) {
        chips.add(schema.titleFa);
      }
    }
    if (chips.isEmpty) {
      chips.add('مشاورهٔ حقوقی');
    }

    return ComposedReply(
      text: sb.toString(),
      chips: chips,
    );
  }

  // ── helpers ────────────────────────────────────────────────────

  /// ساخت echo از آخرین گفتهٔ کاربر یا matchedSpans.
  String _buildEcho(DialogueState state) {
    // تکرار طوطی‌وار گفتهٔ کاربر («می‌فهمم که گفتید «…»») مصنوعی به نظر
    // می‌رسد؛ فقط وقتی پاسخ کوتاه و مشخصی داده شده، آن را تصدیق می‌کنیم.
    if (state.matchedSpans.isNotEmpty) {
      final first = state.matchedSpans.values.first.trim();
      if (first.isNotEmpty && first.length <= 30 && !_containsLatin(first)) {
        return 'نکتهٔ «$first» را در نظر گرفتم.';
      }
    }
    return '';
  }

  /// آیا متن شامل حروف لاتین است؟ (برای Persian-only guard)
  static bool _containsLatin(String s) {
    for (final rune in s.runes) {
      if ((rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A)) {
        return true;
      }
    }
    return false;
  }

  /// انتخاب acknowledgment از bank بر اساس hash.
  String _pickAcknowledgment(DialogueState state) {
    const bank = [
      'باشه، متوجه شدم.',
      'بسیار خوب، این نکته را یادداشت کردم.',
      'درست است، ادامه دهیم.',
    ];
    final v = _variantIndexFor('ack', state, bank.length);
    return bank[v];
  }

  /// محاسبهٔ index variant با hash(convId, family) و permutation + turnIndex.
  ///
  /// برای تضمین عدم تکرار در ۳ نوبت متوالی، از یک permutation با
  /// seed ثابت (بر اساس hash) استفاده می‌کنیم. سپس با استفاده از
  /// turnIndex (که در هر نوبت یک واحد افزایش می‌یابد)، یک index
  /// جدید برمی‌گردانیم. چون perm یک bijection است، سه turn متوالی
  /// به سه variant متفاوت نگاشت می‌شوند.
  int _variantIndexFor(
    String family,
    DialogueState state,
    int bankSize,
  ) {
    final input = '${state.conversationId}|$family';
    final h = _fnv1a32(input);
    final indices = List<int>.generate(bankSize, (i) => i);
    var seed = h;
    for (var i = bankSize - 1; i > 0; i--) {
      seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
      final j = seed % (i + 1);
      final tmp = indices[i];
      indices[i] = indices[j];
      indices[j] = tmp;
    }
    return indices[state.turnIndex % bankSize];
  }

  String? _variantIdFor(String family, DialogueState state) {
    final input = '${state.conversationId}|$family';
    final h = _fnv1a32(input);
    return '$family:$h';
  }

  /// FNV-1a 32-bit hash — deterministic و بدون وابستگی.
  static int _fnv1a32(String input) {
    var hash = 0x811c9dc5;
    final bytes = utf8.encode(input);
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
// ---------------------------------------------------------------------------
// نگارش پویای پاسخ (Dynamic Response Composer)
// ---------------------------------------------------------------------------

/// حال کاربر که از متن پیامش برداشت می‌شود.
enum UserMood { anxious, angry, neutral }

/// نگارندهٔ پاسخ با «راهبرد ساندویچ»:
///
/// - **بالا**: همدلی متناسب با حال کاربر ([UserMood])،
/// - **میانه**: جملهٔ ربط + متن مادهٔ قانونیِ بازیابی‌شده؛ اگر ماده‌ای نباشد،
///   دقیقاً «متأسفانه ماده قانونی دقیقی پیدا نکردم...» و پیشنهاد مشورت با
///   وکیل — هرگز متن قانونی ساختگی تولید نمی‌شود،
/// - **پایین**: قدم‌های عملی (فهرست) + پرسش بعدی.
///
/// تنوع جمله‌ها با شمارندهٔ داخلی چرخانده می‌شود (نه Random)، پس خروجی
/// برای دنبالهٔ یکسانی از فراخوانی‌ها همیشه یکسان است.
class DynamicResponseComposer {
  DynamicResponseComposer({int start = 0}) : _counter = start;

  int _counter;

  /// تعداد پاسخ‌های ساخته‌شده تا اینجا.
  int get counter => _counter;

  void reset([int to = 0]) => _counter = to;

  /// متن ثابت وقتی ماده‌ای پیدا نشده است.
  static const String noArticleText = 'متأسفانه ماده قانونی دقیقی پیدا نکردم...';

  static const String noArticleAdvice =
      'برای اینکه بر اساس حدس راهنمایی‌تان نکنم، پیشنهاد می‌کنم موضوع را با '
      'یک وکیل دادگستری در میان بگذارید. اگر هزینهٔ وکیل برایتان سنگین است، '
      'می‌توانید از معاضدت کانون وکلا کمک بگیرید.';

  static const List<String> _anxiousWords = [
    'نگران', 'نگرانم', 'می‌ترسم', 'میترسم', 'ترسیده‌ام', 'ترس', 'استرس',
    'اضطراب', 'دلشوره', 'چه کار کنم', 'چکار کنم', 'چیکار کنم', 'چه کنم',
    'بدبخت شدم', 'بیچاره', 'ناامید', 'حالم بد', 'گریه', 'کمکم کنید',
    'کمک کنید', 'تو رو خدا', 'توروخدا', 'خواهش می‌کنم', 'آبرویم', 'آبروم',
    'زندان', 'نمی‌دانم چه کنم', 'نمیدونم چیکار', 'خوابم نمی‌برد',
  ];

  static const List<String> _angryWords = [
    'عصبانی', 'عصبانیم', 'کلافه', 'خسته شدم', 'بسه', 'ظلم', 'بی‌انصاف',
    'بی انصاف', 'نامرد', 'دروغگو', 'حقم را خورد', 'حقمو خورد', 'حقم رو خورد',
    'پدرش را درمی‌آورم', 'پدرشو درمیارم', 'حالشو می‌گیرم', 'ولش نمی‌کنم',
    'ول نمی‌کنم', 'انتقام', 'تقاص', 'اعصابم', 'شاکی‌ام', 'غیرقابل تحمل',
    'مسخره', 'سرم کلاه گذاشت',
  ];

  static final List<List<String>> _anxiousToks = [
    for (final w in _anxiousWords) PersianNormalizer.tokens(w),
  ];
  static final List<List<String>> _angryToks = [
    for (final w in _angryWords) PersianNormalizer.tokens(w),
  ];

  /// برداشت قطعی حال کاربر از واژه‌ها و نشانه‌گذاری.
  ///
  /// - هر واژهٔ نگرانی/خشم ۱ امتیاز،
  /// - هر «!» نیم امتیاز خشم (بیشینه ۲)، «؟؟» یا «??» نیم امتیاز نگرانی،
  ///   «...» یک‌چهارم امتیاز نگرانی،
  /// - ایموجی‌های 😡🤬😠 خشم و 😢😭😟😰😥 نگرانی.
  /// با امتیاز کمتر از ۱ حال «خنثی» است؛ در تساوی، نگرانی (همدلی بیشتر)
  /// انتخاب می‌شود.
  static UserMood detectMood(String text) {
    if (text.trim().isEmpty) return UserMood.neutral;
    final toks = PersianNormalizer.tokens(text);
    var anxious = 0.0;
    var angry = 0.0;
    for (final w in _anxiousToks) {
      if (PersianNormalizer.containsPhraseTokens(toks, w)) anxious += 1;
    }
    for (final w in _angryToks) {
      if (PersianNormalizer.containsPhraseTokens(toks, w)) angry += 1;
    }
    final bangs = RegExp('[!！]').allMatches(text).length;
    angry += (bangs * 0.5).clamp(0, 2);
    if (RegExp(r'[؟?]{2,}').hasMatch(text)) anxious += 0.5;
    if (text.contains('...') || text.contains('…')) anxious += 0.25;
    for (final e in const ['😡', '🤬', '😠']) {
      if (text.contains(e)) angry += 1;
    }
    for (final e in const ['😢', '😭', '😟', '😰', '😥', '😔']) {
      if (text.contains(e)) anxious += 1;
    }
    if (anxious < 1 && angry < 1) return UserMood.neutral;
    return angry > anxious ? UserMood.angry : UserMood.anxious;
  }

  static String _empathy(UserMood mood, int v) => switch (mood) {
        UserMood.anxious => switch (v % 3) {
            0 => 'می‌فهمم که این وضعیت چقدر نگران‌کننده است. آرام باشید؛ قدم‌به‌قدم با هم پیش می‌رویم.',
            1 => 'نگرانی شما کاملاً قابل درک است. خبر خوب این است که قانون برای این وضعیت راه مشخصی دارد.',
            _ => 'حق دارید نگران باشید، اما تنها نیستید. بیایید با هم ببینیم دقیقاً چه کاری از دستتان برمی‌آید.',
          },
        UserMood.angry => switch (v % 3) {
            0 => 'کاملاً حق دارید ناراحت و عصبانی باشید؛ این رفتار منصفانه نبوده است.',
            1 => 'می‌فهمم چقدر کلافه شده‌اید. بهترین جواب به این بی‌انصافی، پیگیری قانونی و حساب‌شده است.',
            _ => 'ناراحتی شما کاملاً بجاست. بیایید این خشم را به یک اقدام قانونی مؤثر تبدیل کنیم.',
          },
        UserMood.neutral => switch (v % 3) {
            0 => 'ممنون که موضوع را با من در میان گذاشتید.',
            1 => 'پرسش خوبی است؛ اجازه بدهید دقیق جواب بدهم.',
            _ => 'خوشحالم که قبل از هر اقدامی پرسیدید.',
          },
      };

  /// فقط جملهٔ همدلی متناسب با حال کاربر (برای قاب‌بندی پاسخ‌های دیگر،
  /// مثل پاسخ موتور جست‌وجو). برای حال «خنثی» رشتهٔ خالی برمی‌گرداند و
  /// شمارنده را جلو نمی‌برد؛ در غیر این صورت شمارنده یک واحد جلو می‌رود تا
  /// پیام‌های پیاپی تکراری نباشند.
  String empathyFor(UserMood mood) {
    if (mood == UserMood.neutral) return '';
    return _empathy(mood, _counter++);
  }

  static String _transition(int v) => switch (v % 3) {
        0 => 'طبق متن قانون:',
        1 => 'مبنای قانونی موضوع شما این است:',
        _ => 'قانون در این باره چنین می‌گوید:',
      };

  static final RegExp _bulletPrefix = RegExp(r'^\s*(?:[•\-*–]|\d+[.)]|[۰-۹]+[.)])\s*');

  /// پاسخ کامل ساندویچی.
  ///
  /// - [userText]: پیام کاربر (برای برداشت حال، اگر [mood] داده نشود)،
  /// - [lawArticle]: متن مادهٔ بازیابی‌شده؛ null یا خالی یعنی ماده‌ای نیست،
  /// - [lawSource]: عنوان منبع (مثلاً «قانون صدور چک، ماده ۷»)، اختیاری،
  /// - [actionPlan]: قدم‌های عملی،
  /// - [nextQuestion]: پرسش بعدی (مثلاً از `DialogueStateManager`).
  String compose({
    required String userText,
    String? lawArticle,
    String? lawSource,
    List<String> actionPlan = const [],
    String? nextQuestion,
    UserMood? mood,
  }) {
    final v = _counter++;
    final m = mood ?? detectMood(userText);
    final b = StringBuffer()..writeln(_empathy(m, v));

    // میانه
    b.writeln();
    final article = lawArticle?.trim() ?? '';
    if (article.isEmpty) {
      b
        ..writeln('📜 $noArticleText')
        ..writeln(noArticleAdvice);
    } else {
      b.writeln('📜 ${_transition(v)}');
      final src = lawSource?.trim() ?? '';
      if (src.isNotEmpty) b.writeln('«$src»');
      b.writeln(article);
    }

    // پایین
    final steps = [
      for (final s in actionPlan)
        if (s.replaceFirst(_bulletPrefix, '').trim().isNotEmpty)
          s.replaceFirst(_bulletPrefix, '').trim(),
    ];
    if (steps.isNotEmpty) {
      b
        ..writeln()
        ..writeln('✅ قدم‌های پیشنهادی:');
      for (final s in steps) {
        b.writeln('• $s');
      }
    }
    final q = nextQuestion?.trim() ?? '';
    if (q.isNotEmpty) {
      b
        ..writeln()
        ..writeln('❓ $q');
    }
    return b.toString().trimRight();
  }
}

part of 'advocate.dart';

// مسیرِ گفت‌وگویی که به پرونده مربوط نیست: سلام، تشکر، توهینِ کوتاه، سوگ،
// خلاصه‌خواستن، دستهٔ مشکل و «خارج شدم و برگشتم».
//
// این چهار متد ۲۷۵ خط بودند روی `Advocate` (که خودش ۲۲۹ خطِ `_meta` را در
// دلِ یک متد داشت). حالا `TalkRoute` آن‌ها را دارد و فقط همکارهای خودش را
// می‌شناسد؛ تصمیمِ «این پیام مالِ کدام مسیر است» همچنان کارِ وکیل است.

/// گفت‌وگوی عمومی، بی‌نیاز از خودِ وکیل.
class TalkRoute {
  TalkRoute({
    required this.file,
    required this.dialog,
    required this.voice,
    required this.engine,
    required this.talk,
    required this.picker,
    required this.chipPlan,
    required this.closeCase,
  });

  final CaseFile file;
  final DialogueState dialog;
  final ReplyVoice voice;
  final KnowledgeEngine engine;

  /// گفت‌وگوی انسانی (احوال‌پرسی، خلاصه، سوگ، «منظورتان چیست؟»).
  final TalkReply talk;

  /// موضوعِ باز، برای دکمه‌های بی‌پرونده.
  final TopicPicker picker;

  final ChipPlan Function() chipPlan;

  /// بستنِ پرونده، وقتی کاربر موضوع تازه‌ای را انتخاب می‌کند.
  final void Function() closeCase;

  /// آیا پرونده‌ای باز است؟ (همان تعریفِ وکیل، از دو همکارِ خودش.)
  bool get hasCase => file.topic.isNotEmpty || dialog.guide != null;

  /// توهین‌های کوتاهی که پاسخِ آرام می‌خواهند. پیش‌تر عضوِ خصوصیِ extension
  /// بود و از این کلاس دیده نمی‌شد.
  static const String _rudePattern = 'فهم نداری|بی ?[ ‌]?ارزش|بی فهم';

  AdvocateReply _out(
    String text, {
    List<String> chips = const [],
    String ask = '',
    bool full = false,
    int budget = _budget,
    AnswerSource source = AnswerSource.topic,
  }) =>
      voice.out(text,
          chips: chips, ask: ask, full: full, budget: budget, source: source);

  String _pick(List<String> options) => voice.pick(options);

  List<String> get _idleChips => chipPlan().idle(picker.current());

  List<String> _suggest(Topic t) => chipPlan().suggest(t);

  AdvocateReply _summary(Topic? topic) => talk.summary(topic);

  /// [explicit]: پیام به موضوعی روشن اشاره دارد و پرونده‌ای باز نیست. در این
  /// حالت پاسخ‌های کلیِ مقدم (راهنمای وکیل، مهلت، توانایی‌ها، متن قانون) کنار
  /// می‌روند تا موضوع صریح اول دیده شود. توهین و هویت همچنان اول می‌آیند.
  AdvocateReply? meta(String n, Topic? topic, {bool explicit = false}) {
    final w = Sense.words(n);
    // توهین کوتاه («فهم نداری»، «بی ارزش»): پاسخ آرام؛ نه پرسش سنگین و نه
    // نقشهٔ راه، و موضوع باز هم حفظ می‌شود.
    // «نفهمی» و «نفهمیدم» فرق دارند: فقط کلمهٔ مستقل «نفهمی» همین پاسخ را می‌گیرد.
    if (w <= 4 && Sense.has(n, r'(?<![^ ])نفهمی(?![^ ])')) {
      return _out(
        advocateText('trUnclearWordBody'),
        ask: topic == null ? advocateText('trUnclearWordAsk') : dialog.askText,
        chips: topic == null ? _idleChips : dialog.askChips,
      );
    }
    if (w <= 5 && Sense.has(n, 'خیلی خل|خیلی خر|خیلی احمق|خنگ')) {
      return _out(
        advocateText('trInsult1Body'),
        ask: topic == null ? advocateText('trInsultAsk') : dialog.askText,
        chips: topic == null ? _idleChips : dialog.askChips,
      );
    }
    if (w <= 5 && Sense.has(n, _rudePattern)) {
      return _out(
        advocateText('trInsult2Body'),
        ask: topic == null ? advocateText('trInsultAsk') : dialog.askText,
        chips: topic == null ? _idleChips : dialog.askChips,
      );
    }
    // حق دسترسی به اطلاعات عمومی: قانون انتشار و دسترسی آزاد به اطلاعات
    // (۱۳۸۷)، ماده ۲. قانون اساسی را به این صراحت نشانی نمی‌دهم.
    if (w <= 25 &&
        Sense.has(n,
            'دسترسی (?:آزاد )?به (?:اطلاعات|اسناد|سند)|اطلاعات[^؟]{0,40}محرمانه|محرمانه[^؟]{0,40}اطلاعات|اطلاعات[^؟]{0,20}(?:خودداری|ندهد|نمی[ ]?ده|نداد)|خودداری[^؟]{0,30}اطلاعات')) {
      return _out(
        advocateText('trInfoAccessBody'),
        ask: advocateText('trInfoAccessAsk'),
        chips: [
          advocateText('trInfoAccessChipYes'),
          advocateText('trInfoAccessChipNo'),
        ],
        full: true,
      );
    }
    // «زن داری»: واژه‌ای کوتاه با چند معنی؛ پیش از حدس می‌پرسم.
    if (w <= 3 && Sense.has(n, r'(?<![^ ])زن داری(?![^ ])|(?<![^ ])زن دارم(?![^ ])')) {
      return _out(
        advocateText('trMarryBody'),
        ask: topic == null ? advocateText('trMarryAsk') : dialog.askText,
        chips: topic == null ? branchStart() : dialog.askChips,
      );
    }
    // «شکایت کرده‌ام»: خودِ کاربر شاکی است، نه طرف شکایت.
    if (topic == null &&
        w <= 6 &&
        Sense.has(n, r'شکایت (?:کرده ?(?:ام|م)|کردم|دادم|ثبت کرده ?(?:ام|م)|ثبت کردم)')) {
      return _out(
        advocateText('trComplainantBody'),
        ask: advocateText('trComplainantAsk'),
        chips: [
          advocateText('trComplainantChipCrim'),
          advocateText('trComplainantChipCivil'),
        ],
        full: true,
      );
    }
    if (w <= 8 &&
        Sense.has(n,
            'تو وکیلی|شما وکیل|وکیل هستی|وکیلی ؟|کی هستی|چی هستی|رباتی|ربات هستی|هوش مصنوعی|آدم واقعی|ادم واقعی|آدمی یا|اسمت چیه')) {
      return _out(
        advocateText('trIdentityBody'),
        ask: topic == null ? advocateText('trIdentityAsk') : dialog.askText,
        chips: topic == null ? branchStart() : dialog.askChips,
        full: true,
      );
    }
    // «چه کارهایی می‌توانی بکنی؟»: توانایی‌های برنامه. عمداً فاعل «تو/شما»
    // را می‌خواهد تا «چه کاری می‌توانم بکنم» (پرسش از وضع خودِ کاربر) با
    // آن یکی نشود.
    if (!explicit && w <= 9 &&
        Sense.has(n,
            'خودت(?: را| رو)? معرفی|معرفی (?:خودت|خودتان)|چکار(?:هایی|ایی)|توانای(?:ه?ایت|ی‌?ها(?:یت|یتان)?|ت)|چه کار(?:هایی|ایی|ی)? (?:میتونی|میتوانی|بلدی|میتونید|میتوانید)|کارهایی که (?:میتونی|میتوانی)|چی بلدی|چه کاری از دستت|چی از دستت برمیاد|چه کمکی (?:ازت|از دست شما|ازتون)')) {
      final v = engine.replies.variants('capabilities');
      return _out(
        _pick(v),
        ask: topic == null ? advocateText('trIdentityAsk') : dialog.askText,
        chips: topic == null ? branchStart() : dialog.askChips,
        full: true,
      );
    }
    // وکیل و هزینه: راهنمای عملی، نه تحلیل پرونده. حتی وسط یک پرونده هم
    // جواب می‌گیرد، چون پرسش دربارهٔ وکیل همیشه معنا دارد.
    if (!explicit && w <= 10 &&
        Sense.has(n,
            'وکیل (?:کجا|کدوم|کجاست|چطور|چگونه|بگیرم|بگیریم|لازمه|لازم|پیدا|خوبی)|پیدا کردن وکیل|(?:هزینه|حق ?الوکاله|حق ?وکالت|دستمزد) (?:وکیل|وکالت)|(?:مشاوره|وکالت|کمک حقوقی) (?:رایگان|مجانی|ارزون|ارزان)')) {
      return _out(
        advocateText('trLawyerBody'),
        ask: topic == null ? advocateText('trLawyerAsk') : dialog.askText,
        chips: topic == null ? branchStart() : dialog.askChips,
        full: true,
      );
    }
    // مهلت‌ها: جواب کلی، وقتی پرونده‌ای باز نیست. وسط پرونده، قواعد همان
    // موضوع دقیق‌تر جواب می‌دهند.
    if (!explicit && topic == null &&
        w <= 10 &&
        Sense.has(n,
            'مهلت (?:شکایت|اعتراض|تجدیدنظر|فرجام|دادخواست|قانونی|دارم|داره|داریم|چقدره|چنده|چند روزه)|تا کی (?:باید|میتونم|میتوانم|مهلت)|مرور زمان|کی باید (?:شکایت|اقدام)')) {
      return _out(
        advocateText('trDeadlineBody'),
        ask: advocateText('trDeadlineAsk'),
        chips: branchStart(),
        full: true,
      );
    }
    if (!explicit && w <= 10 &&
        Sense.has(n,
            'میشه (?:[^ ]+ ){0,3}اعتماد|اعتماد کنم|قابل اعتماد|مطمئنی|از کجا میدونی|از کجا معلوم|درست میگی|حرف(?:ات|هات) درست|منبع(?:ت)? چیه|دروغ نمیگی')) {
      return _out(
        advocateText('trTrustBody'),
        ask: dialog.askText,
        chips: dialog.askText.isEmpty ? _idleChips : dialog.askChips,
        full: true,
      );
    }
    if (!explicit && w <= 7 &&
        !Sense.has(n, '(?:ماده|اصل) [0-9]+') &&
        voice.lastLaws.isNotEmpty &&
        Sense.has(n,
            'متن (?:قانون|ماده)|کدوم ماده|کدام ماده|طبق کدوم|طبق کدام|ماده ?(?:اش|ش) (?:چی|رو|را)|مستند(?:ت|ش)? چی|سندت چیه')) {
      // «متن قانون را ببینم» یعنی خودِ متن، نه چکیده؛ و همهٔ موادی که پاسخ
      // پیشین به آن‌ها استناد کرده بود. پیش‌تر فقط دو ماده و آن هم بریده
      // می‌آمد و عنوانشان با ارقام لاتین («ماده 10»).
      final shown = voice.lastLaws.take(3).toList();
      final lines = [
        for (final l in shown)
          '• ${PersianText.toFaDigits(l.title)}'
              '${l.source.trim().isEmpty ? '' : '${advocateText('trLawsSourceSep')}${l.source.trim()}'}:\n'
              '«${_lawBody(l.body)}»',
      ];
      final rest = voice.lastLaws.length - shown.length;
      if (rest > 0) {
        lines.add(advocateFormat('trLawsMore', {'rest': PersianText.toFaDigits('$rest')}));
      }
      return _out(
        advocateFormat('trLawsLead', {'lines': lines.join('\n')}),
        ask: dialog.askText,
        chips: dialog.askChips,
        full: true,
      );
    }
    if (w <= 8 &&
        Sense.has(n,
            'چی فهمیدی|چه فهمیدی|متوجه (?:شدی|حرفم)|فهمیدی چی|حرف(?:م|مو|م رو) فهمیدی|گرفتی چی|میفهمی چی')) {
      final got = topic == null ? const <String>[] : recapOf(topic, file);
      if (topic == null || got.isEmpty) {
        return _out(
          topic == null
              ? advocateText('trUnderstoodEmpty')
              : advocateFormat('trUnderstoodNoDetail', {'title': topic.title}),
          ask: topic == null || dialog.askText.isEmpty
              ? advocateText('trUnderstoodAsk')
              : dialog.askText,
          chips: topic == null ? _idleChips : dialog.askChips,
        );
      }
      return _out(
        '${_pick(Say.understood)} ${_join(got)}.',
        ask: advocateText('trUnderstoodConfirmAsk'),
        chips: _suggest(topic),
      );
    }
    if (w <= 8 &&
        Sense.has(n,
            'چرا (?:[^ ]+ ){0,2}(?:می)?پرس|چه ربطی|به چه درد|برای چی میپرس')) {
      Slot? p;
      if (topic != null) {
        for (final s in topic.slots) {
          if (s.id == file.pending) p = s;
        }
      }
      if (p != null && p.why.isNotEmpty) {
        return _out(
          advocateFormat('trWhyRightPrefix', {'why': p.why}),
          ask: advocateFormat('trWhyAskPrefix', {'ask': p.ask}),
          chips: [...p.options, _dontKnowChip],
          full: true,
        );
      }
      final why = file.pending == 'q:reply'
          ? advocateText('trWhyReply')
          : file.pending == 'q:goal'
              ? advocateText('trWhyGoal')
              : advocateText('trWhyDefault');
      return _out(
        why,
        ask: dialog.askText,
        chips: dialog.askText.isEmpty ? _idleChips : dialog.askChips,
        full: true,
      );
    }
    if (w <= 6 && Sense.has(n, 'خلاصه|جمع ?بندی|در یک جمله|تهش چی|آخرش چی')) {
      return _summary(topic);
    }
    if (w <= 6 &&
        Sense.has(n,
            'ساده ?تر|ساده بگو|نفهمیدم|متوجه نشدم|گیج شدم|پیچیده|دوباره بگو|یه بار دیگه|نگرفتم')) {
      if (voice.lastBody.isEmpty) {
        return _out(advocateText('trSimpleEmptyBody'),
            ask: advocateText('trSimpleEmptyAsk'), chips: _idleChips);
      }
      final lines = <String>[
        for (final l in _strip(voice.lastBody).split('\n'))
          if (l.trim().isNotEmpty) _brief(l.trim()),
      ];
      return _out(
        advocateFormat('trSimpleLead', {'lines': lines.take(4).join('\n')}),
        ask: advocateText('trSimpleAsk'),
        chips: topic == null ? _idleChips : _suggest(topic),
      );
    }
    // بی‌موضوع: همدلی با ناامیدی پس از نظر دوم می‌آید (`_hopeless`)، تا
    // جمله‌ای مثل «کارتم هک شد و پولم رفت» موضوعش را از دست ندهد.
    if (topic != null && w <= 10 && Sense.has(n, _hopelessPattern)) {
      final c = topic.follow['chance'];
      final n2 = topic.follow['next'];
      final sb = StringBuffer(advocateText('trHopelessLead'));
      if (c != null) sb.write('\n${c(file)}');
      if (n2 != null && !file.covered.contains('f:next')) {
        sb.write('\n\n${n2(file)}');
        file.covered.add('f:next');
      }
      voice.lastBody = sb.toString();
      return _out(voice.lastBody, chips: _suggest(topic));
    }
    return null;
  }

  /// دکمه‌های «از کجا شروع کنیم» بیرون از پرونده: شاخهٔ کار (حقوقی/کیفری/
  /// اداری/نمی‌دانم/انصراف)، نه چهار ماجرای آمادهٔ دیگران که کاربر را از حرف
  /// خودش دور می‌کند.
  List<String> branchStart() {
    dialog.branchAsked = true;
    return ChipTexts.branchChips;
  }

  /// پاسخ به دکمه‌های دستهٔ مشکل («حقوقی»، «کیفری»، «اداری»، «نمی‌دانم»،
  /// «انصراف») که همراهِ سلام نشان داده می‌شوند.
  ///
  /// فقط در همان نوبتِ بعد از سلام (یا در آغازِ گفتگو، پیش از آن‌که ماجرایی
  /// گفته شود) معنا دارد؛ وگرنه «نمی‌دانم» جوابِ پرسش‌های خودِ پرونده است، نه
  /// انتخابِ دسته.
  AdvocateReply? branchReply(String raw, String n, {required bool asked}) {
    final label = raw.trim();
    if (!ChipTexts.branchChips.contains(label)) {
      // «خروج از برنامه» یا «انصراف» را ممکن است کاربر تایپ کند، نه بزند.
      if (!asked ||
          Sense.words(n) > 4 ||
          !Sense.has(n, 'انصراف|خروج|بی‌خیال|بستن|دیگه کاری ندارم')) {
        return null;
      }
      closeCase();
      dialog.loose.clear();
      return _out(advocateText('trBranchLeave'));
    }
    if (!asked && (hasCase || dialog.loose.isNotEmpty)) return null;
    closeCase();
    dialog.loose.clear();
    if (label == ChipTexts.leaveChip) {
      return _out(advocateText('trBranchLeave'));
    }
    if (label == ChipTexts.unsureChip) {
      return _out(
        advocateText('trBranchUnsureBody'),
        ask: advocateText('trBranchUnsureAsk'),
      );
    }
    final tail = label == ChipTexts.criminalChip
        ? advocateText('trBranchTailCrim')
        : label == ChipTexts.adminChip
            ? advocateText('trBranchTailAdmin')
            : advocateText('trBranchTailCivil');
    return _out(
      advocateFormat('trBranchPickedBody', {'label': label}),
      ask: advocateFormat('trBranchPickedAsk', {'tail': tail}),
    );
  }

  /// «مشکل حقوقی دارم» و مانندش: کلمه‌های خودِ کاربر را نقل می‌کنم و
  /// می‌پرسم ماجرا چیست.
  AdvocateReply intake(String raw) => _out(
        advocateFormat('trIntakeBody', {'words': _quoteWords(raw)}),
        ask: advocateText('trIntakeAsk'),
        // دکمهٔ اضافه نمی‌گذاریم: کاربر همین حالا دارد ماجرا را می‌گوید.
      );
}

part of 'advocate.dart';

// API عمومیِ وکیل: پرسیدن (`respond`)، شروعِ تازه، بازیابیِ گفتگو، سندهای
// پیشنهادی، متن‌های قالب و دکمه‌های آماده.
//
// این‌ها متدهای خودِ `Advocate` بودند و ۴۰۳ خط را با سیم‌کشی بیست همکار و
// اعضای `static` شریک می‌شدند. تنها چیزی که این‌جا **نمی‌آید** `static` است
// (`topics`، `wantsDraft`، `topicOf`، `_correctionPattern`، `_afterCorrection`):
// در Dart، `extension` عضوِ `static` نمی‌پذیرد. پس آن پنج در `advocate.dart`
// ماندند و این مرز عمدی است، نه فراموشی.
//
// نامِ extension **عمومی** است، نه `_AdvocateApi`: نامِ خصوصی، همهٔ اعضا را هم
// از بیرونِ کتابخانه پنهان می‌کند (همین اشتباه یک بار CI را قرمز کرد:
// `advocate.respond` برای `chat_controller` ناشناخته شد). اعضای خصوصی
// (`_out`، `_withLeave`) باز هم خصوصی می‌مانند، چون خودِ عضو `_` دارد.

extension AdvocateApi on Advocate {
  /// آیا از پاسخ قبلی چیزی نگفته مانده است؟
  bool get hasMore => voice.rest.isNotEmpty;

  /// قالبی که در پاسخ قبلی پیشنهاد نوشتنش را داده‌ام (یا `null`).
  String? get offeredDraft =>
      dialog.offer == 'draft' && dialog.offerDraft.isNotEmpty
          ? dialog.offerDraft
          : null;

  /// پیشنهادِ معلق را کنار می‌گذارد (وقتی لایهٔ بالاتر خودش به آن رسید).
  void clearOffer() => dialog.clearOffer();
  bool get hasCase => file.topic.isNotEmpty || dialog.guide != null;

  /// شناسهٔ قالب‌های سندی که به پروندهٔ جاری می‌خورد (به ترتیب اولویت).
  List<String> get draftIds {
    final t = _current();
    if (t != null) {
      final d = t.drafts;
      final out = <String>[...?(d == null ? null : d(file))];
      for (final g in filings) {
        if (!out.contains(g.template)) out.add(g.template);
      }
      return out;
    }
    return dialog.guide?.templateIds ?? const [];
  }

  /// سندهایی که به وضعیتِ همین پرونده می‌خورد: اول دادخواست، بعد لایحه.
  /// فقط قالب‌هایی که واقعاً در برنامه هستند.
  List<Filing> get filings {
    final t = _current();
    if (t == null) return const [];
    final out = <Filing>[];
    for (final make in [t.petition, t.brief]) {
      final g = make == null ? null : make(file);
      if (g != null && _draftTitles.containsKey(g.template)) out.add(g);
    }
    return out;
  }

  /// اگر این متن دکمهٔ یکی از سندهای پیشنهادیِ همین پرونده باشد، همان را
  /// می‌دهد.
  Filing? filingFor(String raw) {
    final key = Sense.norm(raw);
    for (final g in filings) {
      if (Sense.norm(g.chip) == key) return g;
    }
    return null;
  }

  /// آیا پیام می‌گوید «همین حالا» کسی در خطر است؟
  ///
  /// این حالت به پرونده و به اینکه پیش‌تر هشدار داده‌ام یا نه گره نمی‌خورد؛
  /// هر بار که کاربر این را بگوید، پاسخ فوری می‌گیرد.


  /// متن‌های پیشنهادی برای فیلدهای یک قالب، از روی واقعیت‌های همین پرونده
  /// (شناسهٔ فیلد → متن).
  Map<String, String> fillFor(String templateId) {
    final fill = _current()?.fill;
    return fill == null ? const {} : fill(file, templateId);
  }

  void reset() {
    _closeCase();
    dialog.reset();
    _prevN = '';
    dialog.also = null;
    voice.relevantChip = '';
    voice.reset();
    file.turns = 0;
    file.disclaimed = false;
    unresolved.clear();
  }

  /// بازسازی حافظه از پیام‌های قبلی کاربر (هنگام بازکردن گفتگوی ذخیره‌شده).
  ///
  /// این راه، پرهزینه و شکننده است: هر پیام دوباره از کل خط لوله می‌گذرد،
  /// پس اگر قاعده‌ای تغییر کرده باشد پروندهٔ بازیابی‌شده با پروندهٔ اصلی یکی
  /// نیست. فقط برای گفتگوهای قدیمی که پروندهٔ ذخیره‌شده ندارند به کار
  /// می‌رود؛ گفتگوهای تازه با [restoreCase] باز می‌شوند.
  void replay(Iterable<String> userTexts) {
    reset();
    for (final t in userTexts) {
      respond(t);
    }
  }

  /// بازیابی پرونده از نسخهٔ ذخیره‌شده (JSON تاریخچه) بدون پخش دوبارهٔ پیام‌ها.
  /// ورودی نامعتبر پروندهٔ خالی می‌دهد.
  void restoreCase(Map<String, dynamic> json) {
    reset();
    file.copyFrom(CaseFile.fromJson(json));
  }

  /// [guess] حدسِ خوانندهٔ موضوع برای همین پیام است (اگر محاسبه شده باشد)؛
  /// فقط وقتی به‌کار می‌آید که قاعده‌ها موضوع را نشناخته باشند.
  AdvocateReply respond(String raw, {TopicGuess? guess}) =>
      _withLeave(_reply(raw, guess: guess));

  /// «انصراف» آخرین دکمهٔ **هر** پاسخ است، در هر مرحله‌ای از گفتگو؛ وگرنه
  /// کاربر از وسط ماجرا راه خروج ندارد (بعضی مسیرها مثل جست‌وجوی متن قانون،
  /// پاسخ را مستقیم می‌سازند و از [_out] نمی‌گذرند).
  AdvocateReply _withLeave(AdvocateReply r) {
    if (r.chips.isNotEmpty && r.chips.last == ChipTexts.leaveChip) return r;
    return AdvocateReply(
      r.text,
      chips: [...r.chips.where((c) => c != ChipTexts.leaveChip), ChipTexts.leaveChip],
      laws: r.laws,
      source: r.source,
    );
  }

  /// آیا برای این پیام حدسِ خوانندهٔ موضوع به کار می‌آید؟ محاسبهٔ حدس روی
  /// گوشی زمان می‌برد؛ فقط وقتی خواسته می‌شود که پرونده‌ای باز نیست و
  /// قاعده‌ها خودشان موضوع را نشناخته‌اند.
  bool wantsGuess(String raw) {
    if (file.topic.isNotEmpty || dialog.guide != null || dialog.choices.isNotEmpty) {
      return false;
    }
    if (raw.trim() == ChipTexts.newCaseChip) return false;
    final n = Sense.norm(raw);
    if (!_guessable(n)) return false;
    for (final t in Advocate.topics) {
      if (_score(t, n) >= 3) return false;
    }
    return true;
  }

    /// خروجیِ هر پاسخ: استنادها را به نام ماده برمی‌گرداند، متن را کوتاه
  /// نگه می‌دارد (باقی‌مانده با «ادامه بده» می‌آید) و پرسشِ [ask] را در
  /// پایان می‌گذارد تا گفتگو دوطرفه بماند.
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
  /// دکمه‌های پیشنهادی برای وضعیتِ فعلیِ گفتگو (تصمیم است، نه داده؛ برچسب‌ها
  /// در `chip_texts.dart`).
  List<String> get idleChips => _idleChips();
}

part of 'advocate.dart';

// خطِ تولیدِ پاسخ: **ترتیب** کاندیدها. همین یک تابع تصمیم‌ها را به ترتیب
// می‌چیند و داور اولین پاسخ‌دهنده را برمی‌گرداند؛ هیچ قاعده‌ای این‌جا تنه ندارد.
//
// این فایل پیش‌تر ۴۱۰ خط بود: ترتیب، نگهبان‌ها و دو شاخهٔ «پرونده باز است /
// باز نیست» روی هم. حالا ترتیب این‌جاست، نگهبان‌ها در `advocate_reply_guard`
// و شاخه‌ها در `advocate_reply_case`. ترتیب واژه‌به‌واژه همان پیشین است و
// `tests/python/test_reply_pipeline_shape.py` نوزده نام را به همان ترتیب
// قفل کرده است.

extension _ReplyPipeline on Advocate {
  /// [again] یعنی «این پیام را من خودم ساختم»: وکیل برای «بگویم؟» جواب
  /// کاربر را به پرسشِ تازه ترجمه می‌کند («بگو» ← «استدلالت چیه؟»). آن پیام
  /// نوبتِ کاربر نیست، پس شمارهٔ نوبت را جلو نمی‌برد. پیش‌تر این کار با
  /// `file.turns--` بعد از فراخوانیِ بازگشتی انجام می‌شد؛ حالا صریح است.
  AdvocateReply _reply(String raw, {TopicGuess? guess, bool again = false}) {
    final n = Sense.norm(raw);
    final prevN = _prevN;
    _prevN = n;
    voice.relevantChip = Understanding.relevantChip(raw) ?? '';
    if (!again) file.turns++;
    final choices = dialog.choices;
    final choiceText = dialog.choiceText;
    final guessed = dialog.guessed;
    final branchAsked = dialog.branchAsked;
    dialog.choices = const [];
    dialog.choiceText = '';
    dialog.guessed = false;
    dialog.branchAsked = false;
    final short = Sense.words(n) <= 4;
    // از این‌جا تا «موضوعِ کنارِ هم»، ترتیب خودِ تصمیم است: هر ورودی نام دارد
    // و داور اولین پاسخ‌دهنده را برمی‌گرداند. جای زنجیرهٔ `if`ها، فهرست خوانده
    // می‌شود. ترتیب دقیقاً همان ترتیبِ پیشین است.
    final hit = Advocate._arbiter.pick(<AnswerCandidate>[
      AnswerCandidate('موضوعِ تازه', () => _routes.newCase(raw)),
      AnswerCandidate('«هیچ‌کدام»', () => _routes.noOption(raw)),
      // پاسخ به «این موضوع تازه است یا مربوط به قبلی؟» پیش از هر قاعدهٔ دیگر؛
      // وگرنه «بله»/«خیر» ادامهٔ پروندهٔ قبلی خوانده می‌شود.
      AnswerCandidate('تازه است یا مربوط؟', () => _routes.pending(raw, n)),
      AnswerCandidate('دکمهٔ دستهٔ مشکل',
          () => _branchReply(raw, n, asked: branchAsked)),
      AnswerCandidate('کنار گذاشتنِ موضوع', () => _leaveReply(raw)),
      // ایمنی پیش از هر چیز و مستقل از امتیازِ موضوع.
      AnswerCandidate('ایمنی', () => _safetyReply(n)),
      // «از برنامه خارج شدم» و جملهٔ کوتاهِ سوگ: پرسشِ واقعی، ولی نه ماجرای
      // حقوقی؛ پس از ایمنی می‌آید تا پیامِ خطر زیرش نماند.
      AnswerCandidate('دربارهٔ برنامه', () => _metaReplyBot.metaReply(raw, n)),
      AnswerCandidate('دعوا و شکایت', () => _routes.fight(n, hasCase)),
      AnswerCandidate('انتخابِ موضوع',
          () => _routes.choice(raw, n, choices, choiceText)),
      AnswerCandidate('حدسِ اشتباه', () => _routes.wrongGuess(raw, n, guessed)),
      AnswerCandidate('ادامهٔ حرفِ قبلی', () => _routes.more(raw, n, short)),
      AnswerCandidate('تنظیمِ سند', () => _filingReply(raw)),
      AnswerCandidate('پیشنهادِ پاسخ', () => _routes.offer(raw, n, short)),
      AnswerCandidate('«باشه»', () => _routes.bareAck(raw, n)),
      AnswerCandidate('موضوعِ کنارِ هم', () => _routes.side(raw, n)),
    ]);
    if (hit != null) return hit;
    final topic = _current();
    // محاسبهٔ موضوع از تصمیم جدا شد: این‌جا فقط خوانده می‌شود، بعد تصمیم
    // گرفته می‌شود.
    final read = _readTopics(n);

    // دُمِ مسیرها: پیش از امتیاززدنِ موضوع، «مهلت» و «موضوعِ صریح» جای خودشان
    // را دارند؛ پس داور یک بار تنها با «مهلت» صدا زده می‌شود، بعد پاسخِ
    // موضوعی می‌آید و بعد داورِ دوم.
    final due = Advocate._arbiter.pick(<AnswerCandidate>[
      AnswerCandidate('مهلت', () => _routes.deadline(raw, n, hasCase)),
    ]);
    if (due != null) return due;
    // موضوع صریح (امتیاز بالا، بدون پرونده) بر پاسخ‌های کلیِ مقدم برتری دارد.
    final meta = _meta(n, topic, explicit: topic == null && read.bestScore >= 5);
    if (meta != null) return meta;

    final tail = Advocate._arbiter.pick(<AnswerCandidate>[
      AnswerCandidate('تکرارِ حرفِ قبلی', () => _routes.repeat(prevN, n, hasCase)),
      AnswerCandidate('قاعدهٔ ثابت', () => _routes.fixedRules(n)),
      // مهلت اعتراض یا ابلاغ: مدت به نوع رأی و مرجع بستگی دارد و متن آن در
      // بانک من نیست؛ پس بی‌پاسخ رها نمی‌کنم، راه درست را می‌گویم.
      AnswerCandidate('مهلتِ اعتراض', () => _objectionDeadline(n)),
    ]);
    if (tail != null) return tail;
    // واژهٔ مشخصِ قانونی (مهریه، ودیعه، غبن…) وقتی هیچ پرونده‌ای باز نیست
    // و موضوعی هم تشخیص داده نشده: همان مادهٔ مستند را نشان می‌دهیم.
    if (!hasCase && read.bestScore < 3) {
      // «قهر» و حدس مطمئنِ خوانندهٔ موضوع پیش از متن قانون می‌آیند.
      final confidentGuess = guess != null && guess.confident;
      final lt = Sense.has(n, 'قهر') || confidentGuess ? null : _termReply.lawTerms(raw, n);
      if (lt != null) return lt;
      final refs = Understanding.linkedArticles(n);
      if (refs.isNotEmpty) {
        return _out(
          'این واژه به ${refs.join(' ')} مربوط است.',
          ask: 'ماجرای شما دقیقاً چیست؟ چه کسی و چه کاری کرده است؟',
          full: true,
        );
      }
    }

    // «قهر» جرم نیست و کسی را به‌خاطر قهر زندانی یا جریمه نمی‌کنند. این را
    // پیش از هر موضوع می‌گوییم تا برداشت اشتباه جا نماند.
    if (Sense.has(n, 'قهر') &&
        Sense.has(n, 'زندان|حبس|بازداشت|جریمه|پلیس|دادگاه')) {
      return _out(
        'قهر کردن جرم نیست و کسی را به‌خاطر قهر زندانی یا جریمه نمی‌کنند. اگر ماجرای دعوا یا رفتار طرف مقابل نگرانتان کرده، همان را تعریف کنید.',
        ask: 'چه اتفاقی افتاده است؟',
      );
    }

    if (Sense.has(n, 'گفتگوی من با برنامه|گفتگو با برنامه|با برنامه (?:هست|است)')) {
      return _out('درست است؛ این گفتگو با خود همین برنامه است. هر ماجرایی دارید، بگویید.',
          ask: 'چه چیزی را بررسی کنیم؟');
    }

    final corrected = _correctionReply(n, topic);
    if (corrected != null) return corrected;
    if (topic == null) return _noCaseReply(raw, n, read, guess);
    return _inCaseReply(raw, n, topic, read);
  }
}

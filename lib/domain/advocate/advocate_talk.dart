part of 'advocate.dart';

// گفت‌وگوی انسانی: حرف‌های غیرحقوقی، خلاصه، احوال‌پرسی و کنجکاوی.

const List<List<String>> _parties = [
  ['همسایه', 'همسایه‌تان'],
  ['برادر|داداش', 'برادرتان'],
  ['خواهر|آبجی', 'خواهرتان'],
  [' پدر| بابا', 'پدرتان'],
  [' مادر| مامان', 'مادرتان'],
  ['نامزد', 'نامزدتان'],
  ['همکار', 'همکارتان'],
  ['دوستم|رفیق', 'دوستتان'],
  ['عمو|دایی|خاله|عمه|فامیل|اقوام|پسرعمو|دخترعمو', 'یکی از بستگانتان'],
  ['بانک', 'بانک'],
  ['شهرداری', 'شهرداری'],
  ['بیمه', 'بیمه'],
  ['پلیس|مامور|کلانتری', 'پلیس'],
  ['مدرسه|دانشگاه|آموزشگاه|مهدکودک', 'یک مرکز آموزشی'],
  ['دکتر|پزشک|بیمارستان|کلینیک|درمانگاه', 'پزشک یا مرکز درمانی'],
  ['فروشنده|مغازه دار|فروشگاه|نمایشگاه', 'فروشنده'],
  [' پیک |پستچی|اداره پست|شرکت پست|تیپاکس|باربری|اسنپ|تپسی', 'پیک یا شرکت حمل‌ونقل'],
  ['شرکت', 'یک شرکت'],
];

/// طرفِ ماجرا، اگر کاربر نامش را برده باشد.
String _party(String n) {
  for (final p in _parties) {
    if (Sense.has(n, p[0])) return p[1];
  }
  return '';
}

const Map<String, String> _areas = {
  'criminal_harm': 'به نظرم ماجرا جنبهٔ کیفری دارد.',
  'fraud_cyber': 'به نظرم پای کلاهبرداری یا سوءاستفاده در میان است.',
  'litigation_defense': 'پس پای دادگاه یا یک رأی در میان است.',
  'family': 'پس ماجرا خانوادگی است.',
  'labor': 'پس ماجرا به کار و کارفرما برمی‌گردد.',
  'lease': 'پس ماجرا به اجاره برمی‌گردد.',
  'debt': 'پس حرفِ پول و طلب است.',
  'cheque': 'پس حرفِ چک است.',
};

String _clip(String raw) {
  final t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.length <= 60) return t;
  final cut = t.lastIndexOf(' ', 60);
  return '${t.substring(0, cut < 20 ? 60 : cut)}…';
}

extension _Talk on Advocate {
  /// عبارت‌های ناامیدی؛ هم در `_meta` (وقتی موضوع باز است) و هم در `_hopeless`.
  static const String _hopelessPattern =
      'هیچ راهی|راهی نیست|راهی نداره|پولم رفت|کاری نمیشه کرد|یعنی هیچی|بیچاره شدم|بدبخت شدم|امیدی نیست|دستم به جایی';

  /// توهین‌های کوتاهی که پاسخ آرام می‌خواهند (در `_meta`).
  static const String _rudePattern = 'فهم نداری|بی ?[ ‌]?ارزش|بی فهم';

  /// همدلی برای ناامیدی وقتی هیچ موضوعی باز نیست.
  AdvocateReply? _hopeless(String n) {
    if (Sense.words(n) > 10 || !Sense.has(n, _hopelessPattern)) return null;
    return _out(
      'هنوز برای ناامیدشدن زود است؛ تقریباً همیشه راهی هست.',
      ask: 'چه اتفاقی افتاده؟',
      chips: _idleChips(),
    );
  }

  AdvocateReply? _meta(String n, Topic? topic) {
    final w = Sense.words(n);
    // توهین کوتاه («فهم نداری»، «بی ارزش»): پاسخ آرام؛ نه پرسش سنگین و نه
    // نقشهٔ راه، و موضوع باز هم حفظ می‌شود.
    if (w <= 5 && Sense.has(n, _rudePattern)) {
      return _out(
        'ناراحت شدنتان را می‌فهمم. اگر بگویید ماجرا چیست، تا جایی که بتوانم کمک می‌کنم.',
        ask: topic == null ? 'چه اتفاقی افتاده؟' : _askText,
        chips: topic == null ? _idleChips() : _askChips,
      );
    }
    if (w <= 8 &&
        Sense.has(n,
            'تو وکیلی|شما وکیل|وکیل هستی|وکیلی ؟|کی هستی|چی هستی|رباتی|ربات هستی|هوش مصنوعی|آدم واقعی|ادم واقعی|آدمی یا|اسمت چیه')) {
      return _out(
        'نه؛ من وکیل دادگستری نیستم و آدم هم نیستم. یک دستیار حقوقی‌ام که روی همین گوشی و بدون اینترنت کار می‌کند و حرف‌هایتان جایی نمی‌رود. کارم این است که ماجرا را بشنوم، سؤال بپرسم و بر پایهٔ متن قانون راهنمایی کنم؛ جای وکیل در دادگاه را نمی‌گیرم.',
        ask: topic == null ? 'حالا بگویید چه پیش آمده؟' : _askText,
        chips: topic == null ? _starters() : _askChips,
        full: true,
      );
    }
    // «چه کارهایی می‌توانی بکنی؟»: توانایی‌های برنامه. عمداً فاعل «تو/شما»
    // را می‌خواهد تا «چه کاری می‌توانم بکنم» (پرسش از وضع خودِ کاربر) با
    // آن یکی نشود.
    if (w <= 9 &&
        Sense.has(n,
            'چه کار(?:هایی|ایی|ی)? (?:میتونی|میتوانی|بلدی|میتونید|میتوانید)|کارهایی که (?:میتونی|میتوانی)|چی بلدی|چه کاری از دستت|چی از دستت برمیاد|چه کمکی (?:ازت|از دست شما|ازتون)')) {
      final v = engine.replies.variants('capabilities');
      return _out(
        _pick(v),
        ask: topic == null ? 'حالا بگویید چه پیش آمده؟' : _askText,
        chips: topic == null ? _starters() : _askChips,
        full: true,
      );
    }
    // وکیل و هزینه: راهنمای عملی، نه تحلیل پرونده. حتی وسط یک پرونده هم
    // جواب می‌گیرد، چون پرسش دربارهٔ وکیل همیشه معنا دارد.
    if (w <= 10 &&
        Sense.has(n,
            'وکیل (?:کجا|کدوم|کجاست|چطور|چگونه|بگیرم|بگیریم|لازمه|لازم|پیدا|خوبی)|پیدا کردن وکیل|(?:هزینه|حق ?الوکاله|حق ?وکالت|دستمزد) (?:وکیل|وکالت)|(?:مشاوره|وکالت|کمک حقوقی) (?:رایگان|مجانی|ارزون|ارزان)')) {
      return _out(
        'برای پیدا کردن وکیل می‌توانید از فهرست وکلای کانون وکلای دادگستری شهرتان استفاده کنید، یا به مراکز مشاوره حقوقی رایگان و دفاتر خدمات حقوقی مراجعه کنید. هزینهٔ وکالت را پیش از امضای قرارداد با وکیل روشن و کتبی کنید. اگر توان پرداخت ندارید، درباره‌اش هم بپرسید تا راه‌های کمک را بگویم.',
        ask: topic == null ? 'ماجرای شما چیست؟ اگر بگویید، می‌گویم برایش چه مدارکی لازم است.' : _askText,
        chips: topic == null ? _starters() : _askChips,
        full: true,
      );
    }
    // مهلت‌ها: جواب کلی، وقتی پرونده‌ای باز نیست. وسط پرونده، قواعد همان
    // موضوع دقیق‌تر جواب می‌دهند.
    if (topic == null &&
        w <= 10 &&
        Sense.has(n,
            'مهلت (?:شکایت|اعتراض|تجدیدنظر|فرجام|دادخواست|قانونی|دارم|داره|داریم|چقدره|چنده|چند روزه)|تا کی (?:باید|میتونم|میتوانم|مهلت)|مرور زمان|کی باید (?:شکایت|اقدام)')) {
      return _out(
        'مهلت‌های قانونی، مثل مهلت شکایت، اعتراض یا تجدیدنظر، بسته به نوع ماجرا فرق دارد و بعضی‌شان بسیار کوتاه‌اند. معمولاً از تاریخ ابلاغ یا از روز وقوع ماجرا شمرده می‌شود، پس تاریخ دقیق آن را یادداشت کنید. اگر بگویید ماجرا چیست، همان مهلت مشخص را می‌گویم.',
        ask: 'ماجرا چیست و کِی ابلاغ شده یا اتفاق افتاده است؟',
        chips: _starters(),
        full: true,
      );
    }
    if (w <= 10 &&
        Sense.has(n,
            'میشه (?:[^ ]+ ){0,3}اعتماد|اعتماد کنم|قابل اعتماد|مطمئنی|از کجا میدونی|از کجا معلوم|درست میگی|حرف(?:ات|هات) درست|منبع(?:ت)? چیه|دروغ نمیگی')) {
      return _out(
        'سؤال به‌جایی است. هر ماده‌ای که نام می‌برم واقعاً در بانک قوانین برنامه هست و هر وقت بخواهید متنش را نشانتان می‌دهم؛ از خودم ماده نمی‌سازم. ولی سه محدودیت دارم: مدارکتان را ندیده‌ام، ممکن است قانون تازه‌تر شده باشد، و رویهٔ دادگاه‌ها را یک وکیل حضوری بهتر می‌داند. برای تصمیم‌های بزرگ حرف آخر را با وکیل دادگستری چک کنید.',
        ask: _askText,
        chips: _askText.isEmpty ? _idleChips() : _askChips,
        full: true,
      );
    }
    if (w <= 7 &&
        !Sense.has(n, '(?:ماده|اصل) [0-9]+') &&
        _lastLaws.isNotEmpty &&
        Sense.has(n,
            'متن (?:قانون|ماده)|کدوم ماده|کدام ماده|طبق کدوم|طبق کدام|ماده ?(?:اش|ش) (?:چی|رو|را)|مستند(?:ت|ش)? چی|سندت چیه')) {
      final lines = [
        for (final l in _lastLaws.take(2)) '• ${l.title}: «${_snippet(l.body)}»',
      ];
      return _out(
        'متن قانونی که به آن تکیه کردم:\n${lines.join('\n')}',
        ask: _askText,
        chips: _askChips,
        full: true,
      );
    }
    if (w <= 8 &&
        Sense.has(n,
            'چی فهمیدی|چه فهمیدی|متوجه (?:شدی|حرفم)|فهمیدی چی|حرف(?:م|مو|م رو) فهمیدی|گرفتی چی|میفهمی چی')) {
      final got = topic == null ? const <String>[] : _recap(topic);
      if (topic == null || got.isEmpty) {
        return _out(
          topic == null
              ? 'هنوز ماجرای مشخصی از شما نشنیده‌ام که بگویم چه فهمیده‌ام.'
              : 'می‌دانم موضوع «${topic.title}» است، ولی هنوز جزئیات کافی ندارم.',
          ask: topic == null || _askText.isEmpty
              ? 'دقیقاً چه اتفاقی افتاده است؟'
              : _askText,
          chips: topic == null ? _idleChips() : _askChips,
        );
      }
      return _out(
        '${_pick(Say.understood)} ${_join(got)}.',
        ask: 'درست گرفته‌ام، یا جایی را باید اصلاح کنم؟',
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
          'حق دارید بپرسید. ${p.why}\nاگر نمی‌دانید هم اشکالی ندارد؛ از آن می‌گذرم.',
          ask: 'سؤالم این بود: ${p.ask}',
          chips: [...p.options, _dontKnowChip],
          full: true,
        );
      }
      final why = file.pending == 'q:reply'
          ? 'چون جوابِ او نشان می‌دهد با چه دفاعی روبه‌رو می‌شوید؛ کسی که انکار می‌کند با کسی که فقط عقب می‌اندازد، دو راهِ متفاوت می‌خواهد.'
          : file.pending == 'q:goal'
              ? 'چون راهِ توافق و راهِ دادگاه دو مسیرِ جدا هستند و نمی‌خواهم وقتتان را در مسیری بگذارم که خودتان نمی‌خواهید.'
              : 'برای اینکه جوابم به وضعیت خودِ شما بخورد، نه یک توضیح کلی. در حقوق یک جزئیات کوچک، مثل یک تاریخ یا یک امضا، می‌تواند نتیجه را عوض کند.';
      return _out(
        why,
        ask: _askText,
        chips: _askText.isEmpty ? _idleChips() : _askChips,
        full: true,
      );
    }
    if (w <= 6 && Sense.has(n, 'خلاصه|جمع ?بندی|در یک جمله|تهش چی|آخرش چی')) {
      return _summary(topic);
    }
    if (w <= 6 &&
        Sense.has(n,
            'ساده ?تر|ساده بگو|نفهمیدم|متوجه نشدم|گیج شدم|پیچیده|دوباره بگو|یه بار دیگه|نگرفتم')) {
      if (_lastBody.isEmpty) {
        return _out('هنوز چیزی نگفته‌ام که پیچیده باشد.',
            ask: 'چه مشکلی پیش آمده؟', chips: _idleChips());
      }
      final lines = <String>[
        for (final l in _strip(_lastBody).split('\n'))
          if (l.trim().isNotEmpty) _brief(l.trim()),
      ];
      return _out(
        'ساده‌ترش این است:\n${lines.take(4).join('\n')}',
        ask: 'کدام کلمه یا کدام بخشش هنوز گنگ است؟',
        chips: topic == null ? _idleChips() : _suggest(topic),
      );
    }
    // بی‌موضوع: همدلی با ناامیدی پس از نظر دوم می‌آید (`_hopeless`)، تا
    // جمله‌ای مثل «کارتم هک شد و پولم رفت» موضوعش را از دست ندهد.
    if (topic != null && w <= 10 && Sense.has(n, _hopelessPattern)) {
      final c = topic.follow['chance'];
      final n2 = topic.follow['next'];
      final sb = StringBuffer('نه، بن‌بست نیست؛ فقط راهش سرراست نیست.');
      if (c != null) sb.write('\n${c(file)}');
      if (n2 != null && !file.covered.contains('f:next')) {
        sb.write('\n\n${n2(file)}');
        file.covered.add('f:next');
      }
      _lastBody = sb.toString();
      return _out(_lastBody, chips: _suggest(topic));
    }
    return null;
  }

  AdvocateReply _summary(Topic? topic) {
    final g = _guide;
    if (topic == null && g != null) {
      return _out(g.brief.isNotEmpty ? g.brief : _sentences(g.answer).take(2).join(' '),
          chips: const [Advocate.newCaseChip]);
    }
    if (topic == null) {
      return _out(
        'هنوز ماجرایی تعریف نکرده‌اید که خلاصه‌اش کنم.',
        ask: 'چه شده؟ کوتاه هم بگویید کافی است.',
        chips: _idleChips(),
      );
    }
    final sb = StringBuffer('خلاصه و بدون حاشیه:\n');
    final got = _recap(topic);
    if (got.isNotEmpty) sb.write('• ماجرا: ${_join(got)}.\n');
    final open = _sentences(_strip(topic.opening(file)));
    if (open.isNotEmpty) sb.write('• حرف قانون: ${open.first}\n');
    final plan = topic.follow['next'];
    if (plan != null) {
      final steps = [
        for (final l in _strip(plan(file)).split('\n'))
          if (RegExp('^[۰-۹]+[)]').hasMatch(l.trim())) _brief(l.trim()),
      ];
      if (steps.isNotEmpty) {
        sb.write('• کاری که باید بکنید:\n');
        for (final s in steps.take(4)) {
          sb.write('   $s\n');
        }
      }
    }
    final q = _nextSlot(topic);
    if (q != null) {
      sb.write('• چیزی که هنوز نمی‌دانم و مهم است: ${q.ask}');
    }
    return _out(sb.toString().trimRight(),
        chips: _suggest(topic), budget: _roomyBudget);
  }

  AdvocateReply? _social(String n, Topic? topic) {
    final w = Sense.words(n);
    if (w > 7) return null;
    if (Sense.has(n, 'ممنون|مرسی|متشکر|سپاس|دستت درد نکنه|دمت گرم|لطف کردی|تشکر')) {
      return _out(
        topic == null
            ? 'خواهش می‌کنم. هر وقت سؤالی بود، همین‌جا هستم.'
            : _askText.isNotEmpty
                ? 'خواهش می‌کنم.'
                : 'خواهش می‌کنم. اگر در ادامهٔ کار به مشکلی خوردید یا طرف مقابل حرکت تازه‌ای کرد، همین‌جا بگویید تا قدم بعد را با هم بچینیم.',
        chips: _idleChips(),
      );
    }
    if (Sense.has(n, 'خداحافظ|خدانگهدار|خدا نگهدار|فعلا |بای ')) {
      return _out('خدانگهدار. امیدوارم کارتان به‌خوبی پیش برود.');
    }
    if (Sense.has(n, '^ (?:سلام|درود|وقت بخیر|صبح بخیر|عصر بخیر|شب بخیر|خسته نباشی)')) {
      return _out(
        topic == null
            ? 'سلام، خوش آمدید.'
            : 'سلام دوباره. پرونده‌تان را به خاطر دارم.',
        ask: topic == null ? 'چه اتفاقی افتاده که سراغ من آمده‌اید؟' : _askText,
        chips: topic == null ? _starters() : _askChips,
      );
    }
    if (Sense.has(n, 'خوبی|چطوری|حالت چطوره|چه خبر')) {
      return _out('ممنون که می‌پرسید؛ من آماده‌ام.',
          ask: topic == null ? 'چه کمکی از دستم برمی‌آید؟' : _askText,
          chips: topic == null ? _starters() : _askChips);
    }
    return null;
  }

  bool _vague(String n) =>
      Sense.words(n) <= 9 &&
      Sense.has(n,
          'مشکل(?:ی)? (?:حقوقی |قانونی )?(?:دارم|پیش اومده|برام)|سوال(?:ی)? (?:حقوقی )?(?:داشتم|دارم)|مشاوره|کمک(?:م)? (?:کن|میخوام|کنید)|راهنمایی(?:م)? (?:کن|میخوام|کنید)|گرفتار شدم|یه مسئله');

  AdvocateReply _intake() => _out(
        'در خدمتم.',
        ask:
            'چه اتفاقی افتاده و طرف مقابل کیست؟ همان‌طور که برای یک دوست تعریف می‌کنید بگویید.',
        chips: _starters(),
      );

  /// وقتی موضوع را نمی‌شناسم: به‌جای «متوجه نشدم»، نشان می‌دهم چه شنیده‌ام
  /// و مثل هر وکیلی دربارهٔ ماجرا می‌پرسم تا تصویر روشن شود.
  AdvocateReply _curious(String raw, String n) {
    final all = _loose.join(' ');
    final who = _party(all);
    var area = '';
    final net = intentNet;
    if (net != null && Sense.words(n) >= 3) {
      final top = net.classify(raw);
      if (top.score >= 0.5) area = _areas[top.label] ?? '';
    }
    final allN = Sense.norm(all);
    final known = who.isNotEmpty ||
        area.isNotEmpty ||
        Sense.has(allN, 'پول|خسارت|پس بد|برگرد|غرامت|هزینه|شکایت|مجازات|زندان|جرم');
    // نه طرفی شناخته شد، نه موضوعی، نه نکته‌ای: به‌جای حدس یا جملهٔ ثابت،
    // کلمه‌های خودِ کاربر را نقل می‌کنم و توضیح می‌خواهم.
    if (!known) return _out(_unclearText(raw));
    final heard = who.isNotEmpty
        ? 'پس طرفِ ماجرا $who است.'
        : 'گفتید «${_clip(raw)}».';
    final k = _loose.length;
    if (k <= 1) {
      return _out(area.isEmpty ? heard : '$heard $area',
          ask: who.isNotEmpty
              ? 'دقیقاً چه اتفاقی افتاد و از چه زمانی؟'
              : Sense.words(n) >= 4
                  ? 'این از کِی پیش آمده و تا حالا برایش چه کرده‌اید؟'
                  : 'طرف مقابل کیست و دقیقاً چه کرده است؟');
    }
    if (k == 2) {
      return _out(area.isEmpty ? 'متوجه شدم.' : area,
          ask:
              'و خودتان الان چه می‌خواهید: مال یا پولتان برگردد، از او شکایت کنید، یا از خودتان دفاع کنید؟');
    }
    // برای ماجرایی که تحلیل آماده ندارم، دست‌کم راهِ کلی را روراست می‌گویم.
    if (Sense.has(allN, 'پول|خسارت|پس بد|برگرد|غرامت|هزینه')) {
      return _out(
        'برای این نوع ماجرا تحلیل آماده‌ای ندارم، ولی راه کلیِ پس‌گرفتن پول یا خسارت این است: اول کتبی و قابل اثبات مطالبه کنید (پیام یا اظهارنامهٔ رسمی)، و اگر نداد، دادخواست مطالبهٔ وجه یا خسارت بدهید.',
        ask: 'مبلغش حدوداً چقدر است و چه مدرکی از این ماجرا دارید؟',
      );
    }
    if (Sense.has(allN, 'شکایت|مجازات|زندان|جرم')) {
      return _out(
        'برای این نوع ماجرا تحلیل آماده‌ای ندارم، ولی راه کلیِ شکایت این است: شکوائیه را با مدارکتان در دفتر خدمات الکترونیک قضایی ثبت می‌کنید و دادسرا رسیدگی را شروع می‌کند.',
        ask: 'چه مدرک یا شاهدی از این ماجرا دارید؟',
      );
    }
    return _out(_unclearText(raw));
  }

  /// پاسخ به پیامی که به هیچ نکته‌ای وصل نشد. نخست با نقل همان کلمه‌های
  /// کاربر می‌پرسد منظورش چیست؛ اگر پس از توضیحش باز نامفهوم ماند، می‌گوید
  /// چنین درخواستی در پایگاه داده‌اش نیست و جوابی ندارد.
  String _unclearText(String raw) {
    if (_unclearPhrase.isNotEmpty && _unclearTurn == file.turns - 1) {
      final p = _unclearPhrase;
      _unclearPhrase = '';
      _unclearTurn = -10;
      return 'با توجه به اینکه «$p» در پایگاه داده‌ام نیست، جوابی برایش ندارم.';
    }
    _unclearPhrase = _quoteWords(raw);
    _unclearTurn = file.turns;
    return 'منظورت از «$_unclearPhrase» چیست؟ بیشتر توضیح بده.';
  }
}

/// نقل کوتاهِ کلمه‌های کاربر: بی‌علامت پایانی و حداکثر شش کلمه.
String _quoteWords(String raw) {
  final words = raw
      .trim()
      .replaceAll(RegExp(r'[؟?!.،,]+$'), '')
      .trim()
      .split(RegExp(r'\s+'));
  final head = words.take(6).join(' ');
  return words.length > 6 ? '$head…' : head;
}

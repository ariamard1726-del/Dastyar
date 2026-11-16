part of 'advocate.dart';

// استدلال: سنجش ادعاها و گفتنِ نظر وکیل دربارهٔ هرکدام.

const List<String> _ords = ['اول', 'دوم', 'سوم', 'چهارم', 'پنجم', 'ششم'];

const List<String> _counts = ['یک', 'دو', 'سه', 'چهار', 'پنج', 'شش'];

String _ord(int k) =>
    k >= 1 && k <= _ords.length ? _ords[k - 1] : Sense.fa(k);

String _count(int k) =>
    k >= 1 && k <= _counts.length ? _counts[k - 1] : Sense.fa(k);

String _claimName(ClaimView v) =>
    v.claim.label.isEmpty ? v.claim.goal : v.claim.label;

const String _entitled =
    'تعلق|میرسه|میرسد|میتونم|میتوانم|میشه|میشود|حق (?:دارم|من|منه)|حقمه|میگیرم|میدن|میدهند| یا نه |ممکنه|امکان|قانونی|درسته';

const String _howAsked =
    'چقدر|چند |مبلغ|حساب کن|چطور|چجوری|چه جوری|چگونه|کجا|کی |چه مدرک|چیکار|چه کار';

extension _Arguing on Advocate {
  /// ادعایی که به وضعیت فعلی پرونده می‌خورد.
  Claim? _claim(Topic t) {
    for (final c in t.claims) {
      final w = c.when;
      if (w == null || w(file)) return c;
    }
    return null;
  }

  /// استدلال: شرط‌های قانونیِ ادعاها را یکی‌یکی روی واقعیت‌های همین پرونده
  /// می‌سنجد و از جمع آن‌ها نتیجه می‌گیرد. متن ازپیش‌نوشته نیست؛ با عوض‌شدن
  /// هر واقعیت، استدلال و نتیجه هم عوض می‌شود.
  String? _argue(Topic t) {
    final views = Reasoner.assess(t, file);
    if (views.isEmpty) return null;
    return views.length == 1 ? _argueOne(views.first) : _argueMany(views);
  }

  /// وضع ادعاهای روی میز، پیش از شنیدنِ حرف تازه.
  Map<String, Standing> _standings(Topic t) => {
        for (final v in Reasoner.assess(t, file)) _claimName(v): v.standing,
      };

  /// دلیل‌های برقراریِ شرط‌هایی که محرزند، به زبان خودِ کاربر.
  List<String> _reasons(ClaimView v) => [
        for (final e in v.elements)
          if (e.holds == true && e.element.because != null)
            e.element.because!(file).trim(),
      ]..removeWhere((x) => x.isEmpty);

  /// حرف تازه چه چیزی را در نتیجه جابه‌جا کرد؟ یا خواستهٔ تازه‌ای کنار
  /// خواستهٔ اصلی آمده، یا (اگر قبلاً تحلیل داده‌ام) حکمِ یک خواسته عوض شده.
  String _shift(Topic t, Map<String, Standing> before) {
    if (before.isEmpty) return '';
    final now = Reasoner.assess(t, file);
    if (now.isEmpty) return '';
    final leadKept = before.keys.first == _claimName(now.first);
    for (var i = 0; i < now.length; i++) {
      final v = now[i];
      final name = _claimName(v);
      final old = before[name];
      if (old == null) {
        if (v.claim.label.isEmpty || i == 0 || !leadKept) continue;
        return 'این را هم کنار بقیه گذاشتم: «$name» خواستهٔ جداگانه‌ای است و حسابش را جدا نگه می‌دارم.';
      }
      if (old == v.standing || v.standing == Standing.open) continue;
      if (!file.covered.contains('f:argue')) continue;
      final was = old == Standing.strong
          ? 'محکم بود'
          : (old == Standing.open ? 'هنوز باز بود' : 'گیر داشت');
      return v.standing == Standing.strong
          ? 'این حرفتان حساب را عوض کرد: «$name» که $was، حالا همهٔ شرط‌هایش جمع است.'
          : 'این حرفتان حساب را عوض کرد: «$name» که $was، حالا گیر دارد.';
    }
    return '';
  }

  /// اگر کاربر حرف قبلی‌اش را برعکس کرده، می‌گویم برداشتم از چه به چه عوض
  /// شد؛ بی‌سروصدا عوض‌کردنِ واقعیت، اعتماد را از بین می‌برد.
  String _correction(Topic t) {
    if (_flips.isEmpty) return '';
    final now = _recap(t);
    for (final e in _flips.entries) {
      final cur = file.facts[e.key];
      if (cur == null) continue;
      file.facts[e.key] = e.value;
      final was = _recap(t);
      file.facts[e.key] = cur;
      final gone = [
        for (final x in was)
          if (!now.contains(x)) x,
      ];
      final came = [
        for (final x in now)
          if (!was.contains(x)) x,
      ];
      if (gone.isEmpty || came.isEmpty) continue;
      return 'برداشتم را اصلاح کردم: قبلاً نوشته بودم «${gone.first}»؛ حالا «${came.first}».';
    }
    return '';
  }

  /// کاربر دربارهٔ شدنی‌بودنِ کدام خواسته می‌پرسد؟ فقط پرسش‌های «می‌شود /
  /// نمی‌شود»؛ «چقدر» و «چطور» جواب خودشان را دارند. در موضوع‌هایی که
  /// خواسته‌هایشان نام ندارد، اگر پرسش به بحث مشخص‌تری خورده باشد همان
  /// مقدم است.
  ClaimView? _askedClaim(Topic t, String n, Issue? issue) {
    // «نمی‌دانم بیمه رد می‌شود یا نه» خبر است، نه پرسش.
    if (!Sense.isQuestion(n) || Sense.saysDontKnow(n)) return null;
    if (!Sense.has(n, _entitled) || Sense.has(n, _howAsked)) return null;
    for (final v in Reasoner.assess(t, file)) {
      final c = v.claim.cues;
      if (c.isEmpty || !Sense.has(n, c)) continue;
      if (issue != null && v.claim.label.isEmpty) return null;
      return v;
    }
    return null;
  }

  /// حکمِ یک خواسته روی واقعیت‌های همین پرونده: بله، هنوز معلوم نیست، یا
  /// فعلاً نه — هر کدام با دلیلش.
  String _verdict(ClaimView v) {
    final c = v.claim;
    final why = _reasons(v);
    final sb = StringBuffer();
    if (v.standing == Standing.strong) {
      sb.write(why.isEmpty
          ? 'بله؛ با چیزهایی که گفتید همهٔ شرط‌های قانونی‌اش جمع است. '
          : 'بله؛ چون ${_join(why)}. ');
      sb.write('پس ${c.win(file)}');
      final counter = c.counter;
      if (counter != null) {
        final x = counter(file);
        if (x.isNotEmpty) sb.write('\n${_pick(Say.counter)} $x');
      }
    } else if (v.standing == Standing.open) {
      sb.write('هنوز نمی‌توانم قطعی بگویم، ولی معلوم است به چه بسته است.');
      if (why.isNotEmpty) sb.write(' تا اینجا به نفع شماست که ${_join(why)}.');
      sb.write(v.open.length == 1
          ? ' یک چیز مانده:'
          : ' ${_count(v.open.length)} چیز مانده:');
      for (final e in v.elements) {
        if (e.holds == null) sb.write('\n• ${e.element.text}');
      }
      sb.write(
          '\nاگر ${v.open.length == 1 ? 'آن هم' : 'آن‌ها هم'} برقرار باشد، ${c.win(file)}');
    } else {
      sb.write('با چیزهایی که تا اینجا گفتید، فعلاً نه.');
      for (final e in v.elements) {
        if (e.holds != false) continue;
        sb.write(e.element.ifNo.isEmpty
            ? ' این شرط برقرار نیست: ${e.element.text}'
            : ' ${e.element.ifNo}');
      }
      if (why.isNotEmpty) {
        sb.write('\nاز آن طرف، ${_join(why)}؛ این‌ها به کارتان می‌آید.');
      }
    }
    return sb.toString();
  }

  /// «چون …»: پایهٔ واقعیِ برقراریِ یک شرط، به زبان خودِ کاربر.
  String _because(Element e) {
    final b = e.because;
    if (b == null) return '';
    final x = b(file).trim();
    return x.isEmpty ? '' : '، چون $x';
  }

  String _argueOne(ClaimView v) {
    final c = v.claim;
    final total = v.elements.length;
    final sb = StringBuffer('${_pick(Say.argue)}\n');
    sb.write(total == 1
        ? 'هدف: ${c.goal}. برای رسیدن به آن، قانون یک شرط دارد:\n'
        : 'هدف: ${c.goal}. برای رسیدن به آن، قانون ${_count(total)} شرط دارد:\n');
    for (var i = 0; i < total; i++) {
      final e = v.elements[i].element;
      final h = v.elements[i].holds;
      final String mark;
      if (h == true) {
        mark = '✓ ${_pick(Say.holds)}${_because(e)}.';
      } else if (h == false) {
        mark = '✗ ${_pick(Say.fails)}.${e.ifNo.isEmpty ? '' : ' ${e.ifNo}'}';
      } else {
        mark = '؟ ${_pick(Say.unknown)}.';
      }
      sb.write('• شرط ${_ord(i + 1)}: ${e.text}\n   $mark\n');
    }
    final ok = v.met;
    final failed = v.failed;
    final open = v.open;
    if (failed.isEmpty && open.isEmpty) {
      sb.write(
          '${total == 1 ? 'نتیجه: این شرط برقرار است' : 'نتیجه: هر ${_count(total)} شرط جمع است'}؛ پس ${c.win(file)}\n'
          'ارزیابی من: پروندهٔ قوی‌ای دارید، به شرط اینکه همین‌ها را با مدرک نشان بدهید.');
    } else if (failed.isNotEmpty) {
      sb.write(
          'نتیجه: چون شرط ${_join([for (final k in failed) _ord(k)])} برقرار نیست، کار فعلاً همین‌جا گیر است؛ اول باید همین گره باز شود تا این راه به نتیجه برسد');
      sb.write(ok > 0
          ? ' (${_count(ok)} شرط دیگر را دارید و به کارتان می‌آید).'
          : '.');
      if (open.isNotEmpty) {
        sb.write(
            ' شرط ${_join([for (final k in open) _ord(k)])} هم هنوز برایم روشن نیست.');
      }
    } else {
      sb.write(
          'نتیجه تا اینجا: ${ok == 0 ? 'هنوز هیچ‌کدام از شرط‌ها برایم محرز نیست' : '${_count(ok)} شرط از ${_count(total)} شرط محرز است'} و حرف آخر به شرط ${_join([for (final k in open) _ord(k)])} بستگی دارد. اگر ${open.length == 1 ? 'آن هم' : 'آن‌ها هم'} برقرار باشد، ${c.win(file)}');
    }
    final counter = c.counter;
    if (counter != null) {
      final x = counter(file);
      if (x.isNotEmpty) sb.write('\n${_pick(Say.counter)} $x');
    }
    return sb.toString();
  }

  /// وقتی یک ماجرا چند خواسته دارد: اول حکمِ هر کدام در یک خط، بعد دلیلِ
  /// هر حکم، و در آخر دفاعی که باید منتظرش بود. قوی و ضعیف جدا گفته می‌شود
  /// تا کاربر بداند روی کدام تکیه کند.
  String _argueMany(List<ClaimView> views) {
    String name(ClaimView v) =>
        v.claim.label.isEmpty ? v.claim.goal : v.claim.label;
    final sb = StringBuffer('${_pick(Say.argue)}\n');
    sb.write(
        'با آنچه تا اینجا گفتید ${_count(views.length)} خواسته دارید و وضع هر کدام فرق می‌کند:\n');
    for (final v in views) {
      final String verdict;
      switch (v.standing) {
        case Standing.strong:
          verdict = 'دستتان پر است';
        case Standing.open:
          verdict = v.open.length == 1
              ? 'به یک نکته بسته است'
              : 'به ${_count(v.open.length)} نکته بسته است';
        case Standing.weak:
          verdict = 'فعلاً گیر دارد';
      }
      sb.write('• ${name(v)}: $verdict.\n');
    }
    for (final v in views) {
      final c = v.claim;
      sb.write('\n${name(v)} — ');
      switch (v.standing) {
        case Standing.strong:
          final why = _reasons(v);
          sb.write(why.isEmpty
              ? 'همهٔ شرط‌هایش جمع است؛ پس ${c.win(file)}'
              : '${_join(why)}؛ پس ${c.win(file)}');
        case Standing.open:
          sb.write(v.met == 0
              ? 'هنوز هیچ شرطی برایم محرز نیست. '
              : '${_count(v.met)} شرط از ${_count(v.elements.length)} شرط محرز است. ');
          final rest = [
            for (final e in v.elements)
              if (e.holds == null) e.element.text,
          ];
          if (rest.length == 1) {
            sb.write('مانده این‌که ${rest.first}');
          } else {
            sb.write('مانده:');
            for (final x in rest) {
              sb.write('\n   • $x');
            }
          }
          sb.write('\nاگر برقرار باشد، ${c.win(file)}');
        case Standing.weak:
          for (final e in v.elements) {
            if (e.holds != false) continue;
            sb.write(e.element.ifNo.isEmpty
                ? 'این شرط برقرار نیست: ${e.element.text} '
                : '${e.element.ifNo} ');
          }
          if (v.open.isNotEmpty) {
            sb.write(
                '${v.open.length == 1 ? 'یک شرط' : '${_count(v.open.length)} شرط'} دیگرش هم هنوز روشن نیست.');
          }
      }
    }
    final strong = [
      for (final v in views)
        if (v.standing == Standing.strong) name(v),
    ];
    final weak = [
      for (final v in views)
        if (v.standing == Standing.weak) name(v),
    ];
    if (strong.isNotEmpty || weak.isNotEmpty) {
      sb.write('\n\nجمع‌بندی من: ');
      if (strong.isNotEmpty) {
        sb.write(
            'روی ${_join(strong)} محکم بایستید، به شرط اینکه همین‌ها را با مدرک نشان بدهید');
      }
      if (weak.isNotEmpty) {
        sb.write(strong.isEmpty
            ? 'نقطهٔ ضعف شما ${_join(weak)} است؛ پیش از هر کاری باید گره‌اش را باز کنیم'
            : '؛ نقطهٔ ضعفتان ${_join(weak)} است');
      }
      sb.write('.');
    }
    // دفاعِ طرف مقابل را دربارهٔ مهم‌ترین ادعایی که هنوز زنده است می‌گویم.
    for (final v in views) {
      if (v.standing == Standing.weak) continue;
      final counter = v.claim.counter;
      if (counter == null) continue;
      final x = counter(file);
      if (x.isEmpty) continue;
      sb.write('\n${_pick(Say.counter)} $x');
      break;
    }
    return sb.toString().trimRight();
  }
}

part of 'advocate.dart';

// استدلال: سنجش ادعاها و گفتنِ نظر وکیل دربارهٔ هرکدام.

List<String> get _ords => advocateTextSeq('argueOrd', 6);

List<String> get _counts => advocateTextSeq('argueCount', 6);

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

/// سنجشِ ادعاها و گفتنِ نظرِ وکیل: «ارکانش را دارید یا نه، و چرا».
///
/// این رفتار پیش‌تر متدهای `Advocate` بود؛ ولی هیچ‌کدام به حالتِ گفتگو
/// کاری نداشتند — فقط پرونده و صدا را می‌خواندند. حالا کلاسِ خودش را دارند و
/// همان دو چیز را می‌گیرند.
class CaseArgument {
  CaseArgument(this.file, this.voice, this.recap, this.flips);

  final CaseFile file;
  final ReplyVoice voice;

  /// خلاصهٔ پرونده به شکل فهرستِ جمله‌ها؛ برای نشان‌دادنِ «چه عوض شد».
  final List<String> Function(Topic) recap;

  /// واقعیت‌هایی که کاربر برعکسشان گفته (نامِ واقعیت → مقدارِ پیشین).
  final Map<String, String> flips;

  String _pick(List<String> options) => voice.pick(options);

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
        return advocateFormat('argueShiftAdded', {'name': name});
      }
      if (old == v.standing || v.standing == Standing.open) continue;
      if (!file.covered.contains('f:argue')) continue;
      final was = old == Standing.strong
          ? advocateText('argueShiftWasStrong')
          : (old == Standing.open
              ? advocateText('argueShiftWasOpen')
              : advocateText('argueShiftWasWeak'));
      return v.standing == Standing.strong
          ? advocateFormat('argueShiftNowStrong', {'name': name, 'was': was})
          : advocateFormat('argueShiftNowWeak', {'name': name, 'was': was});
    }
    return '';
  }

  /// اگر کاربر حرف قبلی‌اش را برعکس کرده، می‌گویم برداشتم از چه به چه عوض
  /// شد؛ بی‌سروصدا عوض‌کردنِ واقعیت، اعتماد را از بین می‌برد.
  String _correction(Topic t) {
    if (flips.isEmpty) return '';
    final now = recap(t);
    for (final e in flips.entries) {
      final cur = file.facts[e.key];
      if (cur == null) continue;
      file.facts[e.key] = e.value;
      final was = recap(t);
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
      return advocateFormat(
          'argueCorrection', {'old': gone.first, 'now': came.first});
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
          ? advocateText('argueVerdictStrongPlain')
          : advocateFormat('argueVerdictStrongWhy', {'why': _join(why)}));
      sb.write(advocateFormat('argueVerdictWinPrefix', {'win': c.win(file)}));
      final counter = c.counter;
      if (counter != null) {
        final x = counter(file);
        if (x.isNotEmpty) sb.write('\n${_pick(Say.counter)} $x');
      }
    } else if (v.standing == Standing.open) {
      sb.write(advocateText('argueVerdictOpenLead'));
      if (why.isNotEmpty) {
        sb.write(advocateFormat('argueVerdictOpenWhy', {'why': _join(why)}));
      }
      sb.write(v.open.length == 1
          ? advocateText('argueVerdictOpenOne')
          : advocateFormat('argueVerdictOpenMany', {'count': _count(v.open.length)}));
      for (final e in v.elements) {
        if (e.holds == null) sb.write('\n• ${e.element.text}');
      }
      sb.write(advocateFormat('argueVerdictOpenIf', {
        'pronoun': v.open.length == 1
            ? advocateText('argueWordIt')
            : advocateText('argueWordThey'),
        'win': c.win(file),
      }));
    } else {
      sb.write(advocateText('argueVerdictWeakLead'));
      for (final e in v.elements) {
        if (e.holds != false) continue;
        sb.write(e.element.ifNo.isEmpty
            ? advocateFormat('argueVerdictWeakIfNoMissing', {'text': e.element.text})
            : ' ${e.element.ifNo}');
      }
      if (why.isNotEmpty) {
        sb.write(advocateFormat('argueVerdictWeakWhy', {'why': _join(why)}));
      }
    }
    return sb.toString();
  }

  /// «چون …»: پایهٔ واقعیِ برقراریِ یک شرط، به زبان خودِ کاربر.
  String _because(Element e) {
    final b = e.because;
    if (b == null) return '';
    final x = b(file).trim();
    return x.isEmpty ? '' : advocateFormat('argueBecausePrefix', {'because': x});
  }

  String _argueOne(ClaimView v) {
    final c = v.claim;
    final total = v.elements.length;
    final sb = StringBuffer('${_pick(Say.argue)}\n');
    sb.write(total == 1
        ? advocateFormat('argueOneGoalOne', {'goal': c.goal})
        : advocateFormat('argueOneGoalMany', {'goal': c.goal, 'count': _count(total)}));
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
      sb.write(advocateFormat('argueOneCondPrefix', {
        'ord': _ord(i + 1),
        'text': e.text,
        'mark': mark,
      }));
    }
    final ok = v.met;
    final failed = v.failed;
    final open = v.open;
    if (failed.isEmpty && open.isEmpty) {
      final lead = total == 1
          ? advocateText('argueOneResultStrongOne')
          : advocateFormat('argueOneResultStrongMany', {'count': _count(total)});
      sb.write(advocateFormat('argueOneResultStrongEnd', {
        'lead': lead,
        'win': c.win(file),
      }));
    } else if (failed.isNotEmpty) {
      sb.write(advocateFormat('argueOneResultFailLead', {
        'failed': _join([for (final k in failed) _ord(k)]),
      }));
      sb.write(ok > 0
          ? advocateFormat('argueOneResultFailMore', {'count': _count(ok)})
          : '.');
      if (open.isNotEmpty) {
        sb.write(advocateFormat('argueOneResultFailOpen', {
          'open': _join([for (final k in open) _ord(k)]),
        }));
      }
    } else {
      final metText = ok == 0
          ? advocateText('argueOneResultOpenNone')
          : advocateFormat('argueOneResultOpenSome', {
              'met': _count(ok),
              'total': _count(total),
            });
      sb.write(advocateFormat('argueOneResultOpenTail', {
        'metText': metText,
        'open': _join([for (final k in open) _ord(k)]),
        'pronoun': open.length == 1
            ? advocateText('argueWordIt')
            : advocateText('argueWordThey'),
        'win': c.win(file),
      }));
    }
    final counter = c.counter;
    if (counter != null) {
      final x = counter(file);
      if (x.isNotEmpty) sb.write('\n${_pick(Say.counter)} $x');
    }
    return sb.toString();
  }

  /// وقتی یک ماجرا چند خواسته دارد: اول حکمِ هر کدام در یک خط، بعد دلیلِ
  /// هر حکم، و در آخر دفاعی که باید منتظرش بود. قوی و ضعف جدا گفته می‌شود
  /// تا کاربر بداند روی کدام تکیه کند.
  String _argueMany(List<ClaimView> views) {
    String name(ClaimView v) =>
        v.claim.label.isEmpty ? v.claim.goal : v.claim.label;
    final sb = StringBuffer('${_pick(Say.argue)}\n');
    sb.write(advocateFormat('argueManyLead', {'count': _count(views.length)}));
    for (final v in views) {
      final String verdict;
      switch (v.standing) {
        case Standing.strong:
          verdict = advocateText('argueManyStrong');
        case Standing.open:
          verdict = v.open.length == 1
              ? advocateText('argueManyOpenOne')
              : advocateFormat('argueManyOpenMany', {'count': _count(v.open.length)});
        case Standing.weak:
          verdict = advocateText('argueManyWeak');
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
              ? advocateFormat('argueManyStrongAll', {'win': c.win(file)})
              : advocateFormat('argueManyStrongWhy', {
                  'why': _join(why),
                  'win': c.win(file),
                }));
        case Standing.open:
          sb.write(v.met == 0
              ? advocateText('argueManyOpenNone')
              : advocateFormat('argueManyOpenSome', {
                  'met': _count(v.met),
                  'total': _count(v.elements.length),
                }));
          final rest = [
            for (final e in v.elements)
              if (e.holds == null) e.element.text,
          ];
          if (rest.length == 1) {
            sb.write(advocateFormat('argueManyOpenOneLeft', {'item': rest.first}));
          } else {
            sb.write(advocateText('argueManyOpenManyLeft'));
            for (final x in rest) {
              sb.write('\n   • $x');
            }
          }
          sb.write(advocateFormat('argueManyOpenWin', {'win': c.win(file)}));
        case Standing.weak:
          for (final e in v.elements) {
            if (e.holds != false) continue;
            sb.write(e.element.ifNo.isEmpty
                ? advocateFormat('argueManyWeakIfNoMissing', {'text': e.element.text})
                : '${e.element.ifNo} ');
          }
          if (v.open.isNotEmpty) {
            final countLabel = v.open.length == 1
                ? advocateText('argueManyCondOne')
                : advocateFormat('argueManyCondMany', {'count': _count(v.open.length)});
            sb.write(advocateFormat('argueManyWeakMore', {'countLabel': countLabel}));
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
      sb.write(advocateText('argueManySummaryLead'));
      if (strong.isNotEmpty) {
        sb.write(advocateFormat('argueManySummaryStrong', {
          'strong': _join(strong),
        }));
      }
      if (weak.isNotEmpty) {
        sb.write(strong.isEmpty
            ? advocateFormat('argueManySummaryWeakOnly', {'weak': _join(weak)})
            : advocateFormat('argueManySummaryWeakAlso', {'weak': _join(weak)}));
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

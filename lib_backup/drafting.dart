import 'engine.dart';
import 'templates.dart';

class DraftCmd {
  static const String cancel = 'انصراف';
  static const String back = 'برگشت';
  static const String skip = 'رد کردن';
  static const String blank = 'جای خالی بماند';
  static const String edit = 'ویرایش یک پاسخ';
  static const String finish = 'پایان';
  static const String yes = 'بله';
  static const String no = 'خیر';
  static const String offerYes = 'بله، آماده کن';
  static const String offerNo = 'نه، فقط توضیح بده';
}

class DraftSession {
  final LegalTemplate template;
  final Map<String, String> values = {};
  int index = 0;
  int? editing;
  bool pickingEdit = false;
  bool done = false;

  DraftSession(this.template);

  TemplateField? get current {
    if (editing != null) return template.fields[editing!];
    if (index >= 0 && index < template.fields.length) {
      return template.fields[index];
    }
    return null;
  }
}

class DraftReply {
  final String text;
  final List<String> chips;
  final bool isDocument;
  final bool ended;
  final String note;

  const DraftReply(
    this.text, {
    this.chips = const [],
    this.isDocument = false,
    this.ended = false,
    this.note = '',
  });
}

class LawText {
  final String title;
  final String source;
  final String body;
  final String note;
  LawText(this.title, this.source, this.body, this.note);
}

class IntentResult {
  final LegalTemplate? template;
  final List<LegalTemplate> choices;
  const IntentResult(this.template, this.choices);
  bool get none => template == null && choices.isEmpty;
}

class Drafting {
  static const Set<String> _generic = {
    'زمان', 'کسی', 'متن', 'نامه', 'مورد', 'مبلغ',
  };

  static const List<String> _verbs = [
    'بنویس', 'نوشتن', 'تنظیم', 'تهیه', 'پیش نویس', 'پیشنویس',
    'بساز', 'آماده کن',
  ];

  static const List<String> _nouns = [
    'دادخواست', 'شکوائیه', 'شکواییه', 'شکایت', 'لایحه', 'اظهارنامه', 'اعسار',
  ];

  static const List<String> _questionWords = [
    'چیست', 'چیه', 'چه فرقی', 'چگونه', 'چطور', 'آیا', 'چرا', 'کجا', 'چقدر', '؟', '?',
  ];

  // پرسش‌های صرفاً اطلاعاتی: پیشنهاد تهیهٔ متن نمی‌آید.
  static const List<String> _definitional = [
    'چیست', 'چیه', 'چه فرقی', 'یعنی چه', 'معنی', 'تعریف', 'مجازات',
    'جرم است', 'جرمه', 'حکمش',
  ];

  static const String chooseText = 'کدام متن را می‌خواهید تهیه کنم؟';
  static const String suggestChooseText =
      'برای وضعیتی که نوشتید این متن‌ها می‌توانند مفید باشند. کدام را آماده کنم؟';

  static String offerText(LegalTemplate t) {
    final desc = t.description.isEmpty ? '' : '\n${t.description}';
    return 'به نظر می‌رسد «${t.title}» برای وضعیت شما مفید است.$desc\n\nمی‌خواهید همین حالا آماده‌اش کنم؟ این فقط یک پیشنهاد است و تصمیم نهایی با شماست.';
  }

  static final RegExp _nonLetter = RegExp(
    r'[^\u0621-\u063A\u0641-\u064A\u067E\u0686\u0698\u06A9\u06AF\u06CCa-z0-9]+',
  );
  static final RegExp _miPrefix = RegExp(r'(^| )(نمی|می) ');

  // یکسان‌سازی نیم‌فاصله و فاصله در «می/نمی» (نمی دهد = نمیدهد)
  static String _norm(String s) {
    var n = KnowledgeEngine.normalize(s).replaceAll(_nonLetter, ' ');
    n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
    return n.replaceAllMapped(_miPrefix, (m) => '${m.group(1)}${m.group(2)}');
  }

  static bool _kwHit(String kw, String text, List<String> words) {
    if (kw.contains(' ')) return text.contains(kw);
    for (final w in words) {
      if (w == kw) return true;
      if (kw.length >= 3 && w.startsWith(kw)) return true;
      if (kw.length < 3 && w.startsWith(kw) && w.length <= kw.length + 1) {
        return true;
      }
    }
    return false;
  }

  /// کلمه‌های کلیدی قالب. اگر با «-» شروع شود، کلمهٔ منفی است:
  /// وجودش در پیام یعنی این قالب برای وضعیت کاربر مناسب نیست.
  static int keywordScore(String text, LegalTemplate t) {
    final n = _norm(text);
    final words = n.split(' ');
    for (final k in t.keywords) {
      if (!k.startsWith('-')) continue;
      final kn = _norm(k.substring(1));
      if (kn.isNotEmpty && _kwHit(kn, n, words)) return 0;
    }
    var s = 0;
    for (final k in t.keywords) {
      if (k.startsWith('-')) continue;
      final kn = _norm(k);
      if (kn.isEmpty) continue;
      if (_kwHit(kn, n, words)) s++;
    }
    return s;
  }

  // فعل‌های امری: حتی با علامت پرسش، یعنی کاربر متن می‌خواهد.
  static const List<String> _imperatives = [
    'بنویس', 'بساز', 'آماده کن', 'تنظیم کن', 'تهیه کن', 'پیش نویس کن',
    'پیشنویس کن',
  ];

  static bool _wantsDraft(String n) {
    final asks = _questionWords.any((w) => n.contains(w));
    if (asks && !_imperatives.any((w) => n.contains(w))) return false;
    if (_verbs.any((w) => n.contains(w))) return true;
    return _nouns.any((w) => n.contains(w));
  }

  static Set<String> _titleTokens(LegalTemplate t) {
    return KnowledgeEngine.tokenize('${t.title} ${t.description}')
        .where((w) => !_generic.contains(w))
        .toSet();
  }

  /// کاربر صریحاً خواسته متنی تهیه شود (یا عنوان قالب را زده).
  static IntentResult detect(String text, List<LegalTemplate> ts) {
    if (ts.isEmpty) return const IntentResult(null, []);
    final n = KnowledgeEngine.normalize(text).trim();
    for (final t in ts) {
      if (KnowledgeEngine.normalize(t.title).trim() == n) {
        return IntentResult(t, const []);
      }
    }
    if (!_wantsDraft(n)) return const IntentResult(null, []);

    final tokens = KnowledgeEngine.tokenize(text).toSet();
    var best = 0;
    final scores = <LegalTemplate, int>{};
    for (final t in ts) {
      final tt = _titleTokens(t);
      final s = tokens.where((w) => tt.contains(w)).length +
          2 * keywordScore(text, t);
      scores[t] = s;
      if (s > best) best = s;
    }
    if (best == 0) return IntentResult(null, List.of(ts));
    final top = ts.where((t) => scores[t] == best).toList();
    if (top.length == 1) return IntentResult(top.first, const []);
    return IntentResult(null, top);
  }

  /// کاربر وضعیتش را شرح داده و صریحاً متن نخواسته: فقط پیشنهاد می‌دهیم.
  static IntentResult suggest(String text, List<LegalTemplate> ts) {
    if (ts.isEmpty) return const IntentResult(null, []);
    final n = KnowledgeEngine.normalize(text).trim();
    if (n.length < 6) return const IntentResult(null, []);
    if (_definitional.any((w) => n.contains(w))) {
      return const IntentResult(null, []);
    }
    var best = 0;
    final scores = <LegalTemplate, int>{};
    for (final t in ts) {
      final s = keywordScore(text, t);
      scores[t] = s;
      if (s > best) best = s;
    }
    if (best == 0) return const IntentResult(null, []);
    final top = ts.where((t) => scores[t] == best).toList();
    if (top.length == 1) return IntentResult(top.first, const []);
    return IntentResult(null, top);
  }

  static DraftReply start(DraftSession s) {
    final t = s.template;
    if (t.fields.isEmpty) return _document(s);
    final sb = StringBuffer();
    sb.writeln('برای «${t.title}» چند سؤال کوتاه می‌پرسم و متن را خودم آماده می‌کنم.');
    sb.writeln('هر زمان خواستید «${DraftCmd.back}» یا «${DraftCmd.cancel}» را بزنید.');
    if (!t.reviewed) {
      sb.writeln();
      sb.writeln(
        'توجه: ${t.reviewNote.isEmpty ? 'این قالب هنوز بازبینی نشده است.' : t.reviewNote}',
      );
    }
    if (t.tips.isNotEmpty) {
      sb.writeln();
      sb.writeln('نکته‌ها:');
      for (final tip in t.tips) {
        sb.writeln('• $tip');
      }
    }
    sb.writeln();
    final q = _question(s);
    sb.write(q.text);
    return DraftReply(sb.toString(), chips: q.chips);
  }

  static DraftReply _question(DraftSession s, {String prefix = ''}) {
    final f = s.current!;
    final sb = StringBuffer();
    if (prefix.isNotEmpty) {
      sb.writeln(prefix);
      sb.writeln();
    }
    if (s.editing == null) {
      final total = TemplateRenderer.toFa(s.template.fields.length.toString());
      final cur = TemplateRenderer.toFa((s.index + 1).toString());
      sb.write('($cur از $total) ');
    }
    sb.write(f.label);
    if (!f.required) sb.write(' (اختیاری)');
    if (f.hint.isNotEmpty) {
      sb.writeln();
      sb.write(f.hint);
    }

    final chips = <String>[];
    if (f.type == 'choice') {
      chips.addAll(f.options);
    } else if (f.type == 'check') {
      chips.addAll([DraftCmd.yes, DraftCmd.no]);
    }
    if (f.type != 'check') {
      chips.add(f.required ? DraftCmd.blank : DraftCmd.skip);
    }
    if (s.editing != null || s.index > 0) chips.add(DraftCmd.back);
    chips.add(DraftCmd.cancel);
    return DraftReply(sb.toString(), chips: chips);
  }

  static DraftReply _document(DraftSession s) {
    s.done = true;
    s.pickingEdit = false;
    final t = s.template;
    final text = TemplateRenderer.render(t, s.values);
    final miss = TemplateRenderer.missing(t, s.values);
    final note =
        miss.isEmpty ? '' : 'این موارد خالی مانده است: ${miss.join('، ')}';
    return DraftReply(
      text,
      isDocument: true,
      note: note,
      chips: [DraftCmd.edit, DraftCmd.finish],
    );
  }

  static DraftReply _editChoices(DraftSession s, {String prefix = ''}) {
    final text = prefix.isEmpty
        ? 'کدام پاسخ را می‌خواهید ویرایش کنید؟'
        : prefix;
    final chips = s.template.fields.map((f) => f.label).toList()
      ..add(DraftCmd.back);
    return DraftReply(text, chips: chips);
  }

  static const Set<String> _yes = {'بله', 'آره', 'اره', 'بلی', 'بله.'};
  static const Set<String> _no = {'خیر', 'نه', 'نخیر'};

  static bool isYes(String raw) =>
      _yes.contains(KnowledgeEngine.normalize(raw).trim());

  static bool isNo(String raw) =>
      _no.contains(KnowledgeEngine.normalize(raw).trim());

  static DraftReply answer(DraftSession s, String raw) {
    final input = raw.trim();

    if (input == DraftCmd.cancel) {
      return const DraftReply(
        'تهیهٔ این متن بسته شد. هر زمان خواستید دوباره بنویسید.',
        ended: true,
      );
    }
    if (input == DraftCmd.finish) {
      return const DraftReply(
        'موفق باشید. پیش از ثبت، متن را حتماً با یک کارشناس حقوقی یا مرکز مشاورهٔ رایگان بررسی کنید.',
        ended: true,
      );
    }

    if (s.pickingEdit) {
      if (input == DraftCmd.back) return _document(s);
      final idx = s.template.fields.indexWhere((f) => f.label == input);
      if (idx < 0) {
        return _editChoices(s, prefix: 'یکی از موارد زیر را انتخاب کنید.');
      }
      s.pickingEdit = false;
      s.editing = idx;
      return _question(s);
    }

    if (s.done) {
      if (input == DraftCmd.edit) {
        s.pickingEdit = true;
        return _editChoices(s);
      }
      return const DraftReply(
        'برای تغییر متن «${DraftCmd.edit}» را بزنید، یا «${DraftCmd.finish}» را.',
        chips: [DraftCmd.edit, DraftCmd.finish],
      );
    }

    final f = s.current;
    if (f == null) return _document(s);

    if (input == DraftCmd.back) {
      if (s.editing != null) {
        s.editing = null;
        return _document(s);
      }
      if (s.index > 0) s.index--;
      return _question(s);
    }

    String? value;
    String err = '';
    final isBlank = input == DraftCmd.blank || input == DraftCmd.skip;

    if (isBlank) {
      value = f.type == 'check' ? 'false' : '';
    } else if (f.type == 'check') {
      final n = KnowledgeEngine.normalize(input).trim();
      if (_yes.contains(n)) {
        value = 'true';
      } else if (_no.contains(n)) {
        value = 'false';
      } else {
        err = 'لطفاً «${DraftCmd.yes}» یا «${DraftCmd.no}» را انتخاب کنید.';
      }
    } else if (f.type == 'choice') {
      final n = KnowledgeEngine.normalize(input).trim();
      final exact = f.options
          .where((o) => KnowledgeEngine.normalize(o).trim() == n)
          .toList();
      if (exact.length == 1) {
        value = exact.first;
      } else {
        final part = f.options.where((o) {
          final on = KnowledgeEngine.normalize(o).trim();
          return n.length >= 2 && (on.contains(n) || n.contains(on));
        }).toList();
        if (part.length == 1) {
          value = part.first;
        } else {
          err = 'لطفاً یکی از گزینه‌ها را انتخاب کنید.';
        }
      }
    } else if (f.type == 'number') {
      final n = KnowledgeEngine.normalize(input).replaceAll(RegExp(r'\s'), '');
      final okFmt = RegExp(r'^(\d+|\d{1,3}([,،٬.]\d{3})+)$').hasMatch(n);
      final digits = n.replaceAll(RegExp(r'[^0-9]'), '');
      if (!okFmt || digits.isEmpty) {
        err = 'لطفاً فقط عدد کامل را بنویسید، بدون کلمه (مثلاً ۵۰۰۰۰۰۰۰).';
      } else {
        value = digits;
      }
    } else {
      value = input;
    }

    if (value == null) return _question(s, prefix: err);

    s.values[f.id] = value;
    if (s.editing != null) {
      s.editing = null;
      return _document(s);
    }
    s.index++;
    if (s.index >= s.template.fields.length) return _document(s);
    return _question(s);
  }

  static List<LawText> lawTexts(KnowledgeEngine e, LegalTemplate t) {
    final out = <LawText>[];
    for (final r in t.lawRefs) {
      final c = e.findArticle(r.law, r.article);
      if (c == null) continue;
      out.add(LawText(c.title, c.source, c.body, r.note));
    }
    return out;
  }
}

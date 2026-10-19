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

  static const String chooseText = 'کدام متن را می‌خواهید تهیه کنم؟';

  static bool _wantsDraft(String n) {
    if (_verbs.any((w) => n.contains(w))) return true;
    if (!_nouns.any((w) => n.contains(w))) return false;
    return !_questionWords.any((w) => n.contains(w));
  }

  static Set<String> _keywordTokens(LegalTemplate t) {
    final all = '${t.title} ${t.description} ${t.keywords.join(' ')}';
    return KnowledgeEngine.tokenize(all)
        .where((w) => !_generic.contains(w))
        .toSet();
  }

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
      final kw = _keywordTokens(t);
      final s = tokens.where(kw.contains).length;
      scores[t] = s;
      if (s > best) best = s;
    }
    if (best == 0) return IntentResult(null, List.of(ts));
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
      final n = KnowledgeEngine.normalize(input);
      final leftover = n.replaceAll(RegExp(r'[0-9\s,،٬.]'), '');
      final digits = n.replaceAll(RegExp(r'[^0-9]'), '');
      if (leftover.isNotEmpty || digits.isEmpty) {
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

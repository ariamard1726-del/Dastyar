import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/domain/draft_models.dart';
import 'package:dastyar/domain/draft_words.dart';
import 'package:dastyar/domain/templates.dart';

/// روندِ فرم: پرسشِ فیلدِ بعدی، پاسخِ کاربر، و متنِ نهایی.
///
/// وضعیت در `DraftSession` است؛ این کلاس فقط تصمیم می‌گیرد نوبتِ بعد چه دیده
/// شود. هیچ‌جا واژه‌های کلیدیِ قالب را نمی‌خواند.
class DraftStep {
  static final RegExp _whitespaceRe = RegExp(r'\s');
  static final RegExp _numberFmtRe =
      RegExp(r'^(\d+|\d{1,3}([,،٬.]\d{3})+)$');
  static final RegExp _nonDigitsRe = RegExp(r'[^0-9]');

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

  static DraftReply resumePrompt(DraftSession s) {
    final q = _question(s);
    return DraftReply(
      'پیش‌نویس ناتمام «${s.template.title}» بازیابی شد. می‌توانید از همان‌جا ادامه دهید یا «${DraftCmd.cancel}» را بزنید.\n\n${q.text}',
      chips: q.chips,
    );
  }

  static DraftReply _question(DraftSession s, {String prefix = ''}) {
    final f = s.current;
    if (f == null) return _document(s);
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
      if (DraftWords.isYes(input)) {
        value = 'true';
      } else if (DraftWords.isNo(input)) {
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
      final n = KnowledgeEngine.normalize(input).replaceAll(_whitespaceRe, '');
      final okFmt = _numberFmtRe.hasMatch(n);
      final digits = n.replaceAll(_nonDigitsRe, '');
      if (!okFmt || digits.isEmpty) {
        err = 'لطفاً فقط عدد کامل را بنویسید، بدون کلمه (مثلاً ۵۰۰۰۰۰۰۰).';
      } else {
        value = digits;
      }
    } else if (f.type == 'phone') {
      final normalizedPhone = PersianText.normalizeIranianPhone(input);
      if (normalizedPhone == null) {
        err = 'لطفاً شماره تلفن معتبر وارد کنید (مثلاً ۰۹۱۲۳۴۵۶۷۸۹).';
      } else {
        value = PersianText.toFaDigits(normalizedPhone);
      }
    } else if (f.type == 'national_id') {
      if (!PersianText.isValidIranianNationalId(input)) {
        err = 'کد ملی واردشده معتبر نیست؛ باید ۱۰ رقم صحیح باشد.';
      } else {
        value = PersianText.toFaDigits(PersianText.asciiDigits(input));
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
}

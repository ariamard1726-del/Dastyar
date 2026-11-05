import 'dart:convert';

import 'package:dastyar/domain/dialogue/dialogue_action.dart';
import 'package:dastyar/domain/dialogue/dialogue_state.dart';
import 'package:dastyar/domain/dialogue/domain_slot_schemas.dart';
import 'package:dastyar/domain/dialogue/evidence.dart';

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
        return _composeAskForSlot(action, state);
      case GiveAnswer():
        return _composeGiveAnswer(action);
      case ExplainConflict():
        return _composeExplainConflict(action, state);
      case DisambiguateDomain():
        return _composeDisambiguateDomain(action, state);
    }
  }

  // ── AskForSlot ──────────────────────────────────────────────────

  ComposedReply _composeAskForSlot(AskForSlot action, DialogueState state) {
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
    if (state.matchedSpans.isNotEmpty) {
      final first = state.matchedSpans.values.first;
      if (first.trim().isNotEmpty && !_containsLatin(first)) {
        return 'می‌فهمم که گفتید «${first.trim()}».';
      }
    }
    final last = state.lastUserUtterance.trim();
    if (last.isEmpty || _containsLatin(last)) return '';
    if (last.length > 50) {
      return 'می‌فهمم که گفتید «${last.substring(0, 50)}…».';
    }
    return 'می‌فهمم که گفتید «$last».';
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
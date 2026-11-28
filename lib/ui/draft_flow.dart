import 'dart:async';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/ui/app_settings.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/ui/chat_models.dart';

/// جریانِ «سند بنویس» — از «یک دادخواست می‌خواهم» تا متنِ نهایی.
///
/// این کار پیش‌تر داخل [ChatController] بود: کنترلرِ گفتگو هم پیام کاربر را به
/// وکیل می‌داد، هم فرمِ سند را می‌چرخاند، هم پیش‌نویسِ ناتمام را ذخیره
/// می‌کرد. سه کارِ جدا در یک کلاسِ ۵۳۰ خطی. حالا فرم و پیش‌نویس صاحبِ خودش
/// را دارند و کنترلر فقط پیام‌ها را نشان می‌دهد.
///
/// تنها چیزی که این کلاس از بیرون می‌خواهد، سه کارِ نمایشی است — [post]،
/// [changed]، [scrollToEnd] — تا خودش به لیستِ پیام‌های کنترلر دست نبرد.
class DraftFlow {
  DraftFlow({
    required this.engine,
    required this.repo,
    required this.advocate,
    required this.settings,
    required this.post,
    required this.changed,
    required this.scrollToEnd,
    required this.save,
    required this.isAlive,
  });

  final KnowledgeEngine engine;
  final TemplateRepository repo;
  final Advocate advocate;
  final AppSettings settings;

  /// پیام تازه به گفتگو اضافه می‌شود (بدون نوتیفای).
  final void Function(ChatMessage) post;

  /// صفحه باید دوباره رسم شود.
  final void Function() changed;

  /// صفحه به آخر گفتگو برود.
  final void Function() scrollToEnd;

  /// گفتگو در تاریخچه ذخیره شود.
  final void Function() save;

  /// صفحه هنوز زنده است؟
  final bool Function() isAlive;

  DraftSession? _draft;
  List<LegalTemplate> _pendingList = [];

  /// متن پیشنهادی برای فیلدی که الان پرسیده شده (خالی = پیشنهادی نیست).
  String _suggested = '';

  /// دکمه‌ای که متنِ پیشنهادیِ وکیل را برای فیلد جاری می‌پذیرد.
  static const String useSuggestion = 'همین متن پیشنهادی';

  DraftSession? get draft => _draft;
  bool get isDrafting => _draft != null;
  List<LegalTemplate> get pendingChoices => List.unmodifiable(_pendingList);

  /// گفتگوی تازه یا پروندهٔ تازه: فرم و فهرستِ انتخاب‌ها کنار می‌روند.
  void reset() {
    _draft = null;
    _pendingList = [];
    _suggested = '';
  }

  /// آیا این پیام درخواست نوشتن یک سند است؟ اگر بله، همان را شروع می‌کند
  /// (یا می‌پرسد کدام سند) و `true` برمی‌گرداند.
  bool handle(String text) {
    // لمس «تنظیم دادخواست …» یا «تنظیم لایحه …»: سندِ همین پرونده.
    final filing = advocate.filingFor(text);
    if (filing != null) {
      final t = templateFor(filing.template);
      if (t != null) {
        _pendingList = [];
        advocate.clearOffer();
        start(text, t);
        return true;
      }
    }
    // لمس دکمه‌ای که عنوان دقیق یک قالب است.
    final key = KnowledgeEngine.normalize(text).trim();
    for (final t in repo.templates) {
      if (KnowledgeEngine.normalize(t.title).trim() == key) {
        _pendingList = [];
        start(text, t);
        return true;
      }
    }
    // پاسخ به «کدام متن را می‌خواهید؟».
    if (_pendingList.isNotEmpty) {
      final list = _pendingList;
      _pendingList = [];
      // «نه» باید پیش از جست‌وجوی عنوان بررسی شود؛ وگرنه همین دو حرف درون
      // عنوان یک قالب («هزینه») پیدا می‌شود و سندی ناخواسته شروع می‌شود.
      if (text == DraftCmd.cancel || DraftWords.isNo(text)) {
        post(ChatMessage(text, true));
        post(ChatMessage('باشد، فعلاً متنی نمی‌نویسم. هر وقت خواستید بگویید.',
            false, chips: advocate.idleChips));
        save();
        changed();
        scrollToEnd();
        return true;
      }
      final picked = DraftIntent.pickChoice(text, list);
      if (picked != null) {
        start(text, picked);
        return true;
      }
    }
    if (!Advocate.wantsDraft(text)) return false;
    // «یک دادخواست مطالبهٔ وجه بنویس»: خودِ کاربر سند را نام برده است.
    final intent = DraftIntent.detect(text, repo.templates);
    final direct = intent.template;
    if (direct != null) {
      start(text, direct);
      return true;
    }
    // «برام بنویسش»: سندی که به پروندهٔ جاری می‌خورد.
    for (final id in advocate.draftIds) {
      final t = templateFor(id);
      if (t != null) {
        start(text, t);
        return true;
      }
    }
    if (intent.choices.isNotEmpty) {
      _pendingList = intent.choices;
      post(ChatMessage(text, true, sensitive: true));
      post(ChatMessage(
        DraftIntent.chooseText,
        false,
        sensitive: true,
        chips: [...intent.choices.map((t) => t.title), DraftCmd.cancel],
      ));
      changed();
      scrollToEnd();
      return true;
    }
    return false;
  }

  /// یک قدمِ فرم: پاسخ کاربر به پرسشِ فیلد جاری.
  void step(String text) {
    final s = _draft;
    if (s == null) return;
    var answer = text;
    if (text == useSuggestion) {
      // پذیرفتنِ متن پیشنهادی: همان متن به‌جای جواب می‌نشیند.
      final f = s.current;
      final v = _suggested.isNotEmpty
          ? _suggested
          : (f == null ? '' : (advocate.fillFor(s.template.id)[f.id] ?? ''));
      if (v.isNotEmpty) answer = v;
    }
    final r = _withCaseHelp(DraftStep.answer(s, answer), s);
    post(ChatMessage(answer, true, sensitive: true));
    post(_botFromReply(r, s.template));
    if (r.ended) _draft = null;
    syncCheckpoint();
    changed();
    scrollToEnd();
  }

  /// شروعِ سند از پیامِ کاربر.
  void start(String userText, LegalTemplate t) {
    final s = DraftSession(t);
    final r = _withCaseHelp(DraftStep.start(s), s);
    _draft = r.ended ? null : s;
    post(ChatMessage(userText, true, sensitive: true));
    post(_botFromReply(r, t));
    syncCheckpoint();
    changed();
    scrollToEnd();
  }

  /// ادامهٔ پیش‌نویسِ نیمه‌کاره (از گفتگوی قبلی یا از حافظهٔ رمزنگاری‌شده).
  void resume(DraftSession s) {
    _draft = s;
    post(_botFromReply(DraftStep.resumePrompt(s), s.template));
  }

  void syncCheckpoint() {
    if (!settings.saveDraftProgress || !isAlive()) return;
    final s = _draft;
    if (s == null || s.done) {
      unawaited(DraftCheckpointStore.clear());
    } else {
      unawaited(DraftCheckpointStore.save(s));
    }
  }

  /// ذخیرهٔ صریح وضعیت پیش‌نویس ناتمام به‌صورت رمزنگاری‌شده.
  Future<bool> saveCheckpoint() async {
    final s = _draft;
    if (s == null || s.done) {
      await DraftCheckpointStore.clear();
      return false;
    }
    return DraftCheckpointStore.save(s);
  }

  /// بازیابی پیش‌نویس ناتمام ذخیره‌شده و نمایش پرسش جاری در گفتگو.
  Future<bool> restoreCheckpoint() async {
    if (!isAlive()) return false;
    final restored = await DraftCheckpointStore.load(repo.templates);
    if (restored == null || !isAlive()) return false;
    _draft = restored;
    post(_botFromReply(DraftStep.resumePrompt(restored), restored.template));
    changed();
    scrollToEnd();
    return true;
  }

  /// قالب با همین شناسه (یا null).
  LegalTemplate? templateFor(String id) {
    for (final t in repo.templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// مبلغی که کاربر در گفتگو گفته، به‌عنوان دکمهٔ پیشنهادی برای فیلد مبلغِ
  /// سند. تنها منبعش پروندهٔ وکیل است (مبلغ‌ها آنجا به تومان‌اند و فیلدهای
  /// قالب به ریال).
  DraftReply _withAmountChip(DraftReply r, DraftSession s) {
    if (r.ended || r.isDocument) return r;
    final f = s.current;
    if (f == null || f.id != 'amount' || f.type != 'number') return r;
    if (s.values.containsKey(f.id)) return r;
    final toman = advocate.file.n('amount');
    if (toman == null || toman <= 0) return r;
    final v = PersianText.toFaDigits((toman * 10).toString());
    if (r.chips.contains(v)) return r;
    return DraftReply(r.text, chips: [v, ...r.chips], note: r.note);
  }

  /// پرسشِ فیلد را با آنچه از گفتگو می‌دانیم همراه می‌کند: گزینهٔ درست جلو
  /// می‌آید، عدد به‌صورت دکمه پیشنهاد می‌شود و برای فیلدهای متنی، متنِ
  /// پیشنهادیِ وکیل زیر پرسش می‌آید تا با یک لمس پذیرفته شود.
  DraftReply _withCaseHelp(DraftReply raw, DraftSession s) {
    _suggested = '';
    final r = _withAmountChip(raw, s);
    if (r.ended || r.isDocument || s.done || s.pickingEdit) return r;
    final f = s.current;
    if (f == null || s.values.containsKey(f.id)) return r;
    final v = (advocate.fillFor(s.template.id)[f.id] ?? '').trim();
    if (v.isEmpty) return r;
    switch (f.type) {
      case 'choice':
        if (!r.chips.contains(v) || r.chips.first == v) return r;
        return DraftReply(
          r.text,
          chips: [v, ...r.chips.where((c) => c != v)],
          note: r.note,
        );
      case 'number':
        final n = PersianText.toFaDigits(v);
        if (r.chips.contains(n)) return r;
        return DraftReply(r.text, chips: [n, ...r.chips], note: r.note);
      case 'text':
      case 'multiline':
        _suggested = v;
        return DraftReply(
          '${r.text}\n\nپیشنهاد من از روی گفتگویمان:\n«$v»',
          chips: [useSuggestion, ...r.chips],
          note: r.note,
        );
    }
    return r;
  }

  ChatMessage _botFromReply(DraftReply r, LegalTemplate t) {
    if (r.isDocument) {
      return ChatMessage(
        r.text,
        false,
        sensitive: true,
        isDoc: true,
        docTitle: t.title,
        docReviewed: t.reviewed,
        docReviewNote: t.reviewNote,
        note: r.note,
        laws: DraftLaws.lawTexts(engine, t),
        lawRefsTotal: t.lawRefs.length,
        chips: r.chips,
      );
    }
    return ChatMessage(r.text, false, sensitive: true, chips: r.chips);
  }
}

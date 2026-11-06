import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/domain/lawyer/lawyer_voice.dart';
import 'package:dastyar/domain/legal_counselor.dart';
import 'package:dastyar/domain/templates.dart';

/// نوع یک پیشنهاد (برای انتخاب نماد کنار دکمه).
enum SuggestionKind { question, template, counsel }

class InputSuggestion {
  final String text;
  final SuggestionKind kind;

  const InputSuggestion(this.text, this.kind);

  @override
  bool operator ==(Object other) =>
      other is InputSuggestion && other.text == text && other.kind == kind;

  @override
  int get hashCode => Object.hash(text, kind);

  @override
  String toString() => 'InputSuggestion($text, $kind)';
}

/// پیشنهادهای بالای کادر نوشتن، متناسب با موضوعی که کاربر در حال تایپ آن است
/// (مثل چت‌بات‌های امروزی). کاملاً آفلاین، بدون Random و قطعی است.
///
/// منبع پیشنهادها:
/// ۱. تکمیل متن: پرسش‌های آماده‌ای که با واژه‌های تایپ‌شده جور می‌شوند.
/// ۲. موضوع: راهنمای حقوقی مرتبط یا تشخیص نمادین موضوع → پرسش‌های رایج همان
///    موضوع.
/// ۳. قالب سند مرتبط (مثلاً «دادخواست مطالبهٔ وجه») و شروع مشاورهٔ گام‌به‌گام.
class InputSuggestions {
  InputSuggestions._();

  static const int maxItems = 4;

  /// پرسش‌های رایج هر موضوع. همه به راهنماهای موجود برنامه پاسخ داده می‌شوند.
  static const Map<String, List<String>> topicQuestions = {
    'cheque': [
      'چک برگشتی دارم؛ چه کار کنم؟',
      'مجازات صدور چک بی‌محل چیست؟',
      'چک تضمینی را می‌شود به اجرا گذاشت؟',
    ],
    'labor': [
      'کارفرما حقوقم را نداده؛ چه کنم؟',
      'بدون دلیل اخراج شدم؛ چه حقی دارم؟',
      'کارفرما بیمه‌ام را رد نکرده است',
    ],
    'lease': [
      'صاحبخانه ودیعه‌ام را پس نمی‌دهد',
      'مستأجر خانه را تخلیه نمی‌کند',
      'شرایط فسخ قرارداد اجاره چیست؟',
    ],
    'family': [
      'مهریه را چطور بگیرم؟',
      'همسرم نفقه نمی‌دهد',
      'حضانت فرزند بعد از طلاق با کیست؟',
      'طلاق توافقی چه مراحلی دارد؟',
    ],
    'fraud_cyber': [
      'از من کلاهبرداری اینترنتی شده',
      'مجازات کلاهبرداری چیست؟',
      'کسی امانتم را پس نمی‌دهد',
    ],
    'criminal_harm': [
      'کسی مرا تهدید کرده؛ چه کنم؟',
      'مجازات توهین و فحاشی چیست؟',
      'عکس خصوصی‌ام را منتشر کرده‌اند',
      'کتک خورده‌ام؛ چطور شکایت کنم؟',
    ],
    'litigation_defense': [
      'احضاریه برایم آمده؛ چه کنم؟',
      'مهلت تجدیدنظر چند روز است؟',
      'رأی غیابی علیه من صادر شده',
    ],
    'debt': [
      'کسی قرضم را پس نمی‌دهد',
      'توان پرداخت بدهی ندارم؛ اعسار چطور است؟',
      'سفته را چطور به اجرا بگذارم؟',
    ],
    'inheritance': [
      'ارث به چه کسانی می‌رسد؟',
      'ترکه چطور بین وراث تقسیم می‌شود؟',
    ],
    'accident': [
      'تصادف کرده‌ام؛ خسارت را چطور بگیرم؟',
      'دیه شکستن دست چقدر است؟',
    ],
    'consumer': [
      'جنس معیوب خریدم و پس نمی‌گیرند',
    ],
    'contract': [
      'شرایط فسخ قرارداد چیست؟',
    ],
  };

  /// موضوعِ هر راهنمای حقوقی (شناسهٔ راهنما → کلید [topicQuestions]).
  static const Map<String, String> guideTopic = {
    'cheque_guarantee': 'cheque',
    'cheque_issuer': 'cheque',
    'cheque_bounced': 'cheque',
    'dismissal': 'labor',
    'unpaid_wages': 'labor',
    'labor_insurance': 'labor',
    'deposit_return': 'lease',
    'eviction': 'lease',
    'mahrieh': 'family',
    'nafaqeh': 'family',
    'custody': 'family',
    'divorce': 'family',
    'tamkin': 'family',
    'inheritance': 'inheritance',
    'debt_claim': 'debt',
    'insolvency': 'debt',
    'contract_cancel': 'contract',
    'consumer': 'consumer',
    'fraud': 'fraud_cyber',
    'trust_breach': 'fraud_cyber',
    'private_media': 'criminal_harm',
    'insult_threat': 'criminal_harm',
    'defamation': 'criminal_harm',
    'assault': 'criminal_harm',
    'diyeh': 'accident',
    'accident': 'accident',
    'appeal': 'litigation_defense',
    'summons': 'litigation_defense',
    'legal_aid': 'litigation_defense',
  };

  static List<String> get _corpus => [
        for (final qs in topicQuestions.values) ...qs,
      ];

  static String _norm(String s) =>
      PersianText.normalize(s).replaceAll(RegExp(r'[؟?!،,.؛:]'), ' ').trim();

  static List<String> _words(String s) =>
      _norm(s).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  /// آیا هر واژهٔ تایپ‌شده، آغاز یکی از واژه‌های پرسش است؟
  static bool _completes(List<String> typed, String candidate) {
    if (typed.isEmpty) return false;
    final cw = _words(candidate);
    for (final t in typed) {
      if (!cw.any((w) => w.startsWith(t))) return false;
    }
    return true;
  }

  /// موضوع پیام در حال تایپ، یا `null`.
  static String? topicOf(String text) {
    final g = LawyerVoice.matchGuide(text);
    if (g != null) {
      final t = guideTopic[g.id];
      if (t != null) return t;
    }
    final d = LegalCounselor.detectTopic(text);
    if (d == null || d == 'general_intake') return null;
    return topicQuestions.containsKey(d) ? d : null;
  }

  /// پیشنهادها برای متنی که کاربر در حال نوشتن آن است.
  static List<InputSuggestion> forTyping(
    String text, {
    List<LegalTemplate> templates = const [],
  }) {
    final raw = text.trim();
    final typed = _words(raw);
    if (typed.isEmpty || _norm(raw).length < 2) return const [];
    final typedNorm = _norm(raw);

    final out = <InputSuggestion>[];
    final seen = <String>{};
    void add(String s, SuggestionKind k) {
      if (out.length >= maxItems) return;
      final key = _norm(s);
      if (key.isEmpty || key == typedNorm || !seen.add(key)) return;
      out.add(InputSuggestion(s, k));
    }

    // ۱. تکمیل متن (آن‌هایی که با متن تایپ‌شده شروع می‌شوند، اول).
    final completions = _corpus.where((q) => _completes(typed, q)).toList()
      ..sort((a, b) {
        final sa = _norm(a).startsWith(typedNorm) ? 0 : 1;
        final sb = _norm(b).startsWith(typedNorm) ? 0 : 1;
        return sa.compareTo(sb);
      });
    final reserve = topicOf(raw) == null ? 0 : 2;
    for (final q in completions.take(maxItems - reserve)) {
      add(q, SuggestionKind.question);
    }

    // ۲. پرسش‌های رایج همان موضوع.
    final topic = topicOf(raw);
    if (topic != null) {
      for (final q in topicQuestions[topic]!) {
        if (out.length >= maxItems - reserve) break;
        add(q, SuggestionKind.question);
      }
    }

    // ۳. قالب سند مرتبط و مشاورهٔ گام‌به‌گام.
    final tplTitles = <String>[];
    final g = LawyerVoice.matchGuide(raw);
    if (g != null && templates.isNotEmpty) {
      tplTitles.addAll(LawyerVoice.templateChips(g, templates));
    }
    if (tplTitles.isEmpty && templates.isNotEmpty) {
      final sug = Drafting.suggest(raw, templates);
      final t = sug.template;
      if (t != null) {
        tplTitles.add(t.title);
      } else {
        tplTitles.addAll(sug.choices.map((c) => c.title));
      }
    }
    if (tplTitles.isNotEmpty) add(tplTitles.first, SuggestionKind.template);
    if (topic != null) {
      add(LegalCounselor.startCounselCmd, SuggestionKind.counsel);
    }
    return out;
  }
}

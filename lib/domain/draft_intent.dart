import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/draft_models.dart';
import 'package:dastyar/domain/draft_words.dart';
import 'package:dastyar/domain/templates.dart';

/// تشخیصِ «کاربر چه متنی می‌خواهد» و کدام قالب به حرفش می‌خورد.
///
/// این تنها جایی است که حرفِ کاربر با واژه‌های کلیدیِ قالب مقایسه می‌شود؛
/// `pickChoice` هم همین‌جا است چون انتخاب از فهرست، همان امتیازدهی است با یک
/// گام اضافه (شمارهٔ گزینه، عنوانِ دقیق).
class DraftIntent {
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

  static final RegExp _choiceIdxRe =
      RegExp(r'^(?:گزینه|مورد|شماره)?\s*(\d+)\s*$');
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
    final n = DraftWords.norm(text);
    final words = n.split(' ');
    for (final k in t.keywords) {
      if (!k.startsWith('-')) continue;
      final kn = DraftWords.norm(k.substring(1));
      if (kn.isNotEmpty && _kwHit(kn, n, words)) return 0;
    }
    var s = 0;
    for (final k in t.keywords) {
      if (k.startsWith('-')) continue;
      final kn = DraftWords.norm(k);
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

  /// «بنویس/بنویسید/بنویسش» که به دستیار گفته شده، نه «بنویسم» که کاربر از
  /// خودش می‌گوید («چک را در وجه حامل بنویسم»).
  static final RegExp _writeCmdRe = RegExp(r'بنویس(?:ش|ید|ی)?(?![\u0600-\u06FF])');

  static bool _has(String n, String w) =>
      w == 'بنویس' ? _writeCmdRe.hasMatch(n) : n.contains(w);

  static bool _wantsDraft(String n) {
    final asks = _questionWords.any((w) => n.contains(w));
    if (asks && !_imperatives.any((w) => _has(n, w))) return false;
    if (_verbs.any((w) => _has(n, w))) return true;
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

  /// انتخاب یک قالب از فهرست گزینه‌های پیشنهادی بر اساس پاسخ کاربر
  /// (عنوان دقیق، شمارهٔ گزینه، زیررشتهٔ یکتا در عنوان، یا امتیاز واژگانی).
  /// اگر پیام کاربر پرسش اطلاعاتی باشد، null برمی‌گرداند تا به موتور پاسخ داده شود.
  static LegalTemplate? pickChoice(String raw, List<LegalTemplate> choices) {
    if (choices.isEmpty) return null;
    final n = KnowledgeEngine.normalize(raw).trim();
    if (n.isEmpty) return null;

    for (final t in choices) {
      if (KnowledgeEngine.normalize(t.title).trim() == n) return t;
    }

    final asks = _questionWords.any((w) => n.contains(w));
    if (asks && !_imperatives.any((w) => n.contains(w))) return null;

    final idxMatch = _choiceIdxRe.firstMatch(n);
    final idxGroup = idxMatch?.group(1);
    if (idxGroup != null) {
      final idx = int.tryParse(idxGroup);
      if (idx != null && idx >= 1 && idx <= choices.length) {
        return choices[idx - 1];
      }
    }

    final folded = DraftWords.fold(raw);
    if (folded.length >= 2) {
      final exactFold =
          choices.where((t) => DraftWords.fold(t.title) == folded).toList();
      if (exactFold.length == 1) return exactFold.first;

      final sub = choices.where((t) {
        final tf = DraftWords.fold(t.title);
        return tf.contains(folded) || folded.contains(tf);
      }).toList();
      if (sub.length == 1) return sub.first;
    }

    if (folded.split(' ').length <= 6) {
      final tokens = KnowledgeEngine.tokenize(raw).toSet();
      var best = 0;
      final scores = <LegalTemplate, int>{};
      for (final t in choices) {
        final tt = _titleTokens(t);
        final s =
            tokens.where(tt.contains).length + 2 * keywordScore(raw, t);
        scores[t] = s;
        if (s > best) best = s;
      }
      if (best > 0) {
        final top = choices.where((t) => scores[t] == best).toList();
        if (top.length == 1) return top.first;
      }
    }

    return null;
  }
}

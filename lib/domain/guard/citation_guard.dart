import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/models.dart';
import 'package:dastyar/core/persian_text.dart';

/// گارد اعتبارسنجی استناد در پاسخ‌های LLM.
///
/// این کلاس وظیفهٔ تشخیص «ماده‌های ساختگی» یا «قانون‌های ناموجود» را
/// بر عهده دارد. Assistant هنگام استریم توکن‌های مدل، پیش از هر
/// `yield`، خروجی را با این کلاس بررسی می‌کند.
class CitationGuard {
  final List<CatalogLaw> _catalog;

  CitationGuard({List<CatalogLaw> catalog = const []}) : _catalog = catalog;

  static final RegExp _singleArtRe = RegExp(
    r'(?:ماده|اصل)(?:\s+(واحده)|\s*(\d+(?:\s+مکرر(?:\s+\d{1,2})?)?))',
  );

  static final RegExp _pluralArtRe = RegExp(
    r'(?:مواد|اصول)\s+((?:\d+(?:\s+مکرر(?:\s+\d{1,2})?)?)(?:\s*(?:،|,|و|یا|تا|الی|-)\s*(?:\d+(?:\s+مکرر(?:\s+\d{1,2})?)?))*)',
  );

  static final RegExp _artNumTokenRe = RegExp(
    r'\d+(?:\s+مکرر(?:\s+\d{1,2})?)?',
  );

  /// شماره‌های مادهٔ ذکرشده در یک متن.
  static Set<String> citedArticles(String text) {
    final n = PersianText.collapse(PersianText.normalize(text));
    final out = <String>{};
    for (final m in _singleArtRe.allMatches(n)) {
      final raw = m.group(1) ?? m.group(2)!;
      out.add(PersianText.collapse(raw));
    }
    for (final pm in _pluralArtRe.allMatches(n)) {
      final listPart = pm.group(1)!;
      for (final tm in _artNumTokenRe.allMatches(listPart)) {
        out.add(PersianText.collapse(tm.group(0)!));
      }
    }
    return out;
  }

  /// بررسی سریع: فقط شماره‌های ماده در `ctx` مجاز هستند.
  static bool isGrounded(String answer, List<Hit> ctx) {
    final cited = citedArticles(answer);
    if (cited.isEmpty) return true;
    final allowed = _allowedArticles(ctx);
    return cited.every(allowed.contains);
  }

  static Set<String> _allowedArticles(List<Hit> ctx) {
    final allowed = <String>{};
    for (final h in ctx) {
      allowed.addAll(citedArticles(h.chunk.title));
      allowed.addAll(citedArticles(h.chunk.body));
    }
    return allowed;
  }

  static bool _isFormalStatuteName(String normName) {
    return normName.startsWith('قانون ') ||
        normName.startsWith('لایحه ') ||
        normName.startsWith('آیین دادرسی');
  }

  /// بررسی جامع استناد به مواد و نام‌های قوانین.
  bool isAnswerGrounded(String answer, List<Hit> ctx) {
    if (!isGrounded(answer, ctx)) return false;
    if (_catalog.isEmpty || ctx.isEmpty) return true;

    final ctxLawIds = <String>{
      for (final h in ctx)
        if (h.chunk.lawId.isNotEmpty) h.chunk.lawId,
    };
    final ctxNormText = ctx
        .map(
          (h) =>
              '${h.chunk.normSource} ${PersianText.collapse(PersianText.normalize(h.chunk.body))}',
        )
        .join(' \n ');

    final candidates = <({String lawId, String phrase})>[];
    for (final law in _catalog) {
      for (final raw in [law.title, ...law.aliases]) {
        final phrase = PersianText.collapse(PersianText.normalize(raw));
        if (phrase.isNotEmpty && _isFormalStatuteName(phrase)) {
          candidates.add((lawId: law.id, phrase: phrase));
        }
      }
    }
    candidates.sort((a, b) => b.phrase.length.compareTo(a.phrase.length));

    var remaining = PersianText.collapse(PersianText.normalize(answer));
    for (final c in candidates) {
      if (!remaining.contains(c.phrase)) continue;
      remaining = remaining.replaceAll(c.phrase, ' ');
      if (ctxLawIds.contains(c.lawId)) continue;
      if (ctxNormText.contains(c.phrase)) continue;
      return false;
    }
    return true;
  }

  static bool _isInvalidCompletedCite(
    String cite,
    String tailAfterMatch,
    Set<String> allowed,
  ) {
    if (allowed.contains(cite)) return false;
    final prefix = '$cite ';
    final suffixes = allowed
        .where((a) => a.startsWith(prefix))
        .map((a) => a.substring(prefix.length))
        .toList();
    if (suffixes.isEmpty) return true;
    final tail = PersianText.collapse(tailAfterMatch);
    if (tail.isEmpty) return false;
    return !suffixes.any((s) => s.startsWith(tail));
  }

  static bool _hasInvalidStreamingCitation(String rawAcc, Set<String> allowed) {
    final n = PersianText.normalize(rawAcc);
    for (final m in _singleArtRe.allMatches(n)) {
      if (m.end == n.length) continue;
      final raw = m.group(1) ?? m.group(2)!;
      final cite = PersianText.collapse(raw);
      if (_isInvalidCompletedCite(cite, n.substring(m.end), allowed)) {
        return true;
      }
    }
    for (final pm in _pluralArtRe.allMatches(n)) {
      final listPart = pm.group(1)!;
      final listStart = pm.end - listPart.length;
      for (final tm in _artNumTokenRe.allMatches(listPart)) {
        final absEnd = listStart + tm.end;
        if (absEnd == n.length) continue;
        final cite = PersianText.collapse(tm.group(0)!);
        if (_isInvalidCompletedCite(cite, n.substring(absEnd), allowed)) {
          return true;
        }
      }
    }
    return false;
  }

  /// بررسی استریم در حال نوشتن.
  static bool checkStreaming(String acc, Set<String> allowed) {
    return _hasInvalidStreamingCitation(acc, allowed);
  }

  /// استخراج مجموعهٔ مجازِ ماده‌ها از `ctx`.
  static Set<String> allowedArticles(List<Hit> ctx) {
    return _allowedArticles(ctx);
  }
}

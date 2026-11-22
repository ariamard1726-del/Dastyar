/// مسیر تصمیم موضوعی بدون مدل (همتای tools/topic_flow.py).
///
/// هر پرسش با زیررشته‌های نرمال‌شده به یک برگ تصمیم می‌رسد؛ اگر هیچ قاعده‌ای
/// نخورد، برگ `ask` برمی‌گردد. ترتیب قاعده‌ها در فایل JSON مهم است.
class TopicFlow {
  TopicFlow._();

  static final RegExp _punct = RegExp(r'[،,.;:!?؟()\[\]«»"\-/]+');
  static final RegExp _chequeWord = RegExp(r' چک[\u0600-\u06FF]* ');
  static final RegExp _diacritics = RegExp('[\u064B-\u065F\u0670]');

  /// نرمال‌سازی همان قاعدهٔ پایتون: یکسان‌سازی نویسه‌ها و فاصله‌دار کردن.
  static String spaced(String s) {
    var t = s
        .replaceAll(_diacritics, '')
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('\u200c', ' ')
        .replaceAll('ۀ', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('أ', 'ا')
        .replaceAll('ء', '');
    t = t.replaceAll(_punct, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return ' $t ';
  }

  /// پیشوندِ واژه: «برگشتی» و «برگشت» هر دو با «برگشت» تطبیق می‌یابند.
  static String _prefix(String w) => ' ${spaced(w).trim()}';

  /// آیا پیام دربارهٔ چک است (چک، چکم، چکی، چکش، ...)؟
  static bool mentionsCheque(String q) => _chequeWord.hasMatch(spaced(q));

  /// شناسهٔ برگ تصمیم برای پرسش؛ `ask` وقتی هیچ قاعده‌ای نخورد.
  static String route(Map<String, dynamic> flow, String q) {
    final text = spaced(q);
    final rules = flow['rules'];
    if (rules is! List) return 'ask';
    for (final r in rules.cast<Map<String, dynamic>>()) {
      final any = r['any'];
      if (any is List && any.cast<String>().any((w) => text.contains(_prefix(w)))) {
        return r['leaf'] as String;
      }
      final groups = r['all_groups'];
      if (groups is List &&
          groups.isNotEmpty &&
          groups.cast<List>().every((g) => g.cast<String>().any((w) => text.contains(_prefix(w))))) {
        return r['leaf'] as String;
      }
    }
    return 'ask';
  }
}

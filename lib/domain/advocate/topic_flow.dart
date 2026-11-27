import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/core/text_norm_rules.dart';

/// مسیر تصمیم موضوعی بدون مدل (همتای dev/tools/topic_flow.py).
///
/// هر پرسش با زیررشته‌های نرمال‌شده به یک برگ تصمیم می‌رسد؛ اگر هیچ قاعده‌ای
/// نخورد، برگ `ask` برمی‌گردد. ترتیب قاعده‌ها در فایل JSON مهم است.
class TopicFlow {
  TopicFlow._();

  static final RegExp _punct = RegExp(TextNormRules.spacedToolsPunct);
  static final RegExp _chequeWord = RegExp(r' چک[\u0600-\u06FF]* ');

  /// نرمال‌سازی از قرارداد `dev/tools/contracts/text_norm.json` (`spaced.tools`).
  static String spaced(String s) => PersianText.spacedWith(
        s,
        charMap: TextNormRules.spacedToolsMap,
        dropRanges: TextNormRules.spacedToolsDropRanges,
        punct: _punct,
        pad: TextNormRules.spacedToolsPad,
      );

  /// پیشوندِ واژه: «برگشتی» و «برگشت» هر دو با «برگشت» تطبیق می‌یابند.
  static String _prefix(String w) => ' ${spaced(w).trim()}';

  /// آیا پیام دربارهٔ چک است (چک، چکم، چکی، چکش، ...)؟
  static bool mentionsCheque(String q) => _chequeWord.hasMatch(spaced(q));

  /// شناسهٔ برگ تصمیم برای پرسش؛ `ask` وقتی هیچ قاعده‌ای نخورد.
  static String route(Map<String, dynamic> flow, String q) {
    final text = spaced(q);
    final gate = flow['gate'];
    if (gate is List && gate.isNotEmpty &&
        !gate.cast<String>().any((w) => text.contains(_prefix(w)))) {
      return 'ask';
    }
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

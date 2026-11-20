/// سرویس مدیریت زنجیرهٔ تضادها و ارجاعات متقابل مواد قانونی.
/// داده‌ها (relationships.json) را موتور می‌خواند و به این سرویس می‌دهد.
class ConflictsService {
  /// زنجیرهٔ تضادها را از یک ماده به‌صورت بازگشتی برمی‌گرداند.
  /// - با محافظت در برابر حلقه (cycle) با پارامتر [path]
  /// - با سقف عمق پیمایش [maxDepth] برای جلوگیری از سرریز پشته
  /// - با اعتبارسنجی نوع داده‌ها (null/type safety)
  List<String> getConflictsChain(
    String articleId,
    Map<String, dynamic> data, {
    List<String>? path,
    int maxDepth = 32,
  }) {
    final currentPath = path ?? <String>[articleId];
    if (currentPath.length > maxDepth) return const [];

    final articles = data['articles'];
    if (articles is! Map<String, dynamic>) return const [];

    final currentArticle = articles[articleId];
    if (currentArticle is! Map<String, dynamic>) return const [];

    final rawConflicts = currentArticle['conflicts_with'];
    if (rawConflicts is! List) return const [];

    final conflicts = rawConflicts.map((e) => e.toString()).toList();
    final results = <String>[];

    for (final conflictId in conflicts) {
      if (currentPath.contains(conflictId)) {
        results.add('${currentPath.join(' -> ')} -> $conflictId ⚠️ (حلقه)');
        continue;
      }

      final newPath = <String>[...currentPath, conflictId];
      results.add(newPath.join(' -> '));

      if (newPath.length < maxDepth) {
        final subConflicts = getConflictsChain(
          conflictId,
          data,
          path: newPath,
          maxDepth: maxDepth,
        );
        results.addAll(subConflicts);
      }
    }

    return results;
  }

  /// گرفتن عنوان یک ماده (برای نمایش زیبا در UI).
  String? getTitle(String articleId, Map<String, dynamic> data) {
    final articles = data['articles'];
    if (articles is! Map<String, dynamic>) return null;
    final article = articles[articleId];
    if (article is! Map<String, dynamic>) return null;
    return article['title']?.toString();
  }
}

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// سرویس مدیریت زنجیره تضادهای مواد قانونی.
class ConflictsService {
  /// کش داده‌ها برای جلوگیری از خواندن مکرر فایل.
  Map<String, dynamic>? _cache;

  /// خواندن relationships.json از assets و کش کردن.
  Future<Map<String, dynamic>> loadData() async {
    if (_cache != null) return _cache!;
    final String raw = await rootBundle.loadString('assets/relationships.json');
    _cache = json.decode(raw) as Map<String, dynamic>;
    return _cache!;
  }

  /// زنجیره تضادها را از یک ماده به صورت بازگشتی برمی‌گرداند.
  /// - با محافظت در برابر حلقه (cycle) با پارامتر [path]
  /// - با اعتبارسنجی نوع داده‌ها (null/type safety)
  List<String> getConflictsChain(
    String articleId,
    Map<String, dynamic> data, {
    List<String>? path,
  }) {
    path ??= [articleId];

    final articles = data['articles'];
    if (articles is! Map<String, dynamic>) return [];

    final currentArticle = articles[articleId];
    if (currentArticle is! Map<String, dynamic>) return [];

    final rawConflicts = currentArticle['conflicts_with'];
    if (rawConflicts is! List) return [];

    final conflicts = rawConflicts.map((e) => e.toString()).toList();
    final results = <String>[];

    for (final conflictId in conflicts) {
      // محافظت در برابر حلقه
      if (path.contains(conflictId)) {
        results.add('${path.join(' -> ')} -> $conflictId ⚠️ (حلقه)');
        continue;
      }

      final newPath = [...path, conflictId];
      results.add(newPath.join(' -> '));

      // فراخوانی بازگشتی با مسیر جدید
      final subConflicts = getConflictsChain(
        conflictId,
        data,
        path: newPath,
      );
      results.addAll(subConflicts);
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

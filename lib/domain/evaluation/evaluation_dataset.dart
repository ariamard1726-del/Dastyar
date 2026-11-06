import 'dart:convert';

import 'package:dastyar/core/persian_text.dart';

/// یک مادهٔ قانونیِ انتظاررفته در پاسخ درست.
///
/// article همیشه به شکل canonical ذخیره می‌شود (ماده 3 با ارقام ASCII) تا
/// با Chunk.title موتور دانش دقیقاً قابل مقایسه باشد.
class ExpectedArticle {
  final String lawId;
  final String article;

  const ExpectedArticle({required this.lawId, required this.article});

  factory ExpectedArticle.fromJson(Map<String, dynamic> json) {
    final law = json['law'] ?? json['law_id'] ?? json['lawId'];
    final article = json['article'] ?? json['article_title'] ?? '';
    return ExpectedArticle(
      lawId: (law ?? '').toString().trim(),
      article: canonicalArticle(article.toString()),
    );
  }

  /// بخش شماره‌ایِ ماده، همان‌طور که CitationGuard.citedArticles برمی‌گرداند.
  String get citationKey =>
      canonicalArticle(article).replaceFirst('ماده ', '');

  /// یکدست‌سازی عنوان ماده، هم‌رفتار با KnowledgeEngine.findArticle.
  static String canonicalArticle(String raw) {
    var a = PersianText.collapse(PersianText.normalize(raw));
    if (a.isEmpty) return '';
    if (!a.startsWith('ماده ') && !a.startsWith('اصل ')) a = 'ماده $a';
    return PersianText.collapse(a);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'law': lawId,
        'article': article,
      };

  @override
  String toString() => '$lawId/$article';
}

/// چگونگی ورود پیام کاربر به خط لوله.
enum ScenarioEntry {
  /// کاربر در یک گفتگوی تازه پرسش حقوقی می‌پرسد (مسیر RAG/گفتگوی کوتاه).
  question,

  /// کاربر موضوعی شخصی را مطرح می‌کند و مشاورهٔ گام‌به‌گام آغاز می‌شود.
  counseling,
}

/// یک سناریوی طلاییِ ارزیابی: پرسش واقعی + انتظار حقوقی.
class EvaluationScenario {
  final String id;
  final String query;
  final ScenarioEntry entry;

  /// دامنهٔ حقوقیِ انتظاررفته (cheque، labor، ...)؛ null یعنی سنجیده نشود.
  final String? expectedTopic;

  /// مسیر انتظاررفتهٔ LegalCounselor.step (نامِ CounselorRoute؛ مثل rag).
  final String? expectedRoute;

  /// مواد قانونیِ درست برای این پرسش (ممکن است بیش از یکی باشد).
  final List<ExpectedArticle> expectedArticles;

  /// پاسخ نباید هیچ استناد قانونی داشته باشد (پرسش غیرحقوقی/خارج از دانش).
  final bool expectsNoCitation;

  /// بانک قوانین باید صریحاً بگوید «پیدا نکردم» و پاسخ نسازد.
  final bool expectsRagMiss;

  /// پاسخ‌های بعدیِ کاربر برای ادامهٔ گفتگو (اختیاری).
  final List<String> followUps;

  final List<String> tags;
  final String? note;

  const EvaluationScenario({
    required this.id,
    required this.query,
    this.entry = ScenarioEntry.question,
    this.expectedTopic,
    this.expectedRoute,
    this.expectedArticles = const <ExpectedArticle>[],
    this.expectsNoCitation = false,
    this.expectsRagMiss = false,
    this.followUps = const <String>[],
    this.tags = const <String>[],
    this.note,
  });

  factory EvaluationScenario.fromJson(Map<String, dynamic> json) {
    final expected = (json['expected'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final rawArticles = expected['articles'];
    final articles = <ExpectedArticle>[];
    if (rawArticles is List) {
      for (final item in rawArticles) {
        if (item is Map) {
          articles.add(ExpectedArticle.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    final rawFollow = json['follow_ups'];
    return EvaluationScenario(
      id: (json['id'] ?? '').toString(),
      query: (json['query'] ?? '').toString(),
      entry: ScenarioEntry.values.firstWhere(
        (e) => e.name == (json['entry'] ?? 'question').toString(),
        orElse: () => ScenarioEntry.question,
      ),
      expectedTopic: expected['topic']?.toString(),
      expectedRoute: expected['route']?.toString(),
      expectedArticles: List<ExpectedArticle>.unmodifiable(articles),
      expectsNoCitation: expected['no_citation'] == true,
      expectsRagMiss: expected['rag_miss'] == true,
      followUps: rawFollow is List
          ? List<String>.unmodifiable(rawFollow.map((e) => e.toString()))
          : const <String>[],
      tags: (json['tags'] is List)
          ? List<String>.unmodifiable(
              (json['tags'] as List).map((e) => e.toString()))
          : const <String>[],
      note: json['note']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'query': query,
        'entry': entry.name,
        'expected': <String, dynamic>{
          if (expectedTopic != null) 'topic': expectedTopic,
          if (expectedRoute != null) 'route': expectedRoute,
          'articles': expectedArticles.map((a) => a.toJson()).toList(),
          if (expectsNoCitation) 'no_citation': true,
          if (expectsRagMiss) 'rag_miss': true,
        },
        if (followUps.isNotEmpty) 'follow_ups': followUps,
        if (tags.isNotEmpty) 'tags': tags,
        if (note != null) 'note': note,
      };
}

/// مجموعهٔ سناریوهای طلایی، خوانده‌شده از evaluation_dataset.json.
class EvaluationDataset {
  final List<EvaluationScenario> scenarios;
  final String version;
  final String? description;

  const EvaluationDataset({
    required this.scenarios,
    this.version = '1',
    this.description,
  });

  static const String defaultPath = 'brain/eval/evaluation_dataset.json';

  /// شناسه‌های مسیرهای مجاز؛ با CounselorRoute هم‌خوان است.
  ///
  /// counseling عضو CounselorRoute نیست: این مسیر از LegalCounselor.start
  /// می‌آید؛ یعنی پیام کاربر موضوعی شخصی بوده و مشاورهٔ گام‌به‌گام آغاز شده
  /// است (نه یک گامِ داخلِ step).
  static const Set<String> knownRoutes = <String>{
    'empty',
    'cancel',
    'template',
    'goodbye',
    'smallTalk',
    'rag',
    'intake',
    'domain',
    'counseling',
  };

  factory EvaluationDataset.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('ریشهٔ دیتاست باید یک شیء JSON باشد');
    }
    return EvaluationDataset.fromJson(decoded.cast<String, dynamic>());
  }

  factory EvaluationDataset.fromJson(Map<String, dynamic> json) {
    final raw = json['scenarios'];
    if (raw is! List) {
      throw const FormatException('کلید scenarios باید فهرست باشد');
    }
    final out = <EvaluationScenario>[];
    for (final item in raw) {
      if (item is! Map) continue;
      out.add(EvaluationScenario.fromJson(item.cast<String, dynamic>()));
    }
    return EvaluationDataset(
      scenarios: List<EvaluationScenario>.unmodifiable(out),
      version: (json['version'] ?? '1').toString(),
      description: json['description']?.toString(),
    );
  }

  int get length => scenarios.length;
  bool get isEmpty => scenarios.isEmpty;

  Iterable<EvaluationScenario> byTag(String tag) =>
      scenarios.where((s) => s.tags.contains(tag));

  /// بررسی سلامتِ داده‌ها پیش از هر ارزیابی.
  ///
  /// * شناسهٔ تکراری، پرسش خالی، مسیر ناشناخته و سناریوی بی‌انتظار خطا هستند.
  /// * اگر [knownLawIds] داده شود، هر مادهٔ انتظاررفته باید در بستهٔ قوانین
  /// وجود داشته باشد؛ این کار «توهمِ دیتاست» را هم می‌گیرد.
  List<String> validate({Set<String>? knownLawIds}) {
    final problems = <String>[];
    final ids = <String>{};
    for (final s in scenarios) {
      if (s.id.trim().isEmpty) {
        problems.add('سناریو بدون شناسه: «${s.query}»');
      } else if (!ids.add(s.id)) {
        problems.add('شناسهٔ تکراری: ${s.id}');
      }
      if (s.query.trim().isEmpty) {
        problems.add('${s.id}: پرسش خالی است');
      }
      final route = s.expectedRoute;
      if (route != null && !knownRoutes.contains(route)) {
        problems.add('${s.id}: مسیر ناشناخته «$route»');
      }
      if (s.expectedTopic != null && s.entry != ScenarioEntry.counseling) {
        problems.add(
            '${s.id}: انتظارِ موضوع فقط با entry=counseling معنا دارد');
      }
      if (s.expectsNoCitation && s.expectedArticles.isNotEmpty) {
        problems.add(
            '${s.id}: نمی‌تواند هم مادهٔ انتظاررفته داشته باشد هم no_citation');
      }
      final measurable = s.expectedArticles.isNotEmpty ||
          s.expectedTopic != null ||
          s.expectedRoute != null ||
          s.expectsNoCitation ||
          s.expectsRagMiss;
      if (!measurable) {
        problems.add('${s.id}: هیچ انتظار قابل‌سنجشی ندارد');
      }
      for (final a in s.expectedArticles) {
        if (a.lawId.isEmpty) problems.add('${s.id}: مادهٔ بدون نام قانون');
        if (a.article.isEmpty) problems.add('${s.id}: مادهٔ بدون شماره');
        if (knownLawIds != null && !knownLawIds.contains(a.lawId)) {
          problems.add('${s.id}: قانون ناشناخته «${a.lawId}»');
        }
      }
    }
    return problems;
  }
}
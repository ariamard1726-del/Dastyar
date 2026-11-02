import 'package:dastyar/core/engine.dart';

class AssistantTurn {
  final String text;
  final List<String> alternatives;
  final List<String> conflictChains;

  const AssistantTurn({
    required this.text,
    this.alternatives = const [],
    this.conflictChains = const [],
  });
}

/// هماهنگ‌کنندهٔ قطعی پاسخ: فقط از موتور بازیابی متن قوانین استفاده می‌کند.
///
/// لایهٔ مدل زبانی (llm.dart / بک‌اندهای محلی / کانال بومی) به‌طور کامل حذف
/// شده است؛ پاسخ هرگز تولید آزاد، استریم یا راستی‌آزمایی مدل ندارد و دقیقاً
/// همان خروجی [KnowledgeEngine.query] است.
class Assistant {
  final KnowledgeEngine engine;

  Assistant(this.engine);

  /// پاسخ نهایی به‌همراه پیشنهادهای نزدیک و زنجیرهٔ تعارض، در یک نوبت.
  /// نگه داشتن رابطِ جریانی برای سازگاری با کنترلر گفتگو است؛ فقط یک رویداد می‌دهد.
  Stream<AssistantTurn> askWithAlternatives(
    String question, {
    int maxAlternatives = 3,
  }) async* {
    final reply = engine.query(question, maxAlternatives: maxAlternatives);
    yield AssistantTurn(
      text: reply.text,
      alternatives: reply.alternatives,
      conflictChains: reply.conflictChains,
    );
  }

  /// متن پاسخ قطعی (بدون هیچ تولید مدلی).
  Stream<String> ask(String question) =>
      askWithAlternatives(question, maxAlternatives: 0).map((t) => t.text);
}

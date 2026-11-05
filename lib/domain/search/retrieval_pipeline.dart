import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/dialogue/evidence.dart';

/// لایهٔ نازک روی `KnowledgeEngine` که بازیابی را از orchestration
/// (Assistant) جدا می‌کند.
///
/// چرا این کلاس وجود دارد؟
///   • `Assistant` نباید بداند که بازیابی از `engine.query` استفاده
///     می‌کند یا فردا از `retrieveWithEvidence` یا هر روش دیگر.
///   • در آینده می‌توان retrieval را با cache یا backend دیگر عوض کرد
///     بدون دست زدن به Assistant.
///   • تست `Assistant` با mock کردن این کلاس ساده‌تر می‌شود.
class RetrievalPipeline {
  final KnowledgeEngine _engine;

  RetrievalPipeline(this._engine);

  /// بازیابی پاسخ موتور با پیشنهادهای نزدیک.
  EngineReply retrieve(String question, {int maxAlternatives = 3}) {
    return _engine.query(question, maxAlternatives: maxAlternatives);
  }

  /// بازیابی ساخت‌یافته (EvidenceSet) برای planner در Phase 2.
  EvidenceSet retrieveWithEvidence(String question, {int k = 3}) {
    return _engine.retrieveWithEvidence(question, k: k);
  }
}

import 'dart:math';
import 'package:flutter/services.dart';
import 'package:mobile_rag_engine/mobile_rag_engine.dart';

class AIService {
  late EmbeddingService _embeddingService;
  List<List<double>> _knowledgeEmbeddings = [];
  List<String> _knowledgeSentences = [];

  Future<void> initialize() async {
    // 1. مقداردهی اولیه سرویس Embedding
    _embeddingService = EmbeddingService();

    final modelBytes = await rootBundle.load('assets/model_int8.onnx');
    await _embeddingService.init(modelBytes.buffer.asUint8List());

    // 2. بارگذاری دانش محلی
    final knowledgeText = await rootBundle.loadString('assets/knowledge.txt');
    _knowledgeSentences = knowledgeText
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    // 3. تبدیل تمام جملات به بردار (فقط یکبار در شروع)
    for (String sentence in _knowledgeSentences) {
      _knowledgeEmbeddings.add(await _getEmbedding(sentence));
    }
  }

  Future<List<double>> _getEmbedding(String text) async {
    // این پکیج توکنایز و اجرای مدل را خودکار انجام می‌دهد
    return await _embeddingService.embed(text);
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return dot / (sqrt(normA) * sqrt(normB));
  }

  Future<String> getResponse(String userText) async {
    List<double> userEmb = await _getEmbedding(userText);
    double maxScore = -1;
    int bestIdx = -1;

    for (int i = 0; i < _knowledgeEmbeddings.length; i++) {
      double score = _cosineSimilarity(userEmb, _knowledgeEmbeddings[i]);
      if (score > maxScore) {
        maxScore = score;
        bestIdx = i;
      }
    }

    if (maxScore > 0.5 && bestIdx != -1) {
      return _knowledgeSentences[bestIdx];
    }
    return "متاسفانه در حافظه من اطلاعاتی درباره این موضوع وجود ندارد.";
  }
}

import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:flutter_embedder/flutter_embedder.dart'; // برای HfTokenizer

class AIService {
  late OrtSession _session;
  late HfTokenizer _tokenizer;
  List<List<double>> _knowledgeEmbeddings = [];
  List<String> _knowledgeSentences = [];

  Future<void> initialize() async {
    OrtEnv.instance.init();

    // 1. بارگذاری مدل ONNX
    final modelBytes = await rootBundle.load('assets/model_int8.onnx');
    _session = OrtSession(modelBytes.buffer.asUint8List());

    // 2. بارگذاری توکنایزر با استفاده از flutter_embedder
    _tokenizer = await HfTokenizer.fromAsset('assets/tokenizer.json');

    // 3. بارگذاری دانش محلی
    final knowledgeText = await rootBundle.loadString('assets/knowledge.txt');
    _knowledgeSentences = knowledgeText.split('\n').where((s) => s.trim().isNotEmpty).toList();

    for (String sentence in _knowledgeSentences) {
      _knowledgeEmbeddings.add(await _getEmbedding(sentence));
    }
  }

  Future<List<double>> _getEmbedding(String text) async {
    // توکنایز کردن متن با HfTokenizer
    final ids = _tokenizer.encode(text);
    final inputIds = ids.map((e) => e.toInt()).toList();
    final attentionMask = List.filled(inputIds.length, 1);
    
    // ساخت تنسورها
    final inputIdsTensor = OrtValueTensor.createTensorWithDataList(
        Int64List.fromList(inputIds), [1, inputIds.length]);
    final attentionMaskTensor = OrtValueTensor.createTensorWithDataList(
        Int64List.fromList(attentionMask), [1, attentionMask.length]);

    final inputs = {
      'input_ids': inputIdsTensor,
      'attention_mask': attentionMaskTensor,
    };
    final outputs = await _session.runAsync(inputs);
    
    final outputData = outputs?[0]?.value as List<List<double>>;
    
    inputIdsTensor.release();
    attentionMaskTensor.release();
    for (var out in outputs!) { out?.release(); }

    return outputData[0];
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

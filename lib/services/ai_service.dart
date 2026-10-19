import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:flutter_embedder/flutter_embedder.dart';

class AIService {
  late OrtSession _session;
  late HfTokenizer _tokenizer;
  List<List<double>> _knowledgeEmbeddings = [];
  List<String> _knowledgeSentences = [];

  Future<void> initialize() async {
    OrtEnv.instance.init();

    // 1. ایجاد Session با استفاده از OrtSession.fromBuffer (روش صحیح)
    final sessionOptions = OrtSessionOptions();
    final modelBytes = await rootBundle.load('assets/model_int8.onnx');
    _session = OrtSession.fromBuffer(
      modelBytes.buffer.asUint8List(),
      sessionOptions,
    );

    // 2. بارگذاری توکنایزر
    _tokenizer = await HfTokenizer.fromAsset('assets/tokenizer.json');

    // 3. بارگذاری دانش محلی
    final knowledgeText = await rootBundle.loadString('assets/knowledge.txt');
    _knowledgeSentences = knowledgeText.split('\n').where((s) => s.trim().isNotEmpty).toList();

    for (String sentence in _knowledgeSentences) {
      _knowledgeEmbeddings.add(await _getEmbedding(sentence));
    }
  }

  Future<List<double>> _getEmbedding(String text) async {
    // توکنایز کردن متن
    final encoding = _tokenizer.encode(text);
    
    // دسترسی مستقیم به فیلدهای inputIds و attentionMask (بدون استفاده از map)
    final inputIds = encoding.inputIds.toList();
    final attentionMask = encoding.attentionMask.toList();

    // ساخت تنسورهای ورودی
    final inputIdsTensor = OrtValueTensor.createTensorWithDataList(
        Int64List.fromList(inputIds), [1, inputIds.length]);
    final attentionMaskTensor = OrtValueTensor.createTensorWithDataList(
        Int64List.fromList(attentionMask), [1, attentionMask.length]);

    final inputs = {
      'input_ids': inputIdsTensor,
      'attention_mask': attentionMaskTensor,
    };

    // ایجاد OrtRunOptions (که در خطای سوم به آن نیاز بود)
    final runOptions = OrtRunOptions();

    // اجرای مدل با ارسال runOptions به عنوان آرگومان اول
    final outputs = await _session.runAsync(runOptions, inputs);

    final outputData = outputs?[0]?.value as List<List<double>>;

    // آزادسازی منابع
    inputIdsTensor.release();
    attentionMaskTensor.release();
    runOptions.release();
    outputs?.forEach((element) => element?.release());

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

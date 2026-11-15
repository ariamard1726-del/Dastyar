import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dastyar/domain/understanding/noql_encoder.dart';
import 'package:dastyar/domain/understanding/noql_tokenizer.dart';
import 'package:dastyar/domain/understanding/topic_guess.dart';

/// خوانندهٔ موضوع: جمله → بردار Noql → سرِ طبقه‌بندِ کوچک (۱۹ دسته).
///
/// مدل دست‌نخورده است و فقط موضوع را حدس می‌زند؛ واقعیت‌ها، استدلال و متن
/// پاسخ همچنان با قاعده‌های وکیل است. نفی را نمی‌فهمد («داده» و «نداده»
/// برایش نزدیک‌اند) و برای همین هیچ واقعیتی از آن گرفته نمی‌شود.
class TopicReader {
  TopicReader({
    required this.tokenizer,
    required this.encoder,
    required this.labels,
    required Float32List weights,
    required Float32List bias,
    required this.open,
    required this.ask,
    this.revision = '',
  })  : _w = weights,
        _b = bias;

  factory TopicReader.fromAssets(
      Uint8List weights, String vocabJson, String headJson) {
    final head = jsonDecode(headJson) as Map<String, dynamic>;
    final labels = (head['labels'] as List).cast<String>();
    final w = head['w'] as List;
    final b = head['b'] as List;
    return TopicReader(
      tokenizer: NoqlTokenizer.fromJson(vocabJson),
      encoder: NoqlEncoder.fromBytes(weights),
      labels: labels,
      weights: Float32List.fromList([for (final v in w) (v as num).toDouble()]),
      bias: Float32List.fromList([for (final v in b) (v as num).toDouble()]),
      open: (head['open'] as num).toDouble(),
      ask: (head['ask'] as num).toDouble(),
      revision: (head['revision'] ?? '').toString(),
    );
  }

  final NoqlTokenizer tokenizer;
  final NoqlEncoder encoder;
  final List<String> labels;
  final Float32List _w;
  final Float32List _b;

  /// از این اطمینان به بالا پرونده مستقیم باز می‌شود.
  final double open;

  /// از این اطمینان تا [open] از کاربر پرسیده می‌شود؛ پایین‌تر، مدل ساکت است.
  final double ask;

  /// نسخهٔ مدل در مخزن سازنده‌اش.
  final String revision;

  /// بردار یکه‌شدهٔ جمله.
  Float32List embed(String text) =>
      encoder.embed(tokenizer.encode(NoqlTokenizer.prepare(text),
          maxTokens: encoder.maxTokens));

  /// احتمال هر دسته برای یک بردار جمله.
  Float64List probabilities(Float32List vec) {
    final n = labels.length;
    final d = vec.length;
    final z = Float64List(n);
    var top = double.negativeInfinity;
    for (var i = 0; i < n; i++) {
      var acc = _b[i].toDouble();
      final o = i * d;
      for (var j = 0; j < d; j++) {
        acc += _w[o + j] * vec[j];
      }
      z[i] = acc;
      if (acc > top) top = acc;
    }
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      z[i] = math.exp(z[i] - top);
      sum += z[i];
    }
    for (var i = 0; i < n; i++) {
      z[i] /= sum;
    }
    return z;
  }

  TopicGuess read(String text) {
    final watch = Stopwatch()..start();
    final ids = tokenizer.encode(NoqlTokenizer.prepare(text),
        maxTokens: encoder.maxTokens);
    final p = probabilities(encoder.embed(ids));
    var a = 0;
    var b = -1;
    for (var i = 1; i < p.length; i++) {
      if (p[i] > p[a]) {
        b = a;
        a = i;
      } else if (b < 0 || p[i] > p[b]) {
        b = i;
      }
    }
    if (b < 0) b = a;
    return TopicGuess(
      labels[a],
      p[a],
      labels[b],
      p[b],
      confident: p[a] >= open,
      plausible: p[a] >= ask,
      millis: watch.elapsedMilliseconds,
      tokens: ids.length,
    );
  }
}

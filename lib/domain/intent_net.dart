import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'package:dastyar/core/persian_text.dart';

/// امتیاز یک برچسب نیت از خروجی softmax شبکهٔ عصبی.
class IntentScore {
  final String label;
  final double score;
  const IntentScore(this.label, this.score);

  @override
  String toString() => '$label=${score.toStringAsFixed(2)}';
}

/// شبکهٔ عصبی کوچکِ طبقه‌بندی نیت — ۱۰۰٪ آفلاین و بدون هیچ افزونهٔ بومی.
///
/// وزن‌ها در assets/brain/intent_model.json قرار دارند (خروجی
/// brain/train_intent.py، کوانتیدهٔ int8) و استنتاج دقیقاً همان ریاضیِ
/// `tools/check.py intent` است:
///   ویژگی‌های هش‌شدهٔ واژه + n-gram حرفی (FNV-1a) → L1-normalize
///   → لایهٔ نهان relu → softmax.
/// هیچ LLM، API خارجی یا کتابخانهٔ tflite در کار نیست.
class IntentNet {
  // توجه: پارامترهای نام‌دارِ خصوصی (this._x) به Dart 3.12 نیاز دارند و
  // زبان بسته روی ۳٫۰ است؛ پس با نام عمومی می‌گیریم و در فهرست مقداردهی
  // به فیلدهای خصوصی نسبت می‌دهیم.
  IntentNet._({
    required this.labels,
    required this.thresholds,
    required int nb,
    required int hidden,
    required int ngramMin,
    required int ngramMax,
    required Float64List w1,
    required Float64List b1,
    required Float64List w2,
    required Float64List b2,
    required this.metrics,
  })  : _nb = nb,
        _hidden = hidden,
        _ngramMin = ngramMin,
        _ngramMax = ngramMax,
        _w1 = w1,
        _b1 = b1,
        _w2 = w2,
        _b2 = b2;

  /// برچسب‌های دسته‌ها (مرتب‌شده، همان ترتیب خروجی softmax).
  final List<String> labels;

  /// آستانه‌های تصمیم: topic_min/rag_min/cancel_min.
  final Map<String, double> thresholds;

  /// معیارهای آموزش (برای نمایش در دیباگ/درباره).
  final Map<String, dynamic> metrics;

  final int _nb;
  final int _hidden;
  final int _ngramMin;
  final int _ngramMax;
  final Float64List _w1; // row-major nb × hidden
  final Float64List _b1;
  final Float64List _w2; // row-major hidden × labels
  final Float64List _b2;

  double get topicMin => thresholds['topic_min'] ?? 0.45;
  double get ragMin => thresholds['rag_min'] ?? 0.50;
  double get cancelMin => thresholds['cancel_min'] ?? 0.60;

  static const Set<String> topicLabels = {
    'cheque', 'labor', 'lease', 'family', 'fraud_cyber', 'criminal_harm',
    'litigation_defense', 'debt', 'general_intake',
  };
  static const Set<String> ragLabels = {'legal_question', 'article_lookup'};

  static final RegExp _nonWord = RegExp(
    r'[^\u0621-\u063A\u0641-\u064A\u067E\u0686\u0698\u06A9\u06AF\u06CCa-z0-9]+',
  );

  /// بارگذاری از asset؛ در صورت خرابی فایل null برمی‌گرداند تا برنامه
  /// با مسیر نمادین (بدون شبکه) به کارش ادامه دهد.
  static Future<IntentNet?> load({
    String asset = 'assets/brain/intent_model.json',
  }) async {
    try {
      final raw = await rootBundle.loadString(asset);
      return IntentNet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  factory IntentNet.fromJson(Map<String, dynamic> m) {
    if (m['activation'] != 'relu' || m['input_norm'] != 'l1') {
      throw const FormatException('پیکربندی مدل پشتیبانی نمی‌شود');
    }
    final labels = (m['labels'] as List).map((e) => e.toString()).toList();
    final nb = (m['nb'] as num).toInt();
    final hidden = (m['hidden'] as num).toInt();
    final ngram = (m['ngram'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const [3, 5];
    final th = <String, double>{};
    final rawTh = m['thresholds'];
    if (rawTh is Map) {
      rawTh.forEach((k, v) => th[k.toString()] = (v as num).toDouble());
    }
    return IntentNet._(
      labels: labels,
      thresholds: th,
      metrics: m['metrics'] is Map
          ? Map<String, dynamic>.from(m['metrics'] as Map)
          : const {},
      nb: nb,
      hidden: hidden,
      ngramMin: ngram[0],
      ngramMax: ngram[1],
      w1: _deq(m['w1'], nb * hidden),
      b1: _deq(m['b1'], hidden),
      w2: _deq(m['w2'], hidden * labels.length),
      b2: _deq(m['b2'], labels.length),
    );
  }

  static Float64List _deq(dynamic t, int wantLen) {
    final m = t as Map<String, dynamic>;
    final bytes = base64Decode(m['b64'] as String);
    final shape = (m['shape'] as List?)?.map((e) => (e as num).toInt()).toList();
    var size = 1;
    for (final d in shape ?? const <int>[]) {
      size *= d;
    }
    if (bytes.length != wantLen || (shape != null && size != wantLen)) {
      throw FormatException('اندازهٔ تانسور نادرست: ${bytes.length} != $wantLen');
    }
    final scale = (m['scale'] as num).toDouble();
    if (!(scale > 0) || scale.isNaN || scale.isInfinite) {
      throw const FormatException('مقیاس کوانتیزاسیون نامعتبر');
    }
    final out = Float64List(wantLen);
    for (var i = 0; i < wantLen; i++) {
      final b = bytes[i];
      out[i] = (b > 127 ? b - 256 : b) * scale;
    }
    return out;
  }

  /// حذف نویسه‌های غیرBMP (سورگیت‌ها) تا هش با آینهٔ پایتون یکسان بماند.
  static String _stripNonBmp(String s) {
    final sb = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c < 0xD800 || c > 0xDFFF) sb.writeCharCode(c);
    }
    return sb.toString();
  }

  /// FNV-1a ۳۲بیتی — دقیقاً هم‌الگوریتم با brain/common.py#fnv.
  static int _fnv(String s) {
    var h = 2166136261;
    for (var i = 0; i < s.length; i++) {
      h ^= s.codeUnitAt(i);
      h = (h * 16777619) & 0xFFFFFFFF;
    }
    return h;
  }

  static List<String> _words(String s) {
    final cleaned =
        PersianText.normalize(_stripNonBmp(s)).replaceAll(_nonWord, ' ');
    return cleaned.split(' ').where((w) => w.isNotEmpty).toList();
  }

  /// سطل‌های هش ویژگی (واژه + n-gramهای حرفی) — آینهٔ brain/common.py#feats.
  List<int> featureBuckets(String text) {
    final ids = <int>[];
    for (final w in _words(text)) {
      ids.add(_fnv('w:$w') % _nb);
      final t = '<$w>';
      for (var n = _ngramMin; n <= _ngramMax; n++) {
        for (var i = 0; i + n <= t.length; i++) {
          ids.add(_fnv(t.substring(i, i + n)) % _nb);
        }
      }
    }
    return ids;
  }

  /// بردار احتمال softmax روی همهٔ برچسب‌ها.
  List<double> probabilities(String text) {
    final counts = <int, int>{};
    for (final b in featureBuckets(text)) {
      counts[b] = (counts[b] ?? 0) + 1;
    }
    final c = labels.length;
    if (counts.isEmpty) return List<double>.filled(c, 0);
    var total = 0;
    counts.forEach((_, v) => total += v);

    final h = Float64List.fromList(_b1);
    counts.forEach((i, cnt) {
      final xi = cnt / total;
      final base = i * _hidden;
      for (var j = 0; j < _hidden; j++) {
        h[j] += xi * _w1[base + j];
      }
    });
    for (var j = 0; j < _hidden; j++) {
      if (h[j] < 0) h[j] = 0;
    }

    final logits = Float64List.fromList(_b2);
    for (var j = 0; j < _hidden; j++) {
      final hj = h[j];
      if (hj == 0) continue;
      final base = j * c;
      for (var k = 0; k < c; k++) {
        logits[k] += hj * _w2[base + k];
      }
    }

    var mx = logits[0];
    for (final v in logits) {
      if (v > mx) mx = v;
    }
    var sum = 0.0;
    final exps = Float64List(c);
    for (var k = 0; k < c; k++) {
      // مهار سرریز: توان‌ها به بازهٔ [-745, 0] بریده می‌شوند.
      final e = _expClamped(logits[k] - mx);
      exps[k] = e;
      sum += e;
    }
    if (sum <= 0) return List<double>.filled(c, 0);
    return [for (var k = 0; k < c; k++) exps[k] / sum];
  }

  static double _expClamped(double v) {
    if (v < -745) return 0;
    if (v > 0) v = 0;
    return math.exp(v);
  }

  /// بهترین برچسب و امتیاز آن.
  IntentScore classify(String text) {
    final p = probabilities(text);
    var best = 0;
    for (var i = 1; i < p.length; i++) {
      if (p[i] > p[best]) best = i;
    }
    return IntentScore(labels[best], p[best]);
  }

  /// k برچسب برتر با امتیازشان (برای نکتهٔ «موضوع مرتبط» در تراشه‌ها).
  List<IntentScore> top(String text, {int k = 3}) {
    final p = probabilities(text);
    final idx = [for (var i = 0; i < p.length; i++) i]
      ..sort((a, b) => p[b].compareTo(p[a]));
    return [
      for (final i in idx.take(k)) IntentScore(labels[i], p[i]),
    ];
  }

  /// احتمال تجمعی برچسب‌های یک گروه (مثلاً حوزه‌های مشاوره).
  double groupScore(String text, Set<String> group) {
    final p = probabilities(text);
    var s = 0.0;
    for (var i = 0; i < labels.length; i++) {
      if (group.contains(labels[i])) s += p[i];
    }
    return s;
  }
}

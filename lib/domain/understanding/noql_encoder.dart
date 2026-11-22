import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// گذرِ رو به جلوی مدل Noql (ALBERT، ۱۲ لایه با وزن مشترک) به Dart خالص.
///
/// وزن‌ها از `assets/brain/noql.bin` می‌آیند (قالب NOQL1، ساختهٔ
/// `brain/noql/export.py`): ماتریس‌ها int8 سطربه‌سطر و بقیه float32. هیچ
/// کتابخانهٔ بومی‌ای در کار نیست؛ ضرب‌ها با `Float32x4` انجام می‌شود.
/// خروجی بردار ۷۶۸تاییِ یکه‌شدهٔ جمله است (میانگین توکن‌ها).
class NoqlEncoder {
  NoqlEncoder._(this.maxTokens, this.heads, this.layers, this._f, this._word,
      this._wordScale)
      : embDim = _f['emb_ln.w']!.length,
        dim = _f['map.b']!.length,
        ffn = _f['f.b']!.length;

  /// فایل وزن‌ها را می‌خواند و ماتریس‌های کوچک‌تر را به float32 باز می‌کند.
  factory NoqlEncoder.fromBytes(Uint8List bytes) {
    const magic = [0x4E, 0x4F, 0x51, 0x4C, 0x31, 0, 0, 0]; // NOQL1
    if (bytes.length < 12) throw const FormatException('noql.bin: too short');
    for (var i = 0; i < 8; i++) {
      if (bytes[i] != magic[i]) {
        throw const FormatException('noql.bin: bad magic');
      }
    }
    final view = ByteData.sublistView(bytes);
    final headLen = view.getUint32(8, Endian.little);
    final head = jsonDecode(utf8.decode(bytes.sublist(12, 12 + headLen)))
        as Map<String, dynamic>;
    final base = 12 + headLen;
    final ints = <String, Int8List>{};
    final floats = <String, Float32List>{};
    for (final t in (head['tensors'] as List).cast<Map<String, dynamic>>()) {
      final name = t['name'] as String;
      var count = 1;
      for (final d in t['shape'] as List) {
        count *= d as int;
      }
      final at = base + (t['offset'] as int);
      if (t['type'] == 'i8') {
        ints[name] = Int8List.fromList(
            Int8List.sublistView(bytes, at, at + count));
      } else {
        final f = Float32List(count);
        for (var i = 0; i < count; i++) {
          f[i] = view.getFloat32(at + 4 * i, Endian.little);
        }
        floats[name] = f;
      }
    }
    // همهٔ ماتریس‌ها جز جدول واژه‌ها یک‌بار به float32 باز می‌شوند.
    for (final name in ints.keys.toList()) {
      if (name == 'word') continue;
      final q = ints.remove(name)!;
      final scale = floats.remove('$name.scale')!;
      final cols = q.length ~/ scale.length;
      final f = Float32List(q.length);
      for (var r = 0; r < scale.length; r++) {
        final s = scale[r];
        final o = r * cols;
        for (var c = 0; c < cols; c++) {
          f[o + c] = q[o + c] * s;
        }
      }
      floats[name] = f;
    }
    return NoqlEncoder._(
      head['max_tokens'] as int,
      head['heads'] as int,
      head['layers'] as int,
      floats,
      ints['word']!,
      floats.remove('word.scale')!,
    );
  }

  final int maxTokens;
  final int heads;
  final int layers;
  final int embDim;
  final int dim;
  final int ffn;
  final Map<String, Float32List> _f;
  final Int8List _word;
  final Float32List _wordScale;

  static const double _eps = 1e-12;

  Float32List _t(String name) => _f[name]!;

  /// بردار جمله برای فهرست شناسهٔ توکن (با `[CLS]` و `[SEP]`).
  Float32List embed(List<int> ids) {
    final n = ids.length > maxTokens ? maxTokens : ids.length;
    final e = embDim;
    final d = dim;
    final x = Float32List(n * e);
    final pos = _t('pos');
    final type0 = _t('type0');
    for (var s = 0; s < n; s++) {
      final row = ids[s] * e;
      final scale = _wordScale[ids[s]];
      for (var j = 0; j < e; j++) {
        x[s * e + j] = _word[row + j] * scale + type0[j] + pos[s * e + j];
      }
    }
    _layerNorm(x, n, e, _t('emb_ln.w'), _t('emb_ln.b'));

    var h = Float32List(n * d);
    _linear(_t('map.w'), _t('map.b'), x, h, n, e, d);

    final q = Float32List(n * d);
    final k = Float32List(n * d);
    final v = Float32List(n * d);
    final ctx = Float32List(n * d);
    final att = Float32List(n * d);
    final mid = Float32List(n * ffn);
    var out = Float32List(n * d);
    final hd = d ~/ heads;
    final inv = 1 / math.sqrt(hd);
    final p = Float64List(n);

    for (var layer = 0; layer < layers; layer++) {
      _linear(_t('q.w'), _t('q.b'), h, q, n, d, d);
      _linear(_t('k.w'), _t('k.b'), h, k, n, d, d);
      _linear(_t('v.w'), _t('v.b'), h, v, n, d, d);
      for (var head = 0; head < heads; head++) {
        final ho = head * hd;
        for (var s = 0; s < n; s++) {
          var top = double.negativeInfinity;
          for (var u = 0; u < n; u++) {
            var dot = 0.0;
            final a = s * d + ho;
            final b = u * d + ho;
            for (var j = 0; j < hd; j++) {
              dot += q[a + j] * k[b + j];
            }
            dot *= inv;
            p[u] = dot;
            if (dot > top) top = dot;
          }
          var sum = 0.0;
          for (var u = 0; u < n; u++) {
            p[u] = math.exp(p[u] - top);
            sum += p[u];
          }
          final a = s * d + ho;
          for (var j = 0; j < hd; j++) {
            var acc = 0.0;
            for (var u = 0; u < n; u++) {
              acc += p[u] * v[u * d + ho + j];
            }
            ctx[a + j] = acc / sum;
          }
        }
      }
      _linear(_t('o.w'), _t('o.b'), ctx, att, n, d, d);
      for (var i = 0; i < n * d; i++) {
        att[i] += h[i];
      }
      _layerNorm(att, n, d, _t('att_ln.w'), _t('att_ln.b'));

      _linear(_t('f.w'), _t('f.b'), att, mid, n, d, ffn);
      for (var i = 0; i < n * ffn; i++) {
        final z = mid[i];
        mid[i] = 0.5 *
            z *
            (1.0 + _tanh(0.7978845608028654 * (z + 0.044715 * z * z * z)));
      }
      _linear(_t('fo.w'), _t('fo.b'), mid, out, n, ffn, d);
      for (var i = 0; i < n * d; i++) {
        out[i] += att[i];
      }
      _layerNorm(out, n, d, _t('out_ln.w'), _t('out_ln.b'));
      final swap = h;
      h = out;
      out = swap;
    }

    final vec = Float32List(d);
    var norm = 0.0;
    for (var j = 0; j < d; j++) {
      var acc = 0.0;
      for (var s = 0; s < n; s++) {
        acc += h[s * d + j];
      }
      acc /= n;
      vec[j] = acc;
      norm += acc * acc;
    }
    norm = math.sqrt(norm);
    if (norm < 1e-12) norm = 1e-12;
    for (var j = 0; j < d; j++) {
      vec[j] = vec[j] / norm;
    }
    return vec;
  }

  static double _tanh(double x) {
    if (x > 20) return 1;
    if (x < -20) return -1;
    final e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }

  /// `y[s, i] = b[i] + Σ w[i, j]·x[s, j]` برای هر توکن `s`.
  ///
  /// [inp] باید مضرب ۱۶ باشد (۱۲۸، ۷۶۸ و ۳۰۷۲ هستند).
  static void _linear(Float32List w, Float32List b, Float32List x,
      Float32List y, int n, int inp, int out) {
    final wv = w.buffer.asFloat32x4List(w.offsetInBytes, w.length ~/ 4);
    final xv = x.buffer.asFloat32x4List(x.offsetInBytes, x.length ~/ 4);
    final n4 = inp ~/ 4;
    for (var i = 0; i < out; i++) {
      final wo = i * n4;
      final bias = b[i];
      for (var s = 0; s < n; s++) {
        final xo = s * n4;
        var a0 = Float32x4.zero();
        var a1 = Float32x4.zero();
        var a2 = Float32x4.zero();
        var a3 = Float32x4.zero();
        for (var j = 0; j < n4; j += 4) {
          a0 += wv[wo + j] * xv[xo + j];
          a1 += wv[wo + j + 1] * xv[xo + j + 1];
          a2 += wv[wo + j + 2] * xv[xo + j + 2];
          a3 += wv[wo + j + 3] * xv[xo + j + 3];
        }
        final t = (a0 + a1) + (a2 + a3);
        y[s * out + i] = t.x + t.y + t.z + t.w + bias;
      }
    }
  }

  static void _layerNorm(
      Float32List x, int n, int width, Float32List w, Float32List b) {
    for (var s = 0; s < n; s++) {
      final o = s * width;
      var mean = 0.0;
      for (var j = 0; j < width; j++) {
        mean += x[o + j];
      }
      mean /= width;
      var variance = 0.0;
      for (var j = 0; j < width; j++) {
        final c = x[o + j] - mean;
        variance += c * c;
      }
      final scale = 1 / math.sqrt(variance / width + _eps);
      for (var j = 0; j < width; j++) {
        x[o + j] = (x[o + j] - mean) * scale * w[j] + b[j];
      }
    }
  }
}

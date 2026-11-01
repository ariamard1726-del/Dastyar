import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('هر بخش قانون کار بعد از اولین ماده با «ماده» یا «#» شروع می‌شود', () {
    final f = File(
        'assets/laws/Hoghough_e_Khosousi/Hoghough_e_Kar/Hoghough_E_Kar.txt');
    final parts =
        f.readAsStringSync().replaceAll('\r', '').split(RegExp(r'\n\s*\n'));
    var seen = false;
    final bad = <String>[];
    for (final p in parts) {
      final first = p.trim().split('\n').first.trim();
      if (first.isEmpty) continue;
      if (first.startsWith('ماده ')) {
        seen = true;
        continue;
      }
      if (first.startsWith('#')) continue;
      if (seen) bad.add(first.length > 60 ? first.substring(0, 60) : first);
    }
    expect(seen, isTrue);
    expect(bad, isEmpty,
        reason: '${bad.length} بخش بدون عنوان ماده: ${bad.take(5).join(" | ")}');
  });
}

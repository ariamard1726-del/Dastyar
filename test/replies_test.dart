import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/engine.dart';
import 'package:dastyar/replies.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine e;

  setUpAll(() async {
    e = KnowledgeEngine();
    await e.load();
  });

  test('همهٔ کلیدهای replies.json شناخته‌شده و پرند', () async {
    final t = await rootBundle.loadString('assets/replies.json');
    final m = jsonDecode(t) as Map<String, dynamic>;
    expect(m, isNotEmpty);
    for (final k in m.keys) {
      expect(Replies.defaults.containsKey(k), isTrue, reason: 'کلید ناشناخته: $k');
      expect(m[k].toString().trim(), isNotEmpty, reason: 'مقدار خالی: $k');
    }
  });

  test('جای‌نگهدار {law} جایگزین می‌شود', () {
    expect(
      Replies().get('missing_law', {'law': 'قانون مدنی'}),
      'توجه: متن «قانون مدنی» هنوز در برنامه نیست.',
    );
  });

  test('پرسش خالی، پاسخ ask_more را می‌دهد', () {
    expect(e.answer('؟'), e.replies.get('ask_more'));
    expect(e.replies.get('ask_more'), 'لطفاً پرسش خود را کامل‌تر بنویسید.');
  });

  test('پرسش دربارهٔ توانایی‌ها، متن capabilities را می‌دهد', () {
    final a = e.answer('چه کارهایی می‌توانی انجام بدهی؟');
    expect(a, e.replies.get('capabilities'));
    expect(a.contains('وکیل نیستم'), isTrue);
  });

  test('هیچ پاسخ ثابتی خالی نیست', () {
    for (final k in Replies.defaults.keys) {
      expect(e.replies.get(k).trim(), isNotEmpty, reason: k);
    }
  });
}

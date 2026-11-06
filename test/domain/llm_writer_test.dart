import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/llm.dart';
import 'package:dastyar/domain/lawyer/llm_writer.dart';

class FakeLlm extends LlmBackend {
  final bool ready;
  final List<String> tokens;
  final Duration delay;
  bool cancelled = false;
  String? lastPrompt;
  FakeLlm(this.tokens, {this.ready = true, this.delay = Duration.zero});

  @override
  String get name => 'fake';
  @override
  Future<bool> isReady() async => ready;
  @override
  Stream<String> generate(String prompt,
      {LlmOptions options = const LlmOptions()}) async* {
    lastPrompt = prompt;
    for (final t in tokens) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (cancelled) return;
      yield t;
    }
  }

  @override
  void cancel() => cancelled = true;
}

void main() {
  group('ProseGuard', () {
    test('جملهٔ همدلانهٔ تمیز پذیرفته می‌شود', () {
      const t =
          'می‌فهمم که صاحبخانه پول پیش شما را پس نمی‌دهد و نگران خانهٔ بعدی هستید. با هم قدم‌به‌قدم جلو می‌رویم.';
      expect(ProseGuard.accept(t), t);
    });
    test('ي و ك عربی اصلاح می‌شود', () {
      final r = ProseGuard.accept(
          'مي‌فهمم كه اين وضعيت براي شما سخت است و با هم پيش مي‌رويم.');
      expect(r, isNotNull);
      expect(r, isNot(contains('ي')));
      expect(r, isNot(contains('ك')));
    });
    const rejects = <String, String>{
      'عدد': 'طبق تجربه ظرف ۱۰ روز کار تمام می‌شود و نگران نباشید.',
      'ماده': 'طبق ماده چهار حق با شماست و نگران نباشید اصلاً.',
      'قانون': 'قانون از شما حمایت می‌کند و با هم پیش می‌رویم.',
      'دادگاه': 'باید به دادگاه بروید و شکایت کنید تا حقتان را بگیرید.',
      'قول نتیجه': 'قطعاً پرونده را می‌برید و پولتان برمی‌گردد خیالتان راحت.',
      'لاتین': 'I understand your situation and we will go step by step.',
      'ناتمام': 'می‌فهمم که صاحبخانه پول پیش شما را پس نمی‌دهد و',
      'خیلی کوتاه': 'باشه.',
      'خودمعرفی': 'به عنوان یک دستیار می‌فهمم که شرایط سختی دارید.',
    };
    rejects.forEach((k, t) {
      test('رد: $k', () => expect(ProseGuard.accept(t), isNull));
    });
  });

  group('LlmWriter', () {
    test('خروجی امن برمی‌گردد و پرسش کاربر در پرامپت هست', () async {
      final llm = FakeLlm([
        'می‌فهمم که کارفرما ',
        'حقوق دو ماه شما را نداده است. ',
        'با هم قدم‌به‌قدم پیش می‌رویم.',
      ]);
      final w = LlmWriter(llm);
      final r = await w.personalOpener('کارفرما دو ماهه حقوقمو نداده', 'حقوق معوقه');
      expect(r, startsWith('می‌فهمم'));
      expect(llm.lastPrompt, contains('کارفرما دو ماهه حقوقمو نداده'));
    });
    test('خروجی ناامن کنار گذاشته می‌شود', () async {
      final w = LlmWriter(FakeLlm(['طبق ماده ۱۵۷ قانون کار حق با شماست.']));
      expect(await w.personalOpener('x', 'y'), isNull);
    });
    test('مدل آماده نیست', () async {
      final w = LlmWriter(FakeLlm(['سلام'], ready: false));
      expect(await w.personalOpener('x', 'y'), isNull);
    });
    test('دیرکرد مدل: بدون پاسخ و با توقف تولید', () async {
      final llm = FakeLlm(['می‌فهمم ', 'که ', 'سخت است.'],
          delay: const Duration(milliseconds: 200));
      final w = LlmWriter(llm, timeout: const Duration(milliseconds: 250));
      expect(await w.personalOpener('x', 'y'), isNull);
      expect(llm.cancelled, isTrue);
    });
  });
}

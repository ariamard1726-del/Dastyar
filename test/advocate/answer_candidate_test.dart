import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/advocate/advocate.dart';

/// داورِ پاسخ نهتنها متن را برمیگرداند، بلکه میگوید کدام مسیر با چه دلیلی
/// برنده شد. همین متادیتا جای «پاسخ بیبرچسب» را میگیرد.
void main() {
  test('اولین کاندیدِ پاسخدهنده و متادیتایش برنده میشود', () {
    final called = <String>[];
    const skipped = AnswerCandidate(
      'اول',
      skippedBuild,
      source: AnswerSource.topic,
      confidence: 0.2,
      why: 'مسیر عادی',
    );
    final winner = AnswerCandidate(
      'ایمنی',
      () {
        called.add('ایمنی');
        return AdvocateReply('p', source: AnswerSource.safety);
      },
      source: AnswerSource.safety,
      confidence: 0.95,
      why: 'خطر فوری',
    );

    final decision = const AnswerArbiter().decide([skipped, winner]);
    expect(decision, isNotNull);
    expect(decision!.candidate.name, 'ایمنی');
    expect(decision.candidate.source, AnswerSource.safety);
    expect(decision.candidate.confidence, closeTo(0.95, 0.000001));
    expect(decision.candidate.why, 'خطر فوری');
    expect(decision.reply.source, AnswerSource.safety);
    expect(called, ['ایمنی']);
  });

  test('پیک تنها reply تصمیم را برمیگرداند و وقتی کسی جواب نداد null است', () {
    const none = AnswerCandidate('هیچکس', skippedBuild);
    expect(const AnswerArbiter().pick([none]), isNull);
    expect(const AnswerArbiter().decide([none]), isNull);
  });
}

AdvocateReply? skippedBuild() => null;

// قفلِ سمتِ دارت: داده از کد بیرون رفته و باید همان چیزی بماند که بود.
//
// سه چیز سنجیده می‌شود:
//   ۱. فایلِ دارایی خوانده می‌شود و ۳۴ راهنما با همان ترتیب می‌دهد.
//   ۲. نصب، همان فهرست را در دسترسِ وکیل می‌گذارد (بارگذار کار می‌کند).
//   ۳. اگر فهرست عوض شود، نقشه‌های `LawyerVoice` هم عوض می‌شوند — همان تلهٔ
//      «یک بار برای همیشه» که انگیزهٔ نصبِ صریح بود.
import 'dart:io';

import 'package:dastyar/domain/lawyer/legal_guides.dart';
import 'package:dastyar/domain/lawyer/legal_guides_loader.dart';
import 'package:dastyar/domain/lawyer/lawyer_voice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<LegalGuide> full;

  setUpAll(() async {
    full = parseLegalGuides(File(legalGuidesAsset).readAsStringSync());
  });

  tearDown(() => installLegalGuides(full));

  test('فایلِ دارایی ۳۴ راهنما با ترتیبِ پایدار می‌دهد', () {
    expect(full.length, 34);
    expect(full.first.id, 'cheque_guarantee');
    expect(full.every((g) => g.answer.isNotEmpty && g.followUp.isNotEmpty), isTrue);
    expect([for (final g in full) g.id].toSet().length, full.length);
  });

  test('بارگذار همان فهرست را نصب می‌کند', () async {
    final installed = await loadLegalGuides();
    expect(legalGuidesLoaded, isTrue);
    expect([for (final g in installed) g.id], [for (final g in full) g.id]);
    expect([for (final g in legalGuides) g.id], [for (final g in full) g.id]);
  });

  test('عنوانِ دقیقِ راهنما همان راهنما را برمی‌گرداند', () {
    installLegalGuides(full);
    final g = LawyerVoice.matchGuide(full.first.title);
    expect(g?.id, full.first.id);
  });

  test('نصبِ فهرستِ تازه، نقشه‌های LawyerVoice را بازمی‌سازد', () {
    installLegalGuides(full);
    expect(LawyerVoice.matchGuide(full.first.title)?.id, full.first.id);

    // فقط آخرین راهنما نصب می‌شود؛ اگر نقشه‌ها «یک بار برای همیشه» بودند،
    // راهنمای اول هنوز پیدا می‌شد.
    installLegalGuides([full.last]);
    expect(LawyerVoice.matchGuide(full.first.title), isNull);
    expect(LawyerVoice.matchGuide(full.last.title)?.id, full.last.id);

    installLegalGuides(const []);
    expect(LawyerVoice.matchGuide(full.last.title), isNull);
  });
}

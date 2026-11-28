import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';

void main() {
  Advocate fresh() => Advocate(KnowledgeEngine());

  test('Sense.amount صریح‌بودن تومان خُرد/واقعی را تشخیص می‌دهد', () {
    expect(Sense.amount(Sense.norm('۳۰ تومن')), 30000000);
    expect(Sense.amountIsExplicit(Sense.norm('۳۰ تومن')), isFalse);

    expect(Sense.amount(Sense.norm('۵۰ تومان واقعی')), 50);
    expect(Sense.amountIsExplicit(Sense.norm('۵۰ تومان واقعی')), isTrue);

    expect(Sense.amount(Sense.norm('۵۰ تومان، نه میلیون')), 50);
    expect(Sense.amount(Sense.norm('۵۰ هزار تومان، میلیون نیست')), 50000);
  });

  test('پس از فرض میلیونی «۳۰ تومن»، دکمهٔ مبلغ خُرد آن را بی‌برخورد با پرسش معلق اصلاح می‌کند',
      () {
    final a = fresh();
    a.respond('طلب دارم');
    final assumed = a.respond('۳۰ تومن');
    expect(a.file.topic, 'debt');
    expect(a.file.n('amount'), 30000000);
    expect(assumed.chips, contains(ChipTexts.plainTomanChip));

    final fixed = a.respond(ChipTexts.plainTomanChip);
    expect(a.file.n('amount'), 30);
    expect(a.file.has('proof'), isFalse,
        reason: 'واژهٔ «نیست» نباید به پرسش معلق پاسخ منفی بدهد');
    expect(fixed.chips, isNot(contains(ChipTexts.plainTomanChip)));
  });
}

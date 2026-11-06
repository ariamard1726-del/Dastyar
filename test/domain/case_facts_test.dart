import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/lawyer/case_facts.dart';

void main() {
  group('CaseFacts.extract', () {
    test('مبلغ، زمان، طرف مقابل و پایان قرارداد', () {
      final f = CaseFacts.extract(
        'صاحبخانه ام ۲۰۰ میلیون ودیعه منو پس نمیده و قراردادم دو ماه پیش تموم شده',
      );
      expect(f.amounts, contains('۲۰۰ میلیون'));
      expect(f.durations, contains('دو ماه پیش'));
      expect(f.counterparties, contains('صاحبخانه'));
      expect(f.has(CaseFlag.contractEnded), isTrue);
      expect(f.has(CaseFlag.refusesPay), isTrue);
    });

    test('سکهٔ مهریه و بیش از ۱۱۰ سکه', () {
      final f = CaseFacts.extract('مهریه ام ۱۱۴ سکه است');
      expect(f.coins, 114);
      expect(f.amounts, contains('۱۱۴ سکه'));
      expect(f.has(CaseFlag.coinsOver110), isTrue);
    });

    test('حروف عربی ي و ك یکدست می‌شوند', () {
      final f = CaseFacts.extract('كارفرما بيمه نداره و اخراجم كرده');
      expect(f.counterparties, contains('کارفرما'));
      expect(f.has(CaseFlag.noInsurance), isTrue);
      expect(f.has(CaseFlag.fired), isTrue);
    });

    test('مدارک مثبت و منفی', () {
      final f = CaseFacts.extract('پیام واتساپ دارم و یه شاهد');
      expect(f.evidence, containsAll(<String>['messages', 'witness']));
      final g = CaseFacts.extract('قرارداد ننوشتیم و مدرکی ندارم');
      expect(g.evidence, isNot(contains('contract')));
      expect(g.has(CaseFlag.noWrittenContract), isTrue);
      expect(g.has(CaseFlag.noEvidence), isTrue);
    });

    test('سن زیر ۱۸ و تعداد فرزندان', () {
      final f = CaseFacts.extract('پسرم ۱۷ سالشه و بازداشته');
      expect(f.ages, contains(17));
      expect(f.has(CaseFlag.minor), isTrue);
      expect(f.has(CaseFlag.detained), isTrue);
      final k = CaseFacts.extract('دو تا بچه دارم');
      expect(k.children, 2);
    });

    test('متن عادی چیزی استخراج نمی‌کند و قطعی است', () {
      expect(CaseFacts.extract('مجازات کلاهبرداری چیست').isEmpty, isTrue);
      expect(CaseFacts.extract('').isEmpty, isTrue);
      final a = CaseFacts.extract('به دوستم ۵۰ میلیون تومان قرض دادم').render();
      final b = CaseFacts.extract('به دوستم ۵۰ میلیون تومان قرض دادم').render();
      expect(a, b);
      expect(a, contains(CaseFacts.summaryHead));
      expect(a, contains('۵۰ میلیون تومان'));
    });

    test('merge تکرار نمی‌کند', () {
      final a = CaseFacts.extract('همسایه آب داده');
      final b = CaseFacts.extract('همسایه شاهد دارم');
      final m = a.merge(b);
      expect(m.counterparties.where((c) => c == 'همسایه').length, 1);
      expect(m.evidence, contains('witness'));
    });
  });
}

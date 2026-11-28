import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';

/// فاز ۱ برنامهٔ ارتقای فهم (`docs/UNDERSTANDING_UPGRADE_1405.md`):
/// نفی صریح و شمارهٔ مواد، بی‌نیاز از مدل و از موتور.
void main() {
  group('نفی صریح در متن یکسان‌شده', () {
    test('نفی چسبیدن «نمی» به فعل پس از نرمال‌سازی تشخیص داده می‌شود', () {
      expect(Sense.containsNegation(Sense.norm('کارفرما بیمه ام را نمی کند')), isTrue);
      expect(Sense.containsNegation(Sense.norm('مستاجر پول را نمی دهد')), isTrue);
    });

    test('فرم‌های دیگر نفی دیده می‌شوند', () {
      expect(Sense.containsNegation(Sense.norm('من قرارداد ندارم')), isTrue);
      expect(Sense.containsNegation(Sense.norm('هرگز پولش را ندیدم')), isTrue);
      expect(Sense.containsNegation(Sense.norm('نباید این کار را بکنی')), isTrue);
      expect(Sense.containsNegation(Sense.norm('سندی وجود ندارد')), isTrue);
      expect(Sense.containsNegation(Sense.norm('نه، این کار را نمی خواهم')), isTrue);
    });

    test('جملات مثبت نفی حساب نمی‌شوند', () {
      expect(Sense.containsNegation(Sense.norm('من قرارداد دارم')), isFalse);
      expect(Sense.containsNegation(Sense.norm('حقوقم را گرفته ام')), isFalse);
      expect(Sense.containsNegation(Sense.norm('همسایه دیوار را ساخت')), isFalse);
    });
  });

  group('شمارهٔ مواد در متن یکسان‌شده', () {
    test('شمارهٔ تک ماده خوانده می‌شود', () {
      expect(Sense.articleNumbers(Sense.norm('طبق ماده 45 قانون کار')), [45]);
      expect(Sense.articleNumbers(Sense.norm('ماده ۱۲۵۹ قانون مدنی')), [1259]);
    });

    test('چند ماده در یک جمله خوانده می‌شوند و تکراری نمی‌شوند', () {
      expect(Sense.articleNumbers(Sense.norm('مواد ۱۲ و مواد ۱۳')), [12, 13]);
      expect(Sense.articleNumbers(Sense.norm('ماده 45 و دوباره ماده 45')), [45]);
    });

    test('«مکرر» شماره را عوض نمی‌کند ولی خطا هم نمی‌سازد', () {
      expect(Sense.articleNumbers(Sense.norm('ماده 12 مکرر')), [12]);
    });

    test('متن بدون ماده هیچ شماره‌ای نمی‌دهد', () {
      expect(Sense.articleNumbers(Sense.norm('سلام، حال شما چطور است؟')),
          isEmpty);
    });
  });
}

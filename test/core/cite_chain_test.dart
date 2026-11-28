import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/advocate/cite_chain.dart';
import 'package:dastyar/domain/advocate/reasoner.dart';

/// زنجیرهٔ استناد (فاز ۴): قالب ساختاری این زنجیره هم در UI و هم در ابزارها
/// خوانده می‌شود؛ این آزمون قالب را قفل می‌کند.
void main() {
  test('زنجیرهٔ کامل با شرط‌های ناکام', () {
    final chain = CiteChain(
      facts: ['خریدار ثمن را نداده', 'مبیع تسلیم شده'],
      rule: 'فروشندهٔ ثمن‌نگرفته',
      standing: Standing.open,
      citation: 'مادهٔ ۳۸۴ قانون مدنی',
      failedConditions: ['مدتِ تاخیر ثمن'],
    );
    expect(chain.build(),
        'مقدمات: خریدار ثمن را نداده، مبیع تسلیم شده؛ قاعده: فروشندهٔ ثمن‌نگرفته (نامعلوم)؛ نتیجه: open؛ استناد: مادهٔ ۳۸۴ قانون مدنی؛ استثنا: مدتِ تاخیر ثمن');
  });

  test('زنجیرهٔ بی‌استثنا «—» می‌نویسد', () {
    final chain = CiteChain(
      facts: ['تهمت به دزدی'],
      rule: 'افتراء',
      standing: Standing.strong,
      citation: 'مادهٔ ۶۹۷ قانون مجازات اسلامی',
    );
    expect(chain.build(), contains('استثنا: —'));
    expect(chain.toLines().length, 5);
    expect(chain.toLines()[1], contains('برقرار'));
  });

  test('facts خالی با «—» نمایش داده می‌شود', () {
    final chain = CiteChain(
      facts: const [],
      rule: 'قاعده',
      standing: Standing.weak,
      citation: 'مادهٔ ۱۱۶۷ قانون مدنی',
    );
    expect(chain.build(), contains('مقدمات: —'));
    expect(chain.toLines()[0], 'مقدمات: —');
  });

  test('labelOf برای هر سه وضع درست است', () {
    expect(CiteChain.labelOf(Standing.strong), 'برقرار');
    expect(CiteChain.labelOf(Standing.open), 'نامعلوم');
    expect(CiteChain.labelOf(Standing.weak), 'نابرقرار');
  });
}

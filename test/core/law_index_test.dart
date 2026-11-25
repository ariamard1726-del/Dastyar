import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/law_index.dart';
import 'package:dastyar/core/models.dart';

/// ایندکسِ قوانین باید بدونِ فلاتر و بدونِ دارایی‌ها آزمون‌شدنی باشد. تا
/// دیروز خواندنِ متن و ساختنِ نمایه داخلِ `KnowledgeEngine` بود؛ آزمودنش
/// یعنی بالا آوردنِ `rootBundle` و کلِ بستهٔ قوانین.
void main() {
  const text = '# قانون کار\n'
      '\n'
      '## فصل اول\n'
      '\n'
      'ماده ۱\n'
      'کارگر کسی است که به هر عنوان در مقابل دریافت حق السعی کار می‌کند.\n';

  test('متن به بخش، فصل و ماده شکسته می‌شود', () {
    final out = <Chunk>[];
    final counts = <String, int>{};
    LawIndex.parseInto(text, 'پیش‌فرض', 'labor', out, counts);
    expect(out, hasLength(1));
    final c = out.single;
    expect(c.source, 'قانون کار');
    expect(c.chapter, 'فصل اول');
    expect(c.title, 'ماده ۱');
    expect(c.body, contains('کارگر'));
    expect(c.tfB, isNotEmpty);
    expect(counts['labor'], 1);
  });

  test('قاعدهٔ متنِ منسوخ', () {
    expect(LawIndex.isObsolete('منسوخ شد'), isTrue);
    expect(LawIndex.isObsolete('این ماده به قوت خود باقی است'), isFalse);
  });

  test('ساختنِ نمایه و یافتنِ ماده با شناسهٔ قانون', () {
    final built = LawIndex.build([
      ['labor', 'قانون کار', text],
    ]);
    final idx = LawIndex()..adopt(built);
    expect(idx.size, 1);
    expect(idx.lawCounts['labor'], 1);
    expect(idx.idf, isNotEmpty);
    expect(idx.postings, isNotEmpty);
    final c = idx.chunks.single;
    expect(idx.chunkOf('labor', c.title), 0);
    expect(idx.chunkOf('labor', 'ماده ۹۹۹'), isNull);
  });
}

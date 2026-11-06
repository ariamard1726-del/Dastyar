import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/search/retrieval_pipeline.dart';

void main() {
  String h(String q, double s, [String? t]) =>
      RetrievalPipeline.handleLowConfidenceRetrieval(q,
          similarity: s, candidateTopic: t);

  test('≥ ۰٫۶۵: رشتهٔ خالی', () {
    expect(h('سؤال', 0.65), '');
    expect(h('سؤال', 0.9, 'debt'), '');
  });

  test('< ۰٫۵۰: امتناع مؤدبانه و معرفی معاضدت کانون وکلا', () {
    final r = h('چیزی دربارهٔ قانون فضا', 0.3, 'debt');
    expect(r, contains('اطلاعات دقیق'));
    expect(r, contains('وکیل'));
    expect(r, contains('معاضدت کانون وکلا'));
    expect(r, isNot(contains('دعاوی مالی')));
    expect(h('x', double.nan), contains('معاضدت کانون وکلا'));
  });

  test('۰٫۵۰ تا ۰٫۶۵: پاسخ پل با خلاصهٔ استخراجی و موضوع', () {
    const q = 'سلام وقت بخیر. دوستم سال پیش ۵۰ میلیون تومان از من قرض گرفت و پس نمی‌دهد. چه کنم؟';
    final r = h(q, 0.55, 'debt');
    expect(r, contains('«دوستم سال پیش ۵۰ میلیون تومان از من قرض گرفت و پس نمی‌دهد»'));
    expect(r, contains('به نظر می‌رسد موضوع شما به دعاوی مالی مربوط است'));
    expect(r, contains('طرف مقابل'));
    expect(r, contains('مدرک'));
  });

  test('خلاصه فقط از کلمات خود کاربر است', () {
    const q = 'صاحبخانه ودیعه‌ام را پس نمی‌دهد، ولی قرارداد دارم';
    final s = RetrievalPipeline.extractiveSummary(q);
    expect(q, contains(s.replaceAll('…', '').trim()));
  });

  test('خلاصهٔ طولانی بریده می‌شود', () {
    final q = List.filled(30, 'چک').join(' ');
    final s = RetrievalPipeline.extractiveSummary(q);
    expect(s.endsWith('…'), isTrue);
    expect(s.split(' ').length, 20);
  });

  test('موضوع ناشناخته یا خالی: بدون نام موضوع', () {
    final r = h('دوستم پولم را نمی‌دهد', 0.6, 'xyz');
    expect(r, isNot(contains('به نظر می‌رسد')));
    expect(r, contains('جزئیات بیشتر'));
    expect(RetrievalPipeline.topicLabel('demand_money'), 'دعاوی مالی');
    expect(RetrievalPipeline.topicLabel(null), isNull);
  });
}

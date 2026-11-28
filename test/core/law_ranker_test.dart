import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/law_index.dart';
import 'package:dastyar/core/law_mention.dart';
import 'package:dastyar/core/law_ranker.dart';
import 'package:dastyar/core/models.dart';

/// امتیازدهی باید بدونِ بانکِ قوانین آزمون‌شدنی باشد. تا پیش از این، برای
/// سنجیدنِ «آیا مادهٔ درست بالا می‌آید؟» باید کلِ دارایی‌ها بارگذاری می‌شد و
/// آزمون به محتوای واقعیِ قوانین وابسته بود.
void main() {
  const rentText = '# قانون روابط موجر و مستاجر\n'
      '\n'
      'ماده ۱\n'
      'اگر مستاجر ودیعه را مطالبه کند و موجر ندهد، مستاجر می‌تواند تخلیه بخواهد.\n';
  const laborText = '# قانون کار\n'
      '\n'
      'ماده ۱\n'
      'کارگر کسی است که در مقابل حق السعی کار می‌کند.\n';

  LawIndex build() => LawIndex()
    ..adopt(LawIndex.build([
      ['rent', 'قانون روابط موجر و مستاجر', rentText],
      ['labor', 'قانون کار', laborText],
    ]));

  LawRanker rankerOf(LawIndex idx) => LawRanker(
        index: idx,
        mention: LawMention(
          catalog: [
            CatalogLaw('rent', 'قانون روابط موجر و مستاجر', 'c', 1, const []),
            CatalogLaw('labor', 'قانون کار', 'c', 1, const []),
          ],
          isLoaded: (_) => true,
        ),
        isLoaded: (_) => true,
        topicFactors: (_) => const {},
        expand: (_) => const [],
        synonyms: const [],
      );

  test('واژهٔ پرسش، مادهٔ درست را بالا می‌آورد', () {
    final idx = build();
    final r = rankerOf(idx).rank('ودیعه مستاجر', k: 3);
    expect(r.hits, isNotEmpty);
    expect(r.hits.first.chunk.lawId, 'rent');
    expect(r.hits.first.score, greaterThan(0));
  });

  test('بازرتبه‌بندی موضوع‌محور: قانون موضوع فقط در هم‌امتیازی نزدیک جلو می‌رود', () {
    Chunk mk(String law, String title) =>
        Chunk(law, 's', '', title, 'متن', false, const {}, const {}, const {}, 10);
    final outHit = Hit(mk('civil', 'ماده ۱۰۰'), 1.0);
    final inHit = Hit(mk('rent', 'ماده ۲۰۰'), 0.95); // ≥ 0.9 × 1.0 ⇒ جلو آمد
    final farHit = Hit(mk('labor', 'ماده ۳۰۰'), 0.5); // بقیه دست‌نخورده
    final res = LawRanker.topicRerank(
      [outHit, inHit, farHit],
      const {'rent': 1.4},
    );
    expect(res.map((h) => h.chunk.lawId), ['rent', 'civil', 'labor']);
  });

  test('بازرتبه‌بندی موضوع‌محور: قانون موضوع که خیلی عقب است جلو نمی‌آید', () {
    Chunk mk(String law) =>
        Chunk(law, 's', '', 't', 'متن', false, const {}, const {}, const {}, 10);
    final res = LawRanker.topicRerank(
      [Hit(mk('civil'), 1.0), Hit(mk('rent'), 0.80)],
      const {'rent': 1.4},
    );
    expect(res.first.chunk.lawId, 'civil');
  });

  test('بازرتبه‌بندی موضوع‌محور: نبود موضوع، ترتیب امروز را حفظ می‌کند', () {
    Chunk mk(String law) =>
        Chunk(law, 's', '', 't', 'متن', false, const {}, const {}, const {}, 10);
    final hits = [Hit(mk('civil'), 1.0), Hit(mk('rent'), 0.5)];
    expect(identical(LawRanker.topicRerank(hits), hits), isTrue);
    expect(LawRanker.topicRerank(hits, const {'labor': 0.45}).first.chunk.lawId,
        'civil');
  });

  test('پوشش: مادهٔ مربوط بیش از مادهٔ بی‌ربط واژه‌های پرسش را دارد', () {
    final idx = build();
    final rk = rankerOf(idx);
    final rent = idx.chunks.firstWhere((c) => c.lawId == 'rent');
    final labor = idx.chunks.firstWhere((c) => c.lawId == 'labor');
    expect(rk.coverage('ودیعه مستاجر', rent),
        greaterThan(rk.coverage('ودیعه مستاجر', labor)));
  });

  test('درخواستِ صریحِ ماده، همان ماده را با امتیازِ قطعی می‌دهد', () {
    final idx = build();
    final r = rankerOf(idx).rank('ماده ۱ قانون کار', k: 3);
    expect(r.hits, isNotEmpty);
    expect(r.hits.first.chunk.lawId, 'labor');
    expect(r.hits.first.score, greaterThanOrEqualTo(99));
  });
}

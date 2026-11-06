import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/lawyer/case_facts.dart';
import 'package:dastyar/domain/lawyer/case_reasoner.dart';
import 'package:dastyar/domain/lawyer/legal_guides.dart';
import 'package:dastyar/domain/lawyer/phrase_variator.dart';

LegalGuide guide(String id) => legalGuides.firstWhere((g) => g.id == id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    engine = KnowledgeEngine();
    await engine.load();
  });

  group('classify', () {
    const cases = <String, FollowUpKind>{
      'حالا چیکار کنم؟': FollowUpKind.whatNow,
      'باید اول چیکار کنم؟': FollowUpKind.whatNow,
      'کجا باید شکایت کنم؟': FollowUpKind.where,
      'هزینه‌اش چقدره؟': FollowUpKind.cost,
      'چقدر طول میکشه؟': FollowUpKind.duration,
      'مهلتش چقدره؟': FollowUpKind.deadline,
      'شانس دارم پولمو بگیرم؟': FollowUpKind.chance,
      'حق با منه؟': FollowUpKind.chance,
      'اگه انکار کنه چی؟': FollowUpKind.denial,
      'وکیل لازمه؟': FollowUpKind.lawyer,
      'چه مدارکی لازمه؟': FollowUpKind.evidenceNeeded,
      'آره': FollowUpKind.yes,
      'بله': FollowUpKind.yes,
      'نه': FollowUpKind.no,
      'نمیدونم': FollowUpKind.dontKnow,
      'نمي‌دونم': FollowUpKind.dontKnow,
    };
    cases.forEach((t, k) {
      test(t, () => expect(CaseReasoner.classify(t), k));
    });
    test('شرح ماجرا پرسش وابسته نیست', () {
      expect(CaseReasoner.classify('صاحبخونه ودیعه منو پس نمیده'), isNull);
      expect(CaseReasoner.classify(''), isNull);
    });
  });

  test('همهٔ ارجاع‌های استدلال در بانک قانون وجود دارد', () {
    for (final r in CaseReasoner.allPossibleRefs()) {
      expect(
        engine.findArticle(r.lawId, 'ماده ${r.article}'),
        isNotNull,
        reason: '${r.lawId} ${r.article}',
      );
    }
  });

  test('هر ارجاع پاسخ‌ها در فهرست ارجاع‌های مجاز است', () {
    final allowed =
        CaseReasoner.allPossibleRefs().map((r) => '${r.lawId}:${r.article}').toSet();
    final f = CaseFacts.extract(
        'قرارداد دارم و ۳۰۰ میلیون ودیعه دادم مدت قرارداد تموم شده گواهی عدم پرداخت گرفتم مقصر اون بود');
    for (final g in legalGuides) {
      for (final k in FollowUpKind.values) {
        final a = CaseReasoner.answer(k, g, f);
        expect(a.text.trim(), isNotEmpty, reason: '${g.id} $k');
        for (final r in a.refs) {
          expect(allowed, contains('${r.lawId}:${r.article}'),
              reason: '${g.id} $k');
        }
      }
    }
  });

  test('مرجع صالح با توجه به مبلغ و نصاب دادگاه صلح', () {
    final small = CaseReasoner.where(
        guide('debt_claim'), CaseFacts.extract('۲۰ میلیون قرض دادم'));
    expect(small.text, contains('دادگاه صلح'));
    expect(small.text, contains('بیشتر نیست'));
    final big = CaseReasoner.where(
        guide('debt_claim'), CaseFacts.extract('۵۰۰ میلیون تومان قرض دادم'));
    expect(big.text, contains('دادگاه عمومی حقوقی'));
    final labor = CaseReasoner.where(guide('unpaid_wages'), CaseFacts.empty);
    expect(labor.text, contains('ادارهٔ کار'));
    expect(labor.text, contains('۱۵۷'));
  });

  test('مهلت چک با وضعیت گواهی عدم پرداخت شخصی می‌شود', () {
    final no = CaseReasoner.deadline(guide('cheque_bounced'),
        CaseFacts.extract('هنوز گواهی عدم پرداخت نگرفتم'));
    expect(no.text, contains('شش ماه از تاریخ چک'));
    final yes = CaseReasoner.deadline(guide('cheque_bounced'),
        CaseFacts.extract('گواهی عدم پرداخت گرفتم'));
    expect(yes.text, contains('چون گواهی عدم پرداخت گرفته‌اید'));
    final unknown =
        CaseReasoner.deadline(guide('neighbor_damage'), CaseFacts.empty);
    expect(unknown.text, contains('مهلت مشخصی'));
  });

  test('انکار: ارزش واریز بانکی و بار اثبات', () {
    final a = CaseReasoner.denial(
        guide('debt_claim'), CaseFacts.extract('فقط کارت به کارت کردم'));
    expect(a.text, contains('بار اثبات'));
    expect(a.text, contains('واریز بانکی'));
  });

  test('ارزیابی شانس: نقاط قوت و ضعف', () {
    final a = CaseReasoner.chance(guide('deposit_return'),
        CaseFacts.extract('قرارداد دارم و مدت قرارداد تموم شده'));
    expect(a.text, contains('نقاط قوت'));
    expect(a.text, contains('قطعی'));
    final b = CaseReasoner.chance(guide('cheque_bounced'),
        CaseFacts.extract('هنوز گواهی عدم پرداخت نگرفتم'));
    expect(b.text, contains('بدون آن'));
  });

  test('پرسش بعدی فقط چیزهای نامعلوم را می‌پرسد', () {
    final g = guide('deposit_return');
    final q1 = CaseReasoner.nextQuestion(g, CaseFacts.empty)!;
    expect(q1.$1, contains('مبلغ ودیعه'));
    final q2 = CaseReasoner.nextQuestion(
        g, CaseFacts.extract('۳۰۰ میلیون ودیعه دادم'))!;
    expect(q2.$1, isNot(contains('مبلغ ودیعه')));
    final done = CaseReasoner.nextQuestion(
        g, CaseFacts.extract('۳۰۰ میلیون ودیعه، قرارداد دارم، مدت قرارداد تموم شده'));
    expect(done, isNull);
    final skipped = CaseReasoner.nextQuestion(g, CaseFacts.empty,
        skip: {'amount', CaseFlag.contractEnded});
    expect(skipped!.$1, contains('مدرک'));
  });

  test('قطعی بودن: یک ورودی همیشه یک خروجی', () {
    final f = CaseFacts.extract('قرارداد دارم');
    final a = CaseReasoner.answer(FollowUpKind.whatNow, guide('eviction'), f,
        v: PhraseVariator(seed: 3));
    final b = CaseReasoner.answer(FollowUpKind.whatNow, guide('eviction'), f,
        v: PhraseVariator(seed: 3));
    expect(a.text, b.text);
  });

  group('CaseFacts', () {
    test('parseToman', () {
      expect(CaseFacts.parseToman('۳۰۰ میلیون'), 300000000);
      expect(CaseFacts.parseToman('۲ میلیارد ریال'), 200000000);
      expect(CaseFacts.parseToman('بیست میلیون تومان'), 20000000);
      expect(CaseFacts.parseToman('۱۱۴ سکه'), isNull);
    });
    test('مبلغ با پسوند «ی»', () {
      expect(CaseFacts.extract('چک ۸۰ میلیونی برگشت خورده').amounts,
          isNotEmpty);
    });
    test('نفی: «اخراجم نکرده»', () {
      final f = CaseFacts.extract('دو ماهه حقوقمو نمیده ولی اخراجم نکرده');
      expect(f.has(CaseFlag.fired), isFalse);
      expect(f.denies(CaseFlag.fired), isTrue);
    });
    test('پاسخ کوتاه: مقصر و بیمه', () {
      expect(CaseFacts.extract('مقصر اون بود').has(CaseFlag.otherAtFault),
          isTrue);
      expect(CaseFacts.extract('بیمه داره').has(CaseFlag.hasInsurance), isTrue);
    });
    test('withFlag: بله/نه', () {
      final f = CaseFacts.empty.withFlag(CaseFlag.contractEnded, false);
      expect(f.denies(CaseFlag.contractEnded), isTrue);
      final g = f.withFlag(CaseFlag.contractEnded, true);
      expect(g.has(CaseFlag.contractEnded), isTrue);
      expect(g.denies(CaseFlag.contractEnded), isFalse);
    });
  });
}

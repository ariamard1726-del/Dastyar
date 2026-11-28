/// جدولِ سناریوهای رگرسیونِ پایهٔ بانک قوانین — هر ۲۴ قانون، هر کدام با یک
/// مادهٔ واقعی و شناخته‌شده.
///
/// تست `test/engine/law_regress_test.dart` این جدول را با `_meta.json` می‌سنجد:
/// هر شناسهٔ قانونی که از ردیف‌بندی جا بیفتد، تست قرمز می‌شود تا پوششِ ۱۰۰٪
/// به‌طور خودکار نگه داشته شود.
///
/// ماده‌ها از روی خودِ متونِ بسته‌بندی‌شده انتخاب شده‌اند؛ انتظارها در زمانِ
/// اجرا از خودِ فایل استخراج می‌شود، پس بازنگریِ رسمیِ متن‌ها این تست را نمی‌شکند.
library;

class LawRegressCase {
  final String lawId;
  final int article;

  const LawRegressCase(this.lawId, this.article);
}

const List<LawRegressCase> kLawRegressCases = [
  LawRegressCase('civil', 10),
  LawRegressCase('family_protection', 22),
  LawRegressCase('civil_liability', 1),
  LawRegressCase('child_protection', 1),
  LawRegressCase('marriage', 1),
  LawRegressCase('penal', 305),
  LawRegressCase('penal_taazirat', 674),
  LawRegressCase('fraud_intensify', 1),
  LawRegressCase('cybercrime', 13),
  LawRegressCase('civil_procedure', 306),
  LawRegressCase('criminal_procedure', 1),
  LawRegressCase('civil_execution', 1),
  LawRegressCase('financial_sentences', 3),
  LawRegressCase('dispute_councils', 1),
  LawRegressCase('cheque', 9),
  LawRegressCase('commerce', 1),
  LawRegressCase('commerce_1347', 1),
  LawRegressCase('consumer_protection', 1),
  LawRegressCase('registration', 70),
  LawRegressCase('landlord_tenant', 1),
  LawRegressCase('labor', 7),
  LawRegressCase('social_security', 2),
  LawRegressCase('direct_taxes', 1),
  LawRegressCase('constitution', 22),
];

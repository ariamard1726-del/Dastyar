part of 'advocate.dart';

// جدول‌های دادهٔ وکیل: نگاشتِ شبکهٔ نیت، آستانهٔ پذیرشِ حدس، و ترتیبِ مسیرهای
// پاسخ.
//
// هیچ‌کدام رفتار نیستند، ولی `pipelineOrder` **ترتیبش** رفتار است (ایمنی پیش از
// موضوع، شبکهٔ نیت پس از راهنما)؛ برای همین در فایلِ خودش نشسته و آزمون ترتیبش
// را حرف‌به‌حرف می‌سنجد. عوض کردنِ یک ردیف این‌جا باید آگاهانه باشد، نه در
// میانهٔ یک تغییرِ بی‌ربط.

/// برچسب‌های طبقه‌بند که موضوعِ هم‌معنا در [topics] دارند.
const Map<String, String> netTopics = {
  'cheque': 'cheque',
  'debt': 'debt',
  'family': 'family',
  'labor': 'labor',
  'lease': 'rent',
  'fraud_cyber': 'cyber',
};

/// کمترین اطمینانی که نظر طبقه‌بند با آن پذیرفته می‌شود.
const double netMin = 0.6;

/// ترتیب اولویت مسیرهای دانش، همان‌طور که در [respond] اجرا می‌شود.
///
/// این فهرست «قرارداد» است، نه تزئین: هر مسیر تازه باید جای خودش را در
/// همین فهرست بگیرد و `test/advocate/answer_source_test.dart` هر پاسخ را
/// با برچسب [AdvocateReply.source] می‌سنجد. تغییر ترتیب = تغییر رفتار،
/// پس تغییرش باید همراه با به‌روزکردن همین فهرست و آزمون باشد.
const List<AnswerSource> pipelineOrder = [
  AnswerSource.safety,
  AnswerSource.topic,
  AnswerSource.lawTerms,
  AnswerSource.glossary,
  AnswerSource.guide,
  AnswerSource.topicFlow,
  AnswerSource.guess,
  AnswerSource.intentNet,
  AnswerSource.qaBank,
  AnswerSource.engine,
];

/// دسته‌های خوانندهٔ موضوع → موضوع‌های هم‌معنا در [topics] به ترتیب
/// اولویت. دسته‌های crime، general، chat و other پرونده‌ای ندارند و با
/// آن‌ها وکیل مثل قبل رفتار می‌کند.
const Map<String, List<String>> guessTopics = {
  'rent': ['rent'],
  'cheque': ['cheque'],
  'debt': ['debt', 'enforce'],
  'labor': ['labor'],
  'family': ['family', 'child'],
  'accused': ['accused'],
  'injury': ['injury'],
  'neighbor': ['neighbor'],
  'consumer': ['consumer'],
  'cyber': ['cyber'],
  'inherit': ['inherit'],
  'property': ['property'],
  'company': ['company', 'partner'],
  'guarantee': ['guarantee'],
  'admin': ['admin'],
};

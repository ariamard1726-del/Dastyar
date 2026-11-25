import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/domain/advocate/advocate.dart';

/// ابزارِ آزمون ساختاری: مسیر دانش و قرارداد پاسخ را میسنجد، نه جملهٔ دقیقش را.
/// جایگزینِ تدریجیِ `expect(r.text, contains('...'))` است وقتی آنچه واقعاً مهم است
/// «از کدام مسیر آمد»، «چه دکمهای دارد» یا «موضوع پرونده» باشد.
void expectSource(AdvocateReply r, AnswerSource source) {
  expect(r.source, source, reason: 'مسیر پاسخ: ${r.text}');
}

void expectChip(AdvocateReply reply, String chip) {
  expect(reply.chips, contains(chip), reason: 'دکمهها: ${reply.chips}');
}

void expectNoChip(AdvocateReply reply, String chip) {
  expect(reply.chips, isNot(contains(chip)), reason: 'دکمهها: ${reply.chips}');
}

void expectTopic(Advocate advocate, String topic) {
  expect(advocate.file.topic, topic);
}

void expectCited(AdvocateReply reply) {
  expect(reply.laws, isNotEmpty, reason: 'پاسخ مستند به متن قانون نیست');
}

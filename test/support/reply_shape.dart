import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/domain/advocate/advocate.dart';

/// ابزارِ آزمون ساختاری: مسیر دانش و قرارداد پاسخ را میسنجد، نه جملهٔ دقیقش را.
/// جایگزینِ بررسیهای متنی پراکنده است وقتی آنچه واقعاً مهم است
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

void expectNoText(AdvocateReply reply, String fragment) {
  final hasFragment = reply.text.contains(fragment);
  expect(hasFragment, isFalse,
      reason: 'متن پاسخ نباید حاوی «$fragment» باشد: ${reply.text}');
}

void expectDecisionName(Advocate advocate, String name) {
  expect(advocate.lastDecision?.candidate.name, name,
      reason: 'مسیر برنده: ${advocate.lastDecision?.candidate.name}');
}

void expectSourceIn(AdvocateReply reply, Set<AnswerSource> sources) {
  expect(sources.contains(reply.source), isTrue,
      reason: 'مسیر پاسخ: ${reply.source}');
}

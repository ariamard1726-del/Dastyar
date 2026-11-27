part of 'labor.dart';

// متنِ پاسخ‌ها: پول، خواسته‌ها، طرحِ دعوا و شانس.

String _laborMoney(CaseFile f) {
  final months = f.n('months');
  final sal = f.n('salary');
  if (months == null || sal == null) {
    final need = months == null && sal == null
        ? topicText('laborBod_0')
        : (months == null ? topicText('laborBod_1') : topicText('laborBod_2'));
    return topicText('laborMoneyAskA') + ' ' + need + ' ' + topicText('laborMoneyAskB');
  }
  final years = months / 12.0;
  final san = (sal * years).round();
  final alt = (sal * 1.5 * years).round();
  final sb = StringBuffer(
      topicText('laborMoneySumA') + ' ' + Sense.span(months) + ' ' + topicText('laborMoneySumB') + ' ' + Sense.toman(sal) + topicText('laborMoneySumC') + '\n' + topicText('laborMoneySumD') + ' ' + Sense.toman(san) + ' ' + topicText('laborMoneySumE'));
  if (laborFired(f)) {
    sb.write(
        '\n' + topicText('laborMoneyFiredA') + ' ' + Sense.toman(alt) + ' ' + topicText('laborMoneyFiredB') + '\n' + topicText('laborMoneyFiredC'));
  }
  sb.write(
      '\n' + topicText('laborMoneyTail'));
  return sb.toString();
}

/// خواسته‌هایی که با واقعیت‌های همین پرونده جا دارد در دادخواست بیاید؛
/// ادعایی که شرطش برقرار نیست (مثل سنوات وقتی هنوز سر کارید) نمی‌آید.
String _laborDemands(CaseFile f) {
  final out = <String>[];
  for (final v in Reasoner.assess(laborTopic, f)) {
    if (v.standing == Standing.weak) continue;
    final l = v.claim.label;
    if (l.isEmpty) continue;
    out.add(l == topicText('laborClaimFiredLabel') ? topicText('laborBod_3') : l);
  }
  out.add(topicText('laborBod_4'));
  return out.join(topicText('laborDemandsSep'));
}

String _laborPlan(CaseFile f) {
  final first = laborFired(f)
      ? topicText('laborBod_5')
      : topicText('laborBod_6');
  return topicText('laborPlanLead') + '\n' + first + topicText('laborPlanS2') + '\n' + topicText('laborPlanS3A') + ' ' + _laborDemands(f) + '.\n' + topicText('laborPlanS4') + '\n' + topicText('laborPlanS5');
}

String _laborChance(CaseFile f) {
  final plus = <String>[];
  final minus = <String>[];
  final m = f.n('months');
  if (m != null && m >= 12) plus.add(topicText('laborChanceSpanA') + ' ' + Sense.span(m) + ' ' + topicText('laborChanceSpanB'));
  if (f.yes('contract')) plus.add(topicText('laborBod_7'));
  if (f.yes('insured')) plus.add(topicText('laborBod_8'));
  if (f.no('contract')) minus.add(topicText('laborBod_9'));
  if (f.no('insured')) minus.add(topicText('laborBod_10'));
  final sb = StringBuffer(
      topicText('laborBod_11'));
  if (plus.isNotEmpty) sb.write('\n' + topicText('laborChancePlusLead') + ' ' + plus.join(topicText('laborChancePlusSep')) + '.');
  if (minus.isNotEmpty) {
    sb.write('\n' + topicText('laborChanceMinusLead') + ' ' + minus.join(topicText('laborChanceMinusSep')) + topicText('laborChanceMinusTail'));
  }
  sb.write('\n' + topicText('laborChanceTail'));
  return sb.toString();
}

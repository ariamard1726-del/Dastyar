part of 'family.dart';

// متنِ پاسخ‌ها: ایمنی، مهریه، حضانت و طلاق.

String _famSafety(CaseFile f) =>
    topicText('familySafetyTopA') + (f.has('childAge') ? ' ' + topicText('familySafetyChild') : '') + ' ' + topicText('familySafetyTopB') + '\n' + topicText('familySafetyRest');

String _famMehr(CaseFile f) {
  if (f.eq('role', 'husband')) {
    return topicText('familyBod_0');
  }
  final coins = f.n('coins');
  final sb = StringBuffer(
      topicText('familyBod_1'));
  if (coins != null) {
    sb.write(coins > 110 ? '\n' + topicText('familyMehrOverA') + ' ' + Sense.fa(coins) + ' ' + topicText('familyMehrOverB') + ' ' + Sense.fa(coins - 110) + ' ' + topicText('familyMehrOverC') : '\n' + topicText('familyMehrUnderA') + ' ' + Sense.fa(coins) + ' ' + topicText('familyMehrUnderB'));
  }
  return sb.toString();
}

String _famCustody(CaseFile f) {
  final age = f.n('childAge');
  final sb = StringBuffer();
  if (age != null && age < 7) {
    sb.write(topicText('familyCustYoungA') + ' ' + Sense.fa(age) + ' ' + topicText('familyCustYoungB') + ' ' + (f.eq('role', 'husband') ? topicText('familyCustMother') : topicText('familyCustYou')) + ' ' + topicText('familyCustEst'));
  } else if (age != null) {
    sb.write(topicText('familyCustYoungA') + ' ' + Sense.fa(age) + ' ' + topicText('familyCustOldB'));
  } else {
    sb.write(
        topicText('familyBod_2'));
  }
  sb.write(topicText('familyBod_3'));
  if (f.yes('violence') && !f.eq('role', 'husband')) {
    sb.write(topicText('familyBod_4'));
  }
  return sb.toString();
}

String _famDivorce(CaseFile f) {
  if (f.eq('role', 'husband')) {
    return topicText('familyBod_5');
  }
  return topicText('familyDivorceWays') + '\n' + (f.yes('violence') ? topicText('familyDivorceVYes') : topicText('familyDivorceVNo'));
}

part of 'rent.dart';

// متنِ پاسخِ موضوع‌های اجاره — سمتِ مستأجر و متن‌های مشترک.
// متنهای ثابت از `rent_texts.json` میآیند (`rentText(id)`)؛ تابعهایی که
// پرونده را میخوانند، جملهٔ مناسب را از همانجا میگیرند و با وضعیت پرونده
// ترکیب میکنند. هیچ تصمیمی اینجا گرفته نمیشود. متنهای سمتِ موجر در
// `rent_bodies_landlord.dart`اند.

String _rentPeace() => rentText('rentPeace');

String _rentDepositLaw() => rentText('rentDepositLaw');

String _rentRaiseBody(CaseFile f) {
  final base = rentText('bodyRaiseBase');
  if (f.no('ended')) {
    return base + rentText('bodyRaiseRet00');
  }
  final after = rentText('bodyRaiseAfter');
  if (f.yes('ended')) {
    return rentText('bodyRaiseRet10') + after + rentText('bodyRaiseRet11');
  }
  return base + rentText('bodyRaiseRet20') + after;
}

String _rentRepairBody() => rentText('rentRepairBody');

String _rentDamageBody(CaseFile f) {
  final tail = f.yes('vacated') ? rentText('bodyDamageVacated') : rentText('bodyDamageAccess');
  // «این حرف را زیاد می‌شنوم؛ خوشبختانه…»: دستیار تجربهٔ زیسته ندارد که
  // «زیاد بشنود»، و «خوشبختانه» برای کسی که پولش را نگه داشته‌اند دلداریِ
  // دروغ است. جای هر دو، گفتنِ همان چیزی است که واقعاً می‌دانیم.
  return rentText('bodyDamageRet0') + tail;
}

String _rentEvictBody() => rentText('rentEvictBody');

String _rentOrderBody(CaseFile f) {
  final lead = f.no('ended') ? rentText('bodyOrderNotEnded') : rentText('bodyOrderEnded');
  return lead + rentText('bodyOrderRet0');
}

String _rentOrderDepositBody() => rentText('rentOrderDepositBody');

String _rentAccessBody() => rentText('rentAccessBody');

String _rentSelfRepairBody() => rentText('rentSelfRepairBody');

String _rentDefectBody() => rentText('rentDefectBody');

String _rentGuaranteeBody() => rentText('rentGuaranteeBody');

String _rentBillsBody() => rentText('rentBillsBody');

String _rentLateBody() => rentText('rentLateBody');

String _rentLeaveBody() => rentText('rentLeaveBody');

String _rentRenewBody() => rentText('rentRenewBody');

String _rentHandoverBody() => rentText('rentHandoverBody');

String _rentUnpaidBody(CaseFile f) =>
    rentText(f.eq('aim', 'evict') ? 'bodyUnpaidEvict' : 'bodyUnpaidOther');

String _rentEarlyBody() => rentText('rentEarlyBody');

String _rentGoneBody() => rentText('rentGoneBody');

String _rentNoMoneyBody(CaseFile f) {
  final key = f.yes('vacated') ? '' : rentText('bodyNoMoneyKey');
  return rentText('bodyNoMoneyLead') + key;
}

String _rentBeforeEnd() => rentText('rentBeforeEnd');

String _rentAfterEnd() => rentText('rentAfterEnd');

String _rentFixSelfBody() => rentText('rentFixSelfBody');

String _rentBlameBody() => rentText('rentBlameBody');

String _rentImproveBody() => rentText('rentImproveBody');

String _rentPartialBody() => rentText('rentPartialBody');

String _rentDeliverBody() => rentText('rentDeliverBody');

String _rentThirdBody() => rentText('rentThirdBody');

String _rentPenaltyBody(CaseFile f) {
  final mid = rentText(
      f.eq('role', 'landlord') ? 'bodyPenaltyLandlord' : 'bodyPenaltyTenant');
  return rentText('bodyPenaltyBase') + mid + rentText('bodyPenaltyNone');
}

Prompt? _rentAskReply(CaseFile f) {
  // برگهٔ دادگاه آمده؛ حرفِ موجر دیگر چیزی را عوض نمی‌کند.
  if (_ordered(f)) return Prompt.none;
  if (f.eq('role', 'tenant')) {
    if (f.eq('matter', 'deposit')) {
      return Prompt(rentText('promptTenantDepositQ'), [
        rentText('promptTenantDepositC0'),
        rentText('promptTenantDepositC1'),
        rentText('promptTenantDepositC2'),
        rentText('promptTenantDepositC3'),
      ]);
    }
    if (f.eq('matter', 'evict')) {
      return Prompt(rentText('promptTenantEvictQ'), [
        rentText('promptTenantEvictC0'),
        rentText('promptTenantEvictC1'),
        rentText('promptTenantEvictC2'),
        rentText('promptTenantEvictC3'),
      ]);
    }
    if (f.eq('matter', 'repair')) {
      return Prompt(rentText('promptTenantRepairQ'), [
        rentText('promptTenantRepairC0'),
        rentText('promptTenantRepairC1'),
        rentText('promptTenantRepairC2'),
      ]);
    }
    // در بالابردن اجاره و زودتر رفتن، حرفِ موجر خودِ ماجراست و پرسیده شده.
    if (f.eq('matter', 'raise') || f.eq('matter', 'leave')) return Prompt.none;
    return null;
  }
  if (f.eq('aim', 'evict')) {
    return Prompt(rentText('promptLandlordEvictQ'), [
      rentText('promptLandlordEvictC0'),
      rentText('promptLandlordEvictC1'),
      rentText('promptLandlordEvictC2'),
      rentText('promptLandlordEvictC3'),
    ]);
  }
  if (f.eq('aim', 'unpaid')) {
    return Prompt(rentText('promptLandlordUnpaidQ'), [
      rentText('promptLandlordUnpaidC0'),
      rentText('promptLandlordUnpaidC1'),
      rentText('promptLandlordUnpaidC2'),
      rentText('promptLandlordUnpaidC3'),
    ]);
  }
  if (f.eq('aim', 'damage')) {
    return Prompt(rentText('promptLandlordDamageQ'), [
      rentText('promptLandlordDamageC0'),
      rentText('promptLandlordDamageC1'),
      rentText('promptLandlordDamageC2'),
    ]);
  }
  return null;
}

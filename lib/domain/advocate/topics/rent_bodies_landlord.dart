part of 'rent.dart';

// متن‌های سمتِ موجر: تخلیه، سرقفلی، فروشِ ملک، فوتِ موجر، تغییرِ کاربری و…
// متنهای ثابت از `rent_texts.json` میآیند؛ تابعهای وابسته به پرونده در
// همین فایل میمانند. جدا کردنِ فایل فقط برای خواندنِ آسانتر است.

String _rentSubletBody(CaseFile f) => rentText(
    f.eq('role', 'landlord') ? 'bodySubletLandlord' : 'bodySubletTenant');

String _rentSoldBody(CaseFile f) =>
    rentText(f.eq('role', 'landlord') ? 'bodySoldLandlord' : 'bodySoldTenant');

String _rentDeathBody(CaseFile f) =>
    rentText('bodyDeathBase') +
    rentText(
        f.eq('role', 'landlord') ? 'bodyDeathLandlord' : 'bodyDeathTenant');

String _rentGoodwillBody() => rentText('rentGoodwillBody');

String _rentUsageBody(CaseFile f) =>
    rentText('bodyUsageBase') +
    rentText(
        f.eq('role', 'landlord') ? 'bodyUsageLandlord' : 'bodyUsageTenant');

String _rentCodeBody() => rentText('rentCodeBody');

String _rentSelfHelpBody() => rentText('rentSelfHelpBody');

String _rentLandlordDepositBody() => rentText('rentLandlordDepositBody');

String _rentLandlordDamageBody() => rentText('rentLandlordDamageBody');

String _rentLandlordRaiseBody() => rentText('rentLandlordRaiseBody');

String _rentLandlordBillsBody() => rentText('rentLandlordBillsBody');

String _rentMisuseBody() => rentText('rentMisuseBody');

String _rentObjectBody() => rentText('rentObjectBody');

String _rentWaitNewBody() => rentText('rentWaitNewBody');

String _rentSilentBody(CaseFile f) {
  if (f.eq('role', 'landlord')) {
    final order = f.no('ended') ? '' : rentText('bodySilentLandlordOrder');
    return rentText('bodySilentLandlordA') +
        order +
        rentText('bodySilentLandlordB');
  }
  final key = f.no('vacated') ? rentText('bodySilentTenantKey') : '';
  return rentText('bodySilentTenantA') + key + rentText('bodySilentTenantB');
}

String _rentOwnUseBody(CaseFile f) {
  final deal = rentText('bodyOwnUseDeal');
  final lead = rentText('bodyOwnUseLead');
  if (f.no('ended')) return lead + ' ' + _rentBeforeEnd() + '\n' + deal;
  if (f.yes('ended')) {
    return rentText('bodyOwnUseEnded') + _rentAfterEnd();
  }
  return lead +
      rentText('bodyOwnUseMid1') +
      _rentBeforeEnd() +
      rentText('bodyOwnUseMid2') +
      _rentAfterEnd() +
      '\n' +
      deal;
}

String _rentNoReasonBody(CaseFile f) {
  final ask = rentText('bodyNoReasonAsk');
  if (f.no('ended')) {
    return rentText('bodyNoReasonBefore') + _rentBeforeEnd() + '\n' + ask;
  }
  if (f.yes('ended')) {
    return rentText('bodyNoReasonEnded') + _rentAfterEnd();
  }
  return rentText('bodyNoReasonMid1') +
      _rentBeforeEnd() +
      rentText('bodyNoReasonMid2') +
      _rentAfterEnd() +
      '\n' +
      ask;
}

String _rentNoTermBody(CaseFile f) =>
    rentText('bodyNoTermBase') +
    rentText(
        f.eq('role', 'landlord') ? 'bodyNoTermLandlord' : 'bodyNoTermTenant');

String _rentLandlordNoPlaceBody(CaseFile f) => rentText(f.no('ended')
    ? 'bodyLandlordNoPlaceNotEnded'
    : 'bodyLandlordNoPlaceEnded');

String _rentLandlordDepFirstBody() => rentText('rentLandlordDepFirstBody');

String _rentLandlordOffsetBody() => rentText('rentLandlordOffsetBody');

String _rentLandlordRenewedBody() => rentText('rentLandlordRenewedBody');

String _rentLandlordWearBody() => rentText('rentLandlordWearBody');

String _rentLandlordCantPayBody() => rentText('rentLandlordCantPayBody');

String _rentLandlordPaidBody() => rentText('rentLandlordPaidBody');

String _rentLandlordBuiltBody() => rentText('rentLandlordBuiltBody');

String _rentLandlordGuarantorBody() => rentText('rentLandlordGuarantorBody');

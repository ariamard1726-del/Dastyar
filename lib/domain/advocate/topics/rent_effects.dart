part of 'rent.dart';

// اثرِ حقوقیِ واقعیت‌ها در موضوعِ اجاره: چه چیزی از این حرف‌ها نتیجه می‌شود.
//
// این تنها فایلِ اجاره است که متنِ «اثر» می‌سازد؛ پرسش‌ها (`rent_slots.dart`)،
// بحث‌ها (`rent_issue_*.dart`) و متنِ پاسخ (`rent_bodies*.dart`) جای خودشان را
// دارند. جدا بودنشان یعنی عوض کردنِ یک اثر، فهرستِ بحث‌ها را جابه‌جا نکند.

String _aimEffect(CaseFile f) {
  if (!f.eq('role', 'landlord')) return '';
  switch (f.get('aim')) {
    case 'evict':
      return rentText('effectAimEvict');
    case 'unpaid':
      return rentText('effectAimUnpaid');
    case 'damage':
      return rentText('effectAimDamage');
    case 'breach':
      return rentText('effectAimBreach');
  }
  return '';
}

String _endedEffect(CaseFile f) {
  final landlord = f.eq('role', 'landlord');
  final other = f.eq('role', 'tenant') && !_rentDeposit(f);
  if (_ordered(f)) {
    return f.yes('ended')
        ? rentText('effectEndedOrderedYes')
        : rentText('effectEndedOrderedNo');
  }
  if (f.yes('ended')) {
    if (landlord) {
      return rentText('effectEndedYesLandlord');
    }
    if (other) {
      return rentText('effectEndedYesOther');
    }
    return rentText('effectEndedYesDeposit');
  }
  if (landlord) {
    return rentText('effectEndedNoLandlord');
  }
  if (other) {
    return rentText('effectEndedNoOther');
  }
  return rentText('effectEndedNoDeposit');
}

String _contractEffect(CaseFile f) {
  if (f.yes('contract')) {
    if (f.eq('role', 'landlord')) {
      if (!_evicting(f)) {
        return rentText('effectContractYesNotEvict');
      }
      final ready = f.yes('ended')
          ? rentText('effectContractYesEvictReady')
          : '';
      return rentText('effectContractYesEvict') + ready;
    }
    return _rentDeposit(f)
        ? rentText('effectContractYesTenantDep')
        : rentText('effectContractYesTenantOther');
  }
  if (f.eq('role', 'landlord')) {
    return rentText('effectContractNoLandlord');
  }
  return f.eq('role', 'tenant') && !_rentDeposit(f)
      ? rentText('effectContractNoTenantOther')
      : rentText('effectContractNoTenantDep');
}

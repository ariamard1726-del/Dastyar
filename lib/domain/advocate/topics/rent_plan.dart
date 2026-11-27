part of 'rent.dart';

// نقشهٔ راه: طرحِ دعوا، مدرک، شانس، مهلت و جمع‌بندی.

String _rentPlan(CaseFile f) {
  final sum = _rentSum(f);
  if (f.eq('role', 'landlord')) {
    if (f.eq('aim', 'unpaid')) {
      return rentText('plan0') + moneyForum(sum);
    }
    if (f.eq('aim', 'damage')) {
      return rentText('plan1') + moneyForum(sum);
    }
    if (f.eq('aim', 'breach')) {
      return rentText('plan2');
    }
    if (f.no('ended')) {
      return rentText('plan3');
    }
    return rentText('plan4');
  }
  if (f.eq('matter', 'raise')) {
    return rentText('plan5');
  }
  if (_ordered(f)) {
    return rentText('plan6');
  }
  if (f.eq('matter', 'evict')) {
    return rentText('plan7');
  }
  if (f.eq('matter', 'deliver')) {
    return rentText('plan8') + _rentPeace();
  }
  if (f.eq('matter', 'repair')) {
    return rentText('plan9');
  }
  if (f.eq('matter', 'leave')) {
    return rentText('plan10');
  }
  if (f.no('vacated')) {
    return rentText('plan11');
  }
  return rentText('plan12') + moneyForum(sum);
}

String _rentEvidence(CaseFile f) {
  if (f.eq('role', 'landlord')) {
    return rentText('plan30');
  }
  if (!_rentDeposit(f)) {
    return rentText('plan31');
  }
  final sb = StringBuffer(rentText('plan32'));
  if (f.no('contract')) {
    sb.write(rentText('plan33'));
  }
  return rentText('plan32');
}

String _rentChance(CaseFile f) {
  final lead = rentText('planLead');
  if (f.eq('role', 'landlord')) {
    if (f.eq('aim', 'unpaid')) {
      return lead + rentText('plan19');
    }
    if (f.eq('aim', 'damage')) {
      return lead + rentText('plan20');
    }
    if (f.eq('aim', 'breach')) {
      return lead + rentText('plan21');
    }
    return lead + rentText('plan22');
  }
  if (f.eq('matter', 'raise')) {
    return lead + rentText('plan23');
  }
  if (_ordered(f)) {
    return lead + rentText('plan24');
  }
  if (f.eq('matter', 'evict')) {
    return lead + rentText('plan25');
  }
  if (f.eq('matter', 'deliver')) {
    return lead + rentText('plan26');
  }
  if (f.eq('matter', 'repair')) {
    return lead + rentText('plan27');
  }
  if (f.eq('matter', 'leave')) {
    return lead + rentText('plan28');
  }
  final plus = <String>[];
  final minus = <String>[];
  if (f.yes('vacated')) {
    plus.add(rentText('recapChanceVacated'));
  }
  if (f.yes('ended')) plus.add(rentText('recapChanceEnded'));
  if (f.yes('contract')) plus.add(rentText('recapChanceContract'));
  if (f.no('contract')) {
    minus.add(
        rentText('recapChanceNoContract'));
  }
  if (f.no('ended')) minus.add(rentText('recapChanceNotEnded'));
  if (f.covered.contains('damage')) {
    minus.add(
        rentText('recapChanceDamage'));
  }
  final sb = StringBuffer(
      rentText('recapChanceBase'));
  if (plus.isNotEmpty) sb.write('\n' + rentText('recapChancePlus') + ' ' + plus.join(rentText('recapChanceSep')) + '.');
  if (minus.isNotEmpty) sb.write('\n' + rentText('recapChanceMinus') + ' ' + minus.join(rentText('recapChanceSep')) + '.');
  if (plus.isEmpty && minus.isEmpty) {
    sb.write(
        '\n' + rentText('recapChanceNeutral'));
  }
  return sb.toString();
}

String _rentWhere(CaseFile f) {
  if (f.eq('role', 'landlord')) {
    if (f.eq('aim', 'unpaid') || f.eq('aim', 'damage')) {
      return moneyForum(_rentSum(f));
    }
    return rentText('recapWhereLandlordEvict');
  }
  if (_shop(f) && f.covered.contains('goodwill')) {
    return rentText('recapWhereGoodwill');
  }
  return _rentDeposit(f) ? moneyForum(f.n('amount')) : _rentPeace();
}

String _rentDeadline(CaseFile f) {
  if (_ordered(f)) {
    return rentText('plan13');
  }
  if (f.eq('role', 'landlord')) {
    return rentText('plan14');
  }
  return rentText('plan15');
}

String _rentRefuse(CaseFile f) {
  if (f.eq('role', 'landlord')) {
    if (f.eq('aim', 'unpaid') || f.eq('aim', 'damage')) {
      return rentText('plan16');
    }
    return rentText('plan17');
  }
  if (!_rentDeposit(f)) {
    return rentText('plan34_a') + _rentPeace() + rentText('plan34_b');
  }
  return rentText('plan18');
}

// ============================================================ برداشت وکیل

List<String> rentRecap(CaseFile f) {
  final tenant = f.eq('role', 'tenant');
  final landlord = f.eq('role', 'landlord');
  final sum = _rentSum(f);
  return [
    if (landlord) rentText('recapLandlord'),
    if (tenant) rentText('recapTenant'),
    if (_shop(f)) rentText('recapShop'),
    if (_matter(f, 'deposit')) rentText('recapMatterDeposit'),
    if (_matter(f, 'raise')) rentText('recapMatterRaise'),
    if (_matter(f, 'evict')) rentText('recapMatterEvict'),
    if (_matter(f, 'order')) rentText('recapMatterOrder'),
    if (_matter(f, 'repair')) rentText('recapMatterRepair'),
    if (_matter(f, 'leave')) rentText('recapMatterLeave'),
    if (_matter(f, 'deliver')) rentText('recapMatterDeliver'),
    if (_matter(f, 'evict') && f.yes('official')) rentText('recapOfficialYes'),
    if (_matter(f, 'evict') && f.no('official'))
      rentText('recapOfficialNo'),
    if (_aim(f, 'evict')) rentText('recapAimEvict'),
    if (_aim(f, 'evict') && f.yes('owes')) rentText('recapAimEvictOwes'),
    if (_aim(f, 'unpaid')) rentText('recapAimUnpaid'),
    if (_aim(f, 'damage')) rentText('recapAimDamage'),
    if (_aim(f, 'breach')) rentText('recapAimBreach'),
    if (f.yes('ended')) rentText('recapEndedYes'),
    if (f.no('ended')) rentText('recapEndedNo'),
    if (!landlord && f.yes('vacated')) rentText('recapVacatedYes'),
    if (!landlord && f.no('vacated')) rentText('recapVacatedNo'),
    if (!landlord && f.n('amount') != null)
      rentText('recapAmountPrefix') + ' ' + Sense.toman(f.n('amount')!) + ' ' + rentText('recapAmountSuffix'),
    if (landlord && sum != null) rentText('recapSumPrefix') + ' ' + Sense.toman(sum) + ' ' + rentText('recapSumSuffix'),
    if (f.yes('contract')) rentText('recapContractYes'),
    if (f.no('contract')) rentText('recapContractNo'),
    if (landlord && f.yes('witness')) rentText('recapWitnessYes'),
    if (landlord && f.no('witness')) rentText('recapWitnessNo'),
    if (landlord && f.yes('clause')) rentText('recapClauseYes'),
    if (landlord && f.no('clause')) rentText('recapClauseNo'),
    if (landlord && f.has('aim') && f.yes('proof')) rentText('recapProofYes'),
    if (landlord && f.has('aim') && f.no('proof'))
      rentText('recapProofNo'),
    if (_matter(f, 'repair') && f.yes('told'))
      rentText('recapToldYes'),
    if (_matter(f, 'repair') && f.no('told'))
      rentText('recapToldNo'),
    if (_matter(f, 'leave') && f.yes('consent')) rentText('recapConsentYes'),
    if (_matter(f, 'leave') && f.no('consent'))
      rentText('recapConsentNo'),
  ];
}

// ================================================================ ادعاها

part of 'rent.dart';

// متنِ پیشنهادی برای فیلدهای دادخواست و لایحه.

Map<String, String> _rentFill(CaseFile f, String template) {
  final landlord = f.eq('role', 'landlord');
  final sum = _rentSum(f);
  final out = <String, String>{};
  final papers = <String>[
    if (f.yes('contract')) rentText('fillPaperContract'),
    if (f.yes('witness')) rentText('fillPaperWitness'),
  ];
  switch (template) {
    case 'demand_money':
      if (f.has('contract')) {
        out['basis'] =
            f.yes('contract') ? 'سند عادی (رسید یا قرارداد)' : 'سایر';
      }
      if (landlord && f.eq('aim', 'damage')) {
        out['basis_detail'] =
            rentText('fillDmDamageDetail');
        out['evidence'] = _list([
          ...papers,
          rentText('fillDmDamageEv0'),
          rentText('fillDmDamageEv1'),
          rentText('fillDmDamageEv2'),
        ]);
      } else if (landlord) {
        out['basis_detail'] =
            rentText('fillDmUnpaidDetail');
        out['evidence'] = _list([
          ...papers,
          rentText('fillDmUnpaidEv0'),
          rentText('fillDmUnpaidEv1'),
        ]);
      } else {
        final sb = StringBuffer(
            rentText('fillDmDepositLead'));
        if (f.yes('ended')) sb.write(rentText('fillDmDepositEnded'));
        if (f.yes('vacated')) {
          sb.write(rentText('fillDmDepositVacated'));
        } else if (f.no('vacated')) {
          sb.write(
              rentText('fillDmDepositNotVacated'));
        }
        sb.write(rentText('fillDmDepositTail'));
        out['basis_detail'] = sb.toString();
        out['evidence'] = _list([
          ...papers,
          rentText('fillDmDepositEv0'),
          if (f.yes('vacated')) rentText('fillDmDepositEv1'),
          rentText('fillDmDepositEv2'),
        ]);
      }
    case 'eviction':
      out['contract_kind'] = f.no('contract')
          ? 'قرارداد شفاهی'
          : (f.yes('witness')
              ? 'اجاره‌نامهٔ عادی با امضای دو شاهد'
              : (f.no('witness')
                  ? 'اجاره‌نامهٔ عادی بدون شاهد'
                  : ''));
      final breach =
          f.eq('aim', 'breach') || (f.no('ended') && f.yes('clause'));
      out['ground'] =
          breach ? 'فسخ اجاره به‌علت تخلف مستأجر' : 'پایان مدت اجاره';
      if (breach) {
        out['ground_detail'] =
            rentText('fillEvBreachDetail');
      } else if (f.yes('owes')) {
        out['ground_detail'] =
            rentText('fillEvOwesDetail');
      }
      out['evidence'] = _list([
        ...papers,
        rentText('fillEvEv0'),
        if (breach) rentText('fillEvEv1'),
      ]);
    case 'defense_brief':
      final big = sum != null && sum > 100000000;
      // تخلیه‌ای که فعلاً پایه ندارد: لایحه دربارهٔ اجاره‌های نپرداخته است.
      final aim = _noGround(f) ? 'unpaid' : f.get('aim');
      final money = landlord
          ? (aim == 'unpaid' || aim == 'damage')
          : f.eq('matter', 'deposit');
      out['authority_type'] =
          money && big ? 'شعبهٔ دادگاه عمومی حقوقی' : 'شعبهٔ دادگاه صلح';
      out['sender_role'] =
          !landlord && (_ordered(f) || f.covered.contains('damage'))
              ? 'خوانده'
              : 'خواهان / شاکی';
      if (landlord) {
        switch (aim) {
          case 'unpaid':
            out['subject'] = rentText('fillDbUnpaidSubject');
            out['merits_defense'] =
                rentText('fillDbUnpaidDefense');
          case 'damage':
            out['subject'] = rentText('fillDbDamageSubject');
            out['merits_defense'] =
                rentText('fillDbDamageDefense');
          case 'breach':
            out['subject'] = rentText('fillDbBreachSubject');
            out['merits_defense'] =
                rentText('fillDbBreachDefense');
          default:
            out['subject'] = rentText('fillDbEvictSubject');
            out['merits_defense'] =
                rentText('fillDbEvictDefense');
        }
      } else if (_ordered(f)) {
        out['subject'] = rentText('fillDbOrderedSubject');
        final sb = StringBuffer();
        if (f.no('ended')) {
          sb.write(
              rentText('fillDbOrderedNotEnded'));
        }
        sb.write(
            rentText('fillDbOrderedTail'));
        out['merits_defense'] = sb.toString();
      } else if (f.covered.contains('damage')) {
        out['subject'] = rentText('fillDbCovDamageSubject');
        out['merits_defense'] =
            rentText('fillDbCovDamageDefense');
      } else {
        out['subject'] = rentText('fillDbDepositSubject');
        final sb = StringBuffer();
        if (f.yes('ended')) sb.write(rentText('fillDbDepositEnded'));
        if (f.yes('vacated')) sb.write(rentText('fillDbDepositVacated'));
        sb.write(
            rentText('fillDbDepositTail'));
        out['merits_defense'] = sb.toString();
      }
      out['attachments'] = _list([
        ...papers,
        if (!landlord) rentText('fillDbAttDeposit'),
        if (_ordered(f)) rentText('fillDbAttOrdered'),
      ]);
    case 'formal_notice':
      out['deadline_days'] = '7';
      if (landlord) {
        out['topic'] = f.eq('aim', 'unpaid') || f.eq('aim', 'damage')
            ? 'مطالبهٔ وجه و تسویهٔ بدهی'
            : 'استرداد ودیعه (پول پیش) یا تخلیهٔ ملک استیجاری';
      } else {
        out['topic'] = f.eq('matter', 'deposit') || f.eq('matter', 'leave')
            ? 'استرداد ودیعه (پول پیش) یا تخلیهٔ ملک استیجاری'
            : 'سایر موارد قانونی';
      }
      if (landlord) {
        switch (f.get('aim')) {
          case 'unpaid':
            out['statement_body'] =
                rentText('fillFnUnpaid');
          case 'breach':
            out['statement_body'] =
                rentText('fillFnBreach');
          case 'damage':
            out['statement_body'] =
                rentText('fillFnDamage');
          default:
            out['statement_body'] =
                rentText('fillFnDefault');
        }
      } else {
        switch (f.get('matter')) {
          case 'repair':
            out['statement_body'] =
                rentText('fillFnRepair');
          case 'raise':
            out['statement_body'] =
                rentText('fillFnRaise');
          case 'leave':
            out['statement_body'] =
                rentText('fillFnLeave');
          case 'deliver':
            out['statement_body'] =
                rentText('fillFnDeliver');
          case 'evict':
            out['statement_body'] =
                rentText('fillFnEvict');
          default:
            out['statement_body'] = f.yes('vacated')
                ? rentText('fillFnDepVacated')
                : rentText('fillFnDepNotVacated');
        }
      }
  }
  out.removeWhere((_, v) => v.isEmpty);
  return out;
}

// =============================================================== پرسش‌ها

bool _needsContract(CaseFile f) {
  if (f.eq('role', 'landlord')) {
    return !f.has('aim') || f.eq('aim', 'evict') || f.eq('aim', 'unpaid');
  }
  return !f.has('matter') ||
      f.eq('matter', 'deposit') ||
      f.eq('matter', 'raise') ||
      f.eq('matter', 'repair') ||
      f.eq('matter', 'deliver');
}

bool _needsEnded(CaseFile f) {
  if (f.eq('role', 'landlord')) return !f.has('aim') || f.eq('aim', 'evict');
  return !f.eq('matter', 'repair') &&
      !f.eq('matter', 'leave') &&
      !f.eq('matter', 'deliver');
}

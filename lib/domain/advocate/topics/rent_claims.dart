part of 'rent.dart';

// ادعاهای حقوقیِ این موضوع: ارکان، شرط و نتیجه.

final List<Claim> rentClaims = [
  Claim(
    goal: rentText('claim0_goal'),
    when: (f) => _aim(f, 'unpaid'),
    cues: 'اجاره|کرایه|طلب|پول',
    uses: const ['due'],
    elements: [
      Element(
        rentText('claim0_e0_text'),
        (f) => f.tri('contract'),
        needs: const ['contract'],
        because: (f) => rentText('claim0_e0_because'),
        ifNo:
            rentText('claim0_e0_ifNo'),
      ),
    ],
    win: (f) =>
        rentText('claim0_win'),
    counter: (f) =>
        rentText('claim0_counter'),
  ),
  Claim(
    goal: rentText('claim1_goal'),
    when: (f) => _aim(f, 'damage'),
    cues: 'خسارت|خراب|تعمیر',
    uses: const ['due'],
    elements: [
      Element(
        rentText('claim1_e0_text'),
        (f) => f.tri('proof'),
        needs: const ['proof'],
        because: (f) => rentText('claim1_e0_because'),
        ifNo:
            rentText('claim1_e0_ifNo'),
      ),
    ],
    win: (f) =>
        rentText('claim1_win'),
    counter: (f) =>
        rentText('claim1_counter'),
  ),
  Claim(
    goal: rentText('claim2_goal'),
    when: (f) => _aim(f, 'breach'),
    cues: 'فسخ|تخلیه|بلند|بیرون',
    elements: [
      Element(
        rentText('claim2_e0_text'),
        (f) => f.tri('clause'),
        needs: const ['clause'],
        because: (f) => rentText('claim2_e0_because'),
        ifNo:
            rentText('claim2_e0_ifNo'),
      ),
      Element(
        rentText('claim2_e1_text'),
        (f) => f.tri('proof'),
        needs: const ['proof'],
        because: (f) => rentText('claim2_e1_because'),
        ifNo:
            rentText('claim2_e1_ifNo'),
      ),
    ],
    win: (f) =>
        rentText('claim2_win'),
    counter: (f) =>
        rentText('claim2_counter'),
  ),
  Claim(
    goal: rentText('claim3_goal'),
    when: (f) => _evicting(f) && f.no('ended'),
    cues: 'تخلیه|بیرون(?:ش)? کنم|بلند(?:ش)? کنم|خالی (?:کنه|کند|بشه)|فسخ',
    elements: [
      Element(
        rentText('claim3_e0_text'),
        (f) => f.tri('clause'),
        needs: const ['clause'],
        because: (f) => rentText('claim3_e0_because'),
        ifNo:
            rentText('claim3_e0_ifNo'),
      ),
      Element(
        rentText('claim3_e1_text'),
        (f) => f.tri('contract'),
        needs: const ['contract'],
        because: (f) => rentText('claim3_e1_because'),
        ifNo: rentText('claim3_e1_ifNo'),
      ),
    ],
    win: (f) =>
        rentText('claim3_win'),
    counter: (f) =>
        rentText('claim3_counter'),
  ),
  Claim(
    goal: rentText('claim4_goal'),
    when: (f) => f.eq('role', 'landlord'),
    cues: 'تخلیه|بیرون(?:ش)? کنم|بلند(?:ش)? کنم|خالی (?:کنه|کند|بشه)',
    elements: [
      Element(
        rentText('claim4_e0_text'),
        (f) => f.tri('ended'),
        needs: const ['ended'],
        because: (f) => rentText('claim4_e0_because'),
        ifNo:
            rentText('claim4_e0_ifNo'),
      ),
      Element(
        rentText('claim4_e1_text'),
        (f) => f.tri('contract'),
        needs: const ['contract'],
        because: (f) => rentText('claim4_e1_because'),
        ifNo:
            rentText('claim4_e1_ifNo'),
      ),
      Element(
        rentText('claim4_e2_text'),
        (f) => f.no('contract') ? false : f.tri('witness'),
        needs: const ['witness'],
        because: (f) => rentText('claim4_e2_because'),
        ifNo:
            rentText('claim4_e2_ifNo'),
      ),
    ],
    win: (f) =>
        rentText('claim4_win'),
    counter: (f) =>
        rentText('claim4_counter'),
  ),
  Claim(
    goal: rentText('claim5_goal'),
    when: (f) => !f.has('matter') || f.eq('matter', 'deposit'),
    cues: 'ودیعه|پول پیش|رهن|پولم',
    uses: const ['amount'],
    elements: [
      Element(
        rentText('claim5_e0_text'),
        (f) => f.tri('ended'),
        needs: const ['ended'],
        because: (f) => rentText('claim5_e0_because'),
        ifNo:
            rentText('claim5_e0_ifNo'),
      ),
      Element(
        rentText('claim5_e1_text'),
        (f) => f.tri('vacated'),
        needs: const ['vacated'],
        because: (f) => rentText('claim5_e1_because'),
        ifNo:
            rentText('claim5_e1_ifNo'),
      ),
      Element(
        rentText('claim5_e2_text'),
        (f) => f.tri('contract'),
        needs: const ['contract'],
        because: (f) => rentText('claim5_e2_because'),
        ifNo:
            rentText('claim5_e2_ifNo'),
      ),
    ],
    win: (f) =>
        rentText('claim5_win'),
    counter: (f) =>
        rentText('claim5_counter'),
  ),
  Claim(
    goal: rentText('claim6_goal'),
    when: (f) => f.eq('matter', 'raise'),
    cues: 'اجاره|کرایه|زیاد|گرون|بالا|افزایش',
    elements: [
      Element(
        rentText('claim6_e0_text'),
        _running,
        needs: const ['ended'],
        because: (f) => rentText('claim6_e0_because'),
        ifNo:
            rentText('claim6_e0_ifNo'),
      ),
      Element(
        rentText('claim6_e1_text'),
        (f) => f.tri('contract'),
        needs: const ['contract'],
        because: (f) => rentText('claim6_e1_because'),
        ifNo:
            rentText('claim6_e1_ifNo'),
      ),
    ],
    win: (f) =>
        rentText('claim6_win'),
    counter: (f) =>
        rentText('claim6_counter'),
  ),
  Claim(
    goal: rentText('claim7_goal'),
    when: (f) => f.eq('matter', 'evict') || f.eq('matter', 'order'),
    cues: 'بیرون|بلند|تخلیه|بمونم|بمانم|خالی',
    elements: [
      Element(
        rentText('claim7_e0_text'),
        _running,
        needs: const ['ended'],
        because: (f) => rentText('claim7_e0_because'),
        ifNo:
            rentText('claim7_e0_ifNo'),
      ),
      Element(
        rentText('claim7_e1_text'),
        (f) => f.eq('matter', 'order')
            ? false
            : (f.no('official') ? true : (f.yes('official') ? false : null)),
        needs: const ['official'],
        because: (f) => rentText('claim7_e1_because'),
        ifNo:
            rentText('claim7_e1_ifNo'),
      ),
    ],
    win: (f) =>
        rentText('claim7_win'),
    counter: (f) =>
        rentText('claim7_counter'),
  ),
  Claim(
    goal: rentText('claim8_goal'),
    when: (f) => f.eq('matter', 'repair'),
    cues: 'تعمیر|درست(?:ش)? کن|خراب',
    elements: [
      Element(
        rentText('claim8_e0_text'),
        (f) => f.tri('told'),
        needs: const ['told'],
        because: (f) => rentText('claim8_e0_because'),
        ifNo:
            rentText('claim8_e0_ifNo'),
      ),
      Element(
        rentText('claim8_e1_text'),
        (f) => f.tri('contract'),
        needs: const ['contract'],
        because: (f) => rentText('claim8_e1_because'),
        ifNo:
            rentText('claim8_e1_ifNo'),
      ),
    ],
    win: (f) =>
        rentText('claim8_win'),
    counter: (f) =>
        rentText('claim8_counter'),
  ),
  Claim(
    goal: rentText('claim9_goal'),
    when: (f) => f.eq('matter', 'leave'),
    cues: 'فسخ|بلند|برم|بروم|تخلیه|زودتر',
    elements: [
      Element(
        rentText('claim9_e0_text'),
        (f) => f.tri('consent'),
        needs: const ['consent'],
        because: (f) => rentText('claim9_e0_because'),
        ifNo:
            rentText('claim9_e0_ifNo'),
      ),
    ],
    win: (f) =>
        rentText('claim9_win'),
    counter: (f) =>
        rentText('claim9_counter'),
  ),
];

// ============================================================== سندها

/// دادخواست (یا نخستین نوشتهٔ رسمی) که به همین وضعیت می‌خورد.
Filing? _rentPetition(CaseFile f) {
  if (f.eq('role', 'landlord')) {
    switch (f.get('aim')) {
      case 'unpaid':
        return const Filing('demand_money', 'تنظیم دادخواست مطالبهٔ اجاره‌بها',
            'دادخواست مطالبهٔ اجاره‌بها');
      case 'damage':
        return const Filing('demand_money', 'تنظیم دادخواست مطالبهٔ خسارت',
            'دادخواست مطالبهٔ خسارت');
      case 'evict':
      case 'breach':
        if (_noGround(f)) {
          return f.yes('owes')
              ? const Filing('demand_money',
                  'تنظیم دادخواست مطالبهٔ اجاره‌بها', 'دادخواست مطالبهٔ اجاره‌بها')
              : null;
        }
        return const Filing(
            'eviction', 'تنظیم دادخواست تخلیه', 'دادخواست تخلیه');
    }
    return null;
  }
  if (!f.eq('role', 'tenant')) return null;
  switch (f.get('matter')) {
    case 'deposit':
      return const Filing('demand_money', 'تنظیم دادخواست مطالبهٔ ودیعه',
          'دادخواست مطالبهٔ ودیعه');
    case 'repair':
      return const Filing('formal_notice', 'تنظیم اظهارنامه برای تعمیر',
          'اظهارنامهٔ درخواست تعمیر');
    case 'raise':
      return const Filing('formal_notice', 'تنظیم اظهارنامه دربارهٔ اجاره',
          'اظهارنامه دربارهٔ مبلغ اجاره');
    case 'leave':
      return const Filing('formal_notice', 'تنظیم اظهارنامهٔ تحویل ملک',
          'اظهارنامهٔ آمادگی برای تحویل ملک');
    case 'deliver':
      return const Filing('formal_notice', 'تنظیم اظهارنامه برای تحویل‌گرفتن ملک',
          'اظهارنامهٔ درخواست تحویل مورد اجاره');
    case 'evict':
      return f.yes('official')
          ? null
          : const Filing('formal_notice', 'تنظیم اظهارنامه برای مزاحمت موجر',
              'اظهارنامهٔ اعتراض به مزاحمت موجر');
  }
  return null;
}

/// لایحه‌ای که در پروندهٔ همین دعوا به کار می‌آید.
Filing? _rentBrief(CaseFile f) {
  if (f.eq('role', 'landlord')) {
    if (_noGround(f)) {
      return f.yes('owes')
          ? const Filing('defense_brief', 'تنظیم لایحهٔ مطالبهٔ اجاره‌بها',
              'لایحهٔ مطالبهٔ اجاره‌بها')
          : null;
    }
    switch (f.get('aim')) {
      case 'unpaid':
        return const Filing('defense_brief', 'تنظیم لایحهٔ مطالبهٔ اجاره‌بها',
            'لایحهٔ مطالبهٔ اجاره‌بها');
      case 'damage':
        return const Filing('defense_brief', 'تنظیم لایحهٔ مطالبهٔ خسارت',
            'لایحهٔ مطالبهٔ خسارت');
      case 'breach':
        return const Filing('defense_brief', 'تنظیم لایحهٔ فسخ و تخلیه',
            'لایحهٔ فسخ اجاره و تخلیه');
      case 'evict':
        return const Filing(
            'defense_brief', 'تنظیم لایحهٔ تخلیه', 'لایحهٔ درخواست تخلیه');
    }
    return null;
  }
  if (!f.eq('role', 'tenant')) return null;
  if (_ordered(f)) {
    return const Filing('defense_brief', 'تنظیم لایحه دربارهٔ دستور تخلیه',
        'لایحه دربارهٔ دستور تخلیه');
  }
  if (f.eq('matter', 'deposit')) {
    return f.covered.contains('damage')
        ? const Filing('defense_brief', 'تنظیم لایحهٔ دفاع در برابر ادعای خسارت',
            'لایحهٔ دفاع در برابر ادعای خسارت')
        : const Filing('defense_brief', 'تنظیم لایحهٔ مطالبهٔ ودیعه',
            'لایحهٔ مطالبهٔ ودیعه');
  }
  return null;
}

String _list(List<String> items) => items.join('، ');

/// متن‌های پیشنهادی برای فیلدهای سند، از روی واقعیت‌های همین پرونده.
/// گزینه‌های فیلدهای انتخابی باید نویسه‌به‌نویسه با قالب یکی باشد.

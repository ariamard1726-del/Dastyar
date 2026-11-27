part of 'rent.dart';

// واقعیت‌هایی که وکیل در موضوعِ اجاره می‌پرسد یا از حرفِ کاربر می‌خواند.
//
// هر `Slot` یک پرسش، الگوی خواندنش و اثرِ حقوقی‌اش را کنارِ هم دارد؛ این فهرست
// «چه می‌دانیم» است، نه «چه می‌گوییم».

final List<Slot> _rentSlots = [
  Slot(
    id: 'role',
    first: true,
    // نقش با اشارهٔ گذرا یا نقلِ حرفِ طرف مقابل عوض نمی‌شود؛ فقط با حرفِ
    // صریحِ خودِ کاربر.
    sticky: true,
    readSure: _rentRoleSaid,
    ask: 'شما مستأجر هستید یا موجر (صاحب ملک)؟',
    why: 'حقوق و راه‌های مستأجر و موجر کاملاً فرق دارد؛ باید بدانم طرف کدام‌یک ایستاده‌ام.',
    options: ['مستأجر هستم', 'موجر هستم'],
    read: _rentRole,
    readPending: (n) => Sense.has(n, 'موجر|صاحب|مالک')
        ? 'landlord'
        : (Sense.has(n, 'مستاجر') ? 'tenant' : null),
    yesValue: '',
    noValue: '',
  ),
  Slot(
    id: 'matter',
    first: true,
    sticky: true,
    priority: const ['order'],
    ask: 'اختلافتان با موجر سرِ چیست؟',
    why: 'پس‌گرفتن پول پیش، بالابردن اجاره، بیرون‌کردن و تعمیر هر کدام قاعده و راه خودش را دارد؛ نمی‌خواهم دربارهٔ چیزی حرف بزنم که مسئلهٔ شما نیست.',
    options: [
      'پول پیشم را پس نمی‌دهد',
      'می‌خواهد اجاره را زیاد کند',
      'می‌خواهد به‌زور بیرونم کند',
      'خانه را تعمیر نمی‌کند',
      'دستور تخلیه آمده',
      'می‌خواهم زودتر بلند شوم',
    ],
    read: _rentMatter,
    yesValue: '',
    noValue: '',
    when: (f) => f.eq('role', 'tenant'),
    effect: (f) => _matter(f, 'deposit') ? _rentDepositLaw() : '',
  ),
  Slot(
    id: 'aim',
    first: true,
    sticky: true,
    priority: const ['evict', 'breach', 'unpaid', 'damage'],
    ask: 'مشکلتان با مستأجر چیست؟',
    why: 'تخلیه، گرفتن اجارهٔ عقب‌افتاده، خسارت و تخلف از قرارداد هر کدام راه و مدرک خودش را دارد.',
    options: [
      'ملک را تخلیه نمی‌کند',
      'اجاره را نمی‌دهد',
      'به ملک خسارت زده',
      'خلاف قرارداد عمل کرده',
    ],
    read: _rentAim,
    yesValue: '',
    noValue: '',
    when: (f) => f.eq('role', 'landlord'),
    effect: _aimEffect,
  ),
  Slot(
    id: 'official',
    ask: 'برگهٔ رسمی تخلیه (از دادگاه یا شورا) هم به دستتان رسیده، یا فقط خودش می‌گوید؟',
    why: 'حرف و تهدید موجر هیچ الزامی نمی‌آورد؛ ولی برگهٔ رسمی مهلت کوتاهی دارد و باید فوری به آن جواب داد.',
    options: ['فقط خودش می‌گوید', 'برگهٔ رسمی آمده'],
    read: _rentOfficial,
    readPending: (n) => Sense.has(n, 'خودش|حرف|نیومده|نیامده|نه هنوز')
        ? 'no'
        : (Sense.has(n, 'اومده|آمده|رسیده|ابلاغ شد') ? 'yes' : null),
    when: (f) => _matter(f, 'evict'),
    effect: (f) {
      if (!_matter(f, 'evict')) return '';
      return f.yes('official')
          ? _rentOrderBody(f)
          : rentText('effectSlotOfficialNo');
    },
  ),
  Slot(
    id: 'vacated',
    ask: 'ملک را تخلیه کرده و کلید را تحویل داده‌اید، یا هنوز در اختیار شماست؟',
    why: 'قانون پس‌دادن ودیعه را به تخلیه گره زده است؛ اگر هنوز ملک دست شما باشد اهرم فشار دارید، و اگر تحویل داده باشید باید تاریخ تحویل را ثابت کنیم.',
    options: ['تخلیه کرده‌ام', 'هنوز تخلیه نکرده‌ام'],
    read: _rentVacated,
    readPending: (n) => Sense.has(n, 'نکرد|هنوز| نه |ندادم|دست (?:خودمه|منه)')
        ? 'no'
        : (Sense.has(n, 'کردم|کرده ام|دادم| آره | اره | بله ') ? 'yes' : null),
    when: _rentDeposit,
    effect: (f) => f.yes('vacated')
        ? rentText('effectSlotVacatedYes')
        : rentText('effectSlotVacatedNo'),
  ),
  Slot(
    id: 'ended',
    ask: 'مدت قرارداد اجاره تمام شده است؟',
    why: 'پایان مدت نقطهٔ عطف اجاره است: پیش از آن قرارداد هر دو طرف را پایبند می‌کند و بعد از آن، تخلیه و پس‌دادن ودیعه مطرح می‌شود.',
    options: ['بله، تمام شده', 'نه، هنوز مانده'],
    read: _rentEnded,
    when: _needsEnded,
    effect: _endedEffect,
  ),
  Slot(
    id: 'contract',
    ask: 'اجاره‌نامهٔ کتبی دارید (دستی، بنگاهی یا با کد رهگیری)؟',
    why: 'اجاره‌نامه هم رابطهٔ اجاره را ثابت می‌کند هم مبلغ و مدت را؛ اگر نباشد باید از راه دیگری ثابتش کنیم.',
    options: ['بله، دارم', 'نه، شفاهی بود'],
    read: _rentContract,
    when: _needsContract,
    effect: _contractEffect,
  ),
  Slot(
    id: 'witness',
    ask: 'پای اجاره‌نامه را دو شاهد امضا کرده‌اند، یا کد رهگیری دارد؟',
    why: 'دستور تخلیهٔ یک‌هفته‌ای فقط برای اجاره‌نامه‌ای است که شاهد یا ثبت رسمی داشته باشد؛ بدون آن باید از راه دادخواست رفت.',
    options: ['بله، دارد', 'نه، ندارد'],
    read: _rentWitness,
    when: (f) => _evicting(f) && f.yes('contract') && !f.no('ended'),
    effect: (f) {
      if (!f.eq('role', 'landlord')) return '';
      return f.yes('witness')
          ? rentText('effectSlotWitnessYes')
          : rentText('effectSlotWitnessNo');
    },
  ),
  Slot(
    id: 'clause',
    ask: 'در اجاره‌نامه برای خودتان حق فسخ گذاشته‌اید (مثلاً اگر اجاره را ندهد یا ملک را به دیگری واگذار کند)؟',
    why: 'پیش از پایان مدت، فقط شرطی که در خودِ قرارداد نوشته شده به موجر اجازهٔ به‌هم‌زدن اجاره را می‌دهد.',
    options: ['بله، نوشته‌ایم', 'نه، چنین شرطی نیست'],
    read: _rentClause,
    when: (f) => (_evicting(f) && f.no('ended')) || _aim(f, 'breach'),
    effect: (f) {
      if (!f.eq('role', 'landlord')) return '';
      return f.yes('clause')
          ? rentText('effectSlotClauseYes')
          : rentText('effectSlotClauseNo');
    },
  ),
  Slot(
    id: 'proof',
    ask: 'از این موضوع مدرکی دارید (عکس، فیلم، صورت‌جلسه یا شاهد)؟',
    why: 'اثبات خرابی یا تخلف با موجر است؛ بدون مدرک، دادگاه حرف مستأجر را می‌پذیرد.',
    options: ['بله، دارم', 'نه، ندارم'],
    read: _rentProof,
    when: (f) => _aim(f, 'damage') || _aim(f, 'breach'),
    effect: (f) {
      if (!_aim(f, 'damage') && !_aim(f, 'breach')) return '';
      return f.yes('proof')
          ? rentText('effectSlotProofYes')
          : rentText('effectSlotProofNo');
    },
  ),
  Slot(
    id: 'told',
    ask: 'خرابی را کتبی (با پیام یا نامه) به موجر خبر داده‌اید؟',
    why: 'تا موجر رسماً خبردار نشده باشد، نمی‌شود گفت در تعمیر کوتاهی کرده است.',
    options: ['بله، خبر داده‌ام', 'نه، فقط زبانی گفته‌ام'],
    read: _rentTold,
    when: (f) => _matter(f, 'repair'),
    effect: (f) {
      if (!_matter(f, 'repair')) return '';
      return f.yes('told')
          ? rentText('effectSlotToldYes')
          : rentText('effectSlotToldNo');
    },
  ),
  Slot(
    id: 'consent',
    ask: 'موجر با زودتر رفتن شما موافق است؟',
    why: 'اجاره را پیش از موعد فقط با رضایت دو طرف یا حق فسخی که در قرارداد آمده می‌شود تمام کرد.',
    options: ['بله، موافق است', 'نه، قبول نمی‌کند'],
    read: _rentConsent,
    when: (f) => _matter(f, 'leave'),
    effect: (f) {
      if (!_matter(f, 'leave')) return '';
      return f.yes('consent')
          ? rentText('effectSlotConsentYes')
          : rentText('effectSlotConsentNo');
    },
  ),
  Slot(
    id: 'amount',
    ask: 'مبلغ ودیعه چقدر است؟',
    why: 'مبلغ تعیین می‌کند پرونده به دادگاه صلح می‌رود یا دادگاه عمومی، و هزینهٔ دادرسی هم از روی آن حساب می‌شود.',
    read: (n) => Sense.amount(n)?.toString(),
    readPending: (n) => Sense.looseAmount(n)?.toString(),
    yesValue: '',
    noValue: '',
    when: _rentDeposit,
    effect: (f) => _rentDeposit(f) ? moneyForum(f.n('amount')) : '',
  ),
  Slot(
    id: 'due',
    ask: 'مبلغی که طلب دارید حدوداً چقدر است؟',
    why: 'مبلغ تعیین می‌کند پرونده به دادگاه صلح می‌رود یا دادگاه عمومی، و هزینهٔ دادرسی هم از روی آن حساب می‌شود.',
    read: (n) => Sense.amount(n)?.toString(),
    readPending: (n) => Sense.looseAmount(n)?.toString(),
    yesValue: '',
    noValue: '',
    when: (f) => _aim(f, 'unpaid') || _aim(f, 'damage'),
    effect: (f) => _aim(f, 'unpaid') || _aim(f, 'damage')
        ? moneyForum(f.n('due'))
        : '',
  ),
  // واقعیت‌هایی که فقط از حرف کاربر خوانده می‌شوند و پرسیده نمی‌شوند.
  Slot(
    id: 'place',
    ask: '',
    why: '',
    read: (n) => Sense.has(n,
            'مغازه|تجاری|دکان|دکون|محل کسب|سرقفلی|حق کسب|پاساژ|دفتر کار|کارگاه')
        ? 'shop'
        : null,
    yesValue: '',
    noValue: '',
  ),
  Slot(
    id: 'owes',
    ask: '',
    why: '',
    read: (n) => Sense.has(n, _cUnpaid) ? 'yes' : null,
    yesValue: '',
    noValue: '',
  ),
];

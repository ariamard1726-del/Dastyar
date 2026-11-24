part of 'rent.dart';

// بحث‌ها، پرسش‌ها و خودِ تعریفِ موضوعِ اجاره.

String _aimEffect(CaseFile f) {
  if (!f.eq('role', 'landlord')) return '';
  switch (f.get('aim')) {
    case 'evict':
      return 'از نگاه قانون، موجر برای پس‌گرفتن ملکش راه سریعی دارد، به شرط اینکه قاعده را رعایت کند: با پایان مدت و داشتن اجاره‌نامهٔ کتبیِ شاهددار، «دستور تخلیه» ظرف حدود یک هفته صادر و اجرا می‌شود [[landlord_tenant:3]]؛ شرطش پس‌دادن یا سپردن ودیعهٔ مستأجر است [[landlord_tenant:4]].';
    case 'unpaid':
      return 'پرداخت اجاره در موعد، تعهد قانونی مستأجر است [[civil:490]]؛ می‌توانید اجاره‌های عقب‌افتاده را مطالبه کنید و اگر ودیعه‌ای از او دارید، طلبتان از راه دادخواست از آن کسر می‌شود [[landlord_tenant:4]].';
    case 'damage':
      return 'مستأجر فقط مسئول خرابی‌ای است که از کوتاهی یا زیاده‌روی خودش باشد، نه فرسودگی عادی [[civil:493]]؛ پس کلید کار، مدرکِ خرابی است.';
    case 'breach':
      return 'اگر مستأجر از شرطی که در اجاره‌نامه نوشته‌اید تخلف کرده باشد، حق فسخ پیدا می‌کنید [[civil:496]]؛ پس همه‌چیز به متن قرارداد برمی‌گردد.';
  }
  return '';
}

String _endedEffect(CaseFile f) {
  final landlord = f.eq('role', 'landlord');
  final other = f.eq('role', 'tenant') && !_rentDeposit(f);
  if (_ordered(f)) {
    return f.yes('ended')
        ? 'با تمام‌شدن مدت، صدور دستور تخلیه راه قانونیِ موجر است [[landlord_tenant:3]]؛ پس تکیهٔ شما روی ودیعه و مهلت است: تا پول پیش را نگرفته‌اید یا به دایرهٔ اجرا سپرده نشده، تخلیه اجرا نمی‌شود [[landlord_tenant:4]].'
        : 'چون مدت قرارداد تمام نشده، این دستور جای اعتراض دارد: دستور تخلیه فقط برای بعد از پایان مدت است [[landlord_tenant:3]]؛ هم‌زمان با اجرای دستور می‌توانید شکایتتان را به دادگاه بدهید [[landlord_tenant:5]].';
  }
  if (f.yes('ended')) {
    if (landlord) {
      return 'با تمام‌شدن مدت، عقد اجاره خودبه‌خود پایان یافته است [[civil:494]]؛ از این لحظه ماندنِ او بدون رضایت شما مجوزی ندارد و بابت هر روزش اجرت‌المثل طلبکارید.';
    }
    if (other) {
      return 'با تمام‌شدن مدت، عقد اجاره خودبه‌خود پایان یافته است [[civil:494]]؛ از این به بعد ماندن شما و مبلغ اجاره به توافق تازه با او بسته است و او می‌تواند تخلیه را از راه قانونی بخواهد.';
    }
    return 'با تمام‌شدن مدت، عقد اجاره خودبه‌خود پایان یافته است [[civil:494]] و دو طرف باید هم‌زمان به تعهدشان عمل کنند: شما تخلیه، او پرداخت ودیعه.';
  }
  if (landlord) {
    return 'چون مدت تمام نشده، دستور تخلیهٔ فوری در کار نیست [[landlord_tenant:3]]؛ قرارداد برای هر دو طرف الزام‌آور است [[civil:219]] و فقط با حق فسخی که در اجاره‌نامه دارید می‌شود زودتر تخلیه خواست.';
  }
  if (other) {
    return 'چون مدت قرارداد تمام نشده، قرارداد برای هر دو طرف الزام‌آور است [[civil:219]]؛ او نمی‌تواند پیش از موعد شرایط را یک‌طرفه عوض کند یا شما را به رفتن مجبور کند.';
  }
  return 'چون مدت قرارداد تمام نشده، قرارداد برای هر دو طرف الزام‌آور است [[civil:219]] و پس‌گرفتن ودیعه پیش از موعد فقط با توافق (فسخ دوطرفه) یا شرطی که در خود قرارداد آمده ممکن است. اگر او راضی به تخلیهٔ زودتر شده، همان را کتبی کنید.';
}

String _contractEffect(CaseFile f) {
  if (f.yes('contract')) {
    if (f.eq('role', 'landlord')) {
      if (!_evicting(f)) {
        return 'اجاره‌نامهٔ کتبی ستون پروندهٔ شماست؛ مبلغ اجاره، مدت و شرط‌ها را از همان استناد می‌کنیم.';
      }
      final ready = f.yes('ended')
          ? '\nبا این حساب، اگر مدت تمام شده و دو شاهد پای اجاره‌نامه را امضا کرده‌اند، شرایط دستور تخلیه را دارید: درخواست را در دفتر خدمات الکترونیک قضایی ثبت کنید و ودیعهٔ او را آماده داشته باشید تا هم‌زمان با تخلیه پس بدهید [[landlord_tenant:3]] [[landlord_tenant:4]].'
          : '';
      return 'اجاره‌نامهٔ کتبی کلید «دستور تخلیهٔ فوری» است، به شرط اینکه دو شاهد هم پایش را امضا کرده باشند [[landlord_tenant:2]]؛ اگر امضای شاهد ندارد، باید از راه دادخواست تخلیه بروید که کمی طولانی‌تر است.$ready';
    }
    return _rentDeposit(f)
        ? 'اجاره‌نامهٔ کتبی ستون پروندهٔ شماست؛ مبلغ ودیعه و تاریخ پایان را از همان استناد می‌کنیم.'
        : 'اجاره‌نامهٔ کتبی ستون پروندهٔ شماست؛ مبلغ اجاره و تاریخ پایان را از همان استناد می‌کنیم.';
  }
  if (f.eq('role', 'landlord')) {
    return 'نبودِ اجاره‌نامهٔ کتبی راه دستور تخلیهٔ فوری را می‌بندد، ولی حق شما را از بین نمی‌برد: با رسید واریز اجاره‌ها، پیام‌ها و شاهد، رابطهٔ اجاره را ثابت می‌کنید و از راه دادخواست جلو می‌روید.';
  }
  return f.eq('role', 'tenant') && !_rentDeposit(f)
      ? 'نبودِ اجاره‌نامهٔ کتبی کار را سخت‌تر می‌کند ولی ناممکن نه؛ رسید واریز اجاره، پیام‌ها و شهادت شهود می‌تواند رابطهٔ اجاره و شرایطش را ثابت کند.'
      : 'نبودِ اجاره‌نامهٔ کتبی کار را سخت‌تر می‌کند ولی ناممکن نه؛ رسید واریز ودیعه، پیام‌ها و شهادت شهود می‌تواند پرداخت پول و رابطهٔ اجاره را ثابت کند.';
}

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
    effect: (f) => _matter(f, 'deposit') ? _rentDepositLaw : '',
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
          : 'تا وقتی برگهٔ رسمی از مرجع قضایی نیامده، حرف و تهدید او هیچ الزامی برای شما نمی‌آورد؛ تنها راه قانونی‌اش گرفتن دستور تخلیه است [[landlord_tenant:3]].';
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
        ? 'چون ملک را تخلیه و تحویل داده‌اید، او دیگر هیچ بهانه‌ای برای نگه‌داشتن ودیعه ندارد [[landlord_tenant:4]]. از این‌جا به بعد پروندهٔ شما یک «مطالبهٔ وجه» سرراست است؛ فقط باید بتوانید تاریخ تخلیه و تحویل کلید را نشان دهید (صورت‌جلسه، پیام، شاهد یا بنگاه).'
        : 'تا وقتی ملک در دست شماست، برگ برنده با شماست: تخلیه و تحویل ملک موکول به پس‌گرفتن ودیعه یا سپرده‌شدن آن به دایرهٔ اجراست [[landlord_tenant:4]]. پس تا پول را نگرفته‌اید کلید را ندهید.',
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
          ? 'با امضای دو شاهد یا کد رهگیری، اجاره‌نامهٔ شما همان سندی است که قانون برای دستور تخلیهٔ فوری می‌خواهد [[landlord_tenant:2]] [[landlord_tenant:3]].'
          : 'بدون امضای دو شاهد یا کد رهگیری، راه دستور تخلیهٔ یک‌هفته‌ای بسته است و باید «دادخواست تخلیه» بدهید که با جلسهٔ دادگاه و زمان بیشتر همراه است.';
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
          ? 'شرط فسخ در اجاره‌نامه کلید کار است: با تخلف مستأجر حق فسخ دارید [[civil:496]]؛ فسخ را با اظهارنامه اعلام کنید [[civil_procedure:156]] و بعد تخلیه را بخواهید.'
          : 'بدون شرط فسخ در قرارداد، تا پایان مدت نمی‌شود اجاره را به هم زد [[civil:219]]؛ راه شما مطالبهٔ اجاره‌های نپرداخته و درخواست تخلیه بلافاصله پس از پایان مدت است.';
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
          ? 'خوب است؛ همین مدرک‌ها را با «تأمین دلیل» رسمی کنید تا بعداً قابل انکار نباشد [[civil_procedure:149]].'
          : 'بدون مدرک، ادعا در دادگاه به‌سختی پیش می‌رود؛ پیش از هر کاری «تأمین دلیل» بخواهید تا کارشناس وضعیت را صورت‌جلسه کند [[civil_procedure:149]].';
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
          ? 'همین پیام کتبی پایهٔ کار است: نشان می‌دهد موجر از خرابی خبر داشته و تعمیر نکرده است؛ نسخه‌ای از آن را نگه دارید.'
          : 'اول کتبی خبر بدهید و مهلت مشخص بگذارید (پیام هم کافی است، اظهارنامه محکم‌تر [[civil_procedure:156]])؛ بدون این، در دادگاه نمی‌شود نشان داد کوتاهی از او بوده.';
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
          ? 'با رضایت او کار ساده است: اجاره با توافق دو طرف به هم می‌خورد [[civil:283]]؛ فقط همین توافق، تاریخ تخلیه و تاریخ پس‌دادن ودیعه را کتبی کنید.'
          : 'بدون رضایت او، اجاره تا پایان مدت پابرجاست [[civil:219]]؛ اگر در قرارداد حق فسخ ندارید، عملی‌ترین راه پیشنهاد مستأجر جایگزین است.';
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

// ================================================================ بحث‌ها
//
// ترتیب مهم است: موتور نخستین بحثی را می‌گیرد که الگویش به پیام بخورد؛
// پس بحث‌های مشخص (دستور تخلیه، چک ضمانت) پیش از بحث‌های کلی (خرابی،
// بیرون‌کردن) آمده‌اند.

int _r(bool c, int v, [int other = 0]) => c ? v : other;

final List<Issue> _rentIssues = [
  // ---- هر دو طرف
  Issue(
    id: 'goodwill',
    chip: 'سرقفلی به چه کسی می‌رسد؟',
    cues: _cGoodwill,
    body: (f) => _rentGoodwillBody,
    rank: (f) => _r(_shop(f), 4, -1),
  ),
  Issue(
    id: 'death',
    chip: 'با فوت یکی از دو طرف اجاره چه می‌شود؟',
    cues: _cDeath,
    body: _rentDeathBody,
    rank: (f) => -1,
  ),
  Issue(
    id: 'sold',
    chip: 'اگر ملک فروخته شود چه می‌شود؟',
    cues: _cSold,
    body: _rentSoldBody,
  ),
  Issue(
    id: 'usage',
    chip: 'اجرت‌المثل چیست؟',
    cues: _cUsage,
    body: _rentUsageBody,
    rank: (f) => f.eq('role', 'landlord')
        ? _r(f.yes('ended'), 3)
        : _r(f.yes('ended') && f.no('vacated'), 2),
  ),
  Issue(
    id: 'code',
    chip: 'اجاره‌نامه کد رهگیری ندارد',
    cues: _cCode,
    body: (f) => _rentCodeBody,
    rank: (f) => _r(f.no('witness') || f.no('contract'), 2),
  ),
  Issue(
    id: 'penalty',
    chip: 'جریمهٔ دیرکردِ قرارداد را می‌شود گرفت؟',
    cues: _cPenalty,
    body: _rentPenaltyBody,
    rank: (f) => f.eq('role', 'landlord')
        ? _r(_evicting(f) && f.yes('ended'), 2)
        : _r(_matter(f, 'deposit') && f.yes('vacated'), 2),
  ),
  Issue(
    id: 'noTerm',
    chip: 'در قرارداد مدت ننوشته‌ایم',
    cues: _cNoTerm,
    body: _rentNoTermBody,
    rank: (f) => _r(f.no('contract'), 2, -1),
  ),
  // ---- مستأجر
  Issue(
    id: 'order',
    chip: 'برایم دستور تخلیه آمده',
    cues: _cOrder,
    body: _rentOrderBody,
    when: _tenantSide,
    covers: const {'official', 'matter'},
    rank: (f) => _ordered(f)
        ? -1
        : _r(_matter(f, 'evict'), 3, _r(f.yes('ended'), 1)),
  ),
  Issue(
    id: 'orderDeposit',
    chip: 'پول پیشم را هنوز نداده',
    cues: _cOrderDeposit,
    body: (f) => _rentOrderDepositBody,
    when: _ordered,
    rank: (f) => 4,
  ),
  Issue(
    id: 'guarantee',
    chip: 'چک ضمانتم را پس نمی‌دهد',
    cues: _cGuarantee,
    body: (f) => _rentGuaranteeBody,
    when: _tenantSide,
    rank: (f) => _r(_matter(f, 'deposit'), 1),
  ),
  Issue(
    id: 'partial',
    chip: 'بخشی از خانه قابل استفاده نیست',
    cues: _cPartial,
    body: (f) => _rentPartialBody,
    when: _tenantSide,
    rank: (f) => _r(_matter(f, 'repair'), 2, -1),
  ),
  Issue(
    id: 'defect',
    chip: 'می‌توانم به‌خاطر خرابی فسخ کنم؟',
    cues: _cDefect,
    body: (f) => _rentDefectBody,
    when: _tenantSide,
    rank: (f) => _r(_matter(f, 'repair'), 3, _r(_matter(f, 'leave'), 3)),
  ),
  Issue(
    id: 'selfRepair',
    chip: 'خودم تعمیر کنم پولش را می‌دهد؟',
    cues: _cSelfRepair,
    body: (f) => _rentSelfRepairBody,
    when: _tenantSide,
    rank: (f) => _r(_matter(f, 'repair'), 4),
  ),
  Issue(
    id: 'improve',
    chip: 'هزینه‌ای که برای خانه کرده‌ام چه می‌شود؟',
    cues: _cImprove,
    body: (f) => _rentImproveBody,
    when: _tenantSide,
    rank: (f) => _r(_matter(f, 'leave') || _matter(f, 'repair'), 1,
        _r(_matter(f, 'deposit'), 0, -1)),
  ),
  Issue(
    id: 'access',
    chip: 'بی‌اجازه وارد خانه می‌شود',
    cues: _cAccess,
    body: (f) => _rentAccessBody,
    when: _tenantSide,
    rank: (f) => _r(_matter(f, 'evict'), 2),
  ),
  Issue(
    id: 'deliver',
    chip: 'خانه را تحویلم نمی‌دهد',
    cues: _cDeliver,
    body: (f) => _rentDeliverBody,
    when: (f) => _tenantSide(f) && !f.yes('vacated'),
    rank: (f) => -1,
  ),
  Issue(
    id: 'third',
    chip: 'کس دیگری مدعی ملک شده یا مزاحم است',
    cues: _cThird,
    body: (f) => _rentThirdBody,
    when: _tenantSide,
    rank: (f) => -1,
  ),
  Issue(
    id: 'handover',
    chip: 'کلید را تحویل نمی‌گیرد',
    cues: _cHandover,
    body: (f) => _rentHandoverBody,
    when: _tenantSide,
    covers: const {'vacated'},
    rank: (f) => _r(_matter(f, 'deposit') && f.no('vacated'), 4,
        _r(_matter(f, 'leave'), 2)),
  ),
  Issue(
    id: 'late',
    chip: 'اجاره‌ام عقب افتاده',
    cues: _cLate,
    body: (f) => _rentLateBody,
    when: _tenantSide,
    rank: (f) => _r(_matter(f, 'evict') || _matter(f, 'order'), 2),
  ),
  Issue(
    id: 'bills',
    chip: 'قبض و شارژ با کیست؟',
    cues: _cBills,
    body: (f) => _rentBillsBody,
    when: _tenantSide,
    rank: (f) => _r(_matter(f, 'deposit'), 1),
  ),
  Issue(
    id: 'noMoney',
    chip: 'می‌گوید پول ندارم',
    cues: _cNoMoney,
    body: _rentNoMoneyBody,
    when: _depositTalk,
    rank: (f) => _r(_matter(f, 'deposit'), 3, -1),
  ),
  Issue(
    id: 'waitNew',
    chip: 'می‌گوید صبر کن مستأجر جدید بیاید',
    cues: _cWaitNew,
    body: (f) => _rentWaitNewBody,
    when: _depositTalk,
    rank: (f) => _r(_matter(f, 'deposit'), 2, -1),
  ),
  Issue(
    id: 'ownUse',
    chip: 'می‌گوید خودم می‌خواهم بنشینم',
    cues: _cOwnUse,
    body: _rentOwnUseBody,
    when: _tenantSide,
    rank: (f) => _r(_matter(f, 'evict'), 3, -1),
  ),
  Issue(
    id: 'sublet',
    chip: 'می‌توانم به کس دیگری اجاره بدهم؟',
    cues: _cSublet,
    body: _rentSubletBody,
    when: _tenantSide,
    rank: (f) => _r(_matter(f, 'leave'), 3),
  ),
  Issue(
    id: 'renew',
    chip: 'قرارداد تمدید نشده و هنوز ساکنم',
    cues: _cRenew,
    body: (f) => _rentRenewBody,
    when: (f) => _tenantSide(f) && !f.yes('vacated'),
    rank: (f) => _r(
        f.yes('ended') && !_matter(f, 'deposit'), 3, _r(_matter(f, 'raise'), 2)),
  ),
  Issue(
    id: 'leave',
    chip: 'می‌خواهم زودتر بلند شوم',
    cues: _cLeave,
    body: (f) => _rentLeaveBody,
    when: _tenantSide,
    covers: const {'matter'},
    rank: (f) => _matter(f, 'leave') ? -1 : _r(f.no('ended'), 1),
  ),
  Issue(
    id: 'raise',
    chip: 'می‌تواند اجاره را زیاد کند؟',
    cues: _cRaise,
    body: _rentRaiseBody,
    when: _tenantSide,
    rank: (f) => _matter(f, 'raise') ? -1 : _r(_matter(f, 'evict'), 1),
  ),
  Issue(
    id: 'noReason',
    chip: 'بی‌دلیل می‌خواهد بلندم کند',
    cues: _cNoReason,
    body: _rentNoReasonBody,
    when: (f) =>
        _tenantSide(f) && (!f.has('matter') || f.eq('matter', 'evict')),
    rank: (f) => _r(_matter(f, 'evict'), 1, -1),
  ),
  Issue(
    id: 'evict',
    chip: 'می‌خواهد به‌زور بیرونم کند',
    cues: _cEvict,
    body: (f) => _rentEvictBody,
    when: _tenantSide,
    rank: (f) => _matter(f, 'evict')
        ? -1
        : _r(_matter(f, 'raise'), 3,
            _r(_matter(f, 'deposit') && f.no('vacated'), 2)),
  ),
  Issue(
    id: 'fixSelf',
    chip: 'می‌گوید خودت درست کن',
    cues: _cFixSelf,
    body: (f) => _rentFixSelfBody,
    when: _tenantSide,
    rank: (f) => _r(_matter(f, 'repair'), 3, -1),
  ),
  Issue(
    id: 'blame',
    chip: 'می‌گوید تقصیر خودت است',
    cues: _cBlame,
    body: (f) => _rentBlameBody,
    when: (f) => _matter(f, 'repair'),
    rank: (f) => 2,
  ),
  Issue(
    id: 'repair',
    chip: 'تعمیر خانه با کیست؟',
    cues: _cRepair,
    body: (f) => _rentRepairBody,
    when: _tenantSide,
  ),
  Issue(
    id: 'silent',
    chip: 'جوابم را نمی‌دهد',
    cues: _cSilent,
    body: _rentSilentBody,
    when: _tenantSide,
    rank: (f) => _r(_matter(f, 'deposit') || _matter(f, 'repair'), 1, -1),
  ),
  Issue(
    id: 'damage',
    chip: 'می‌گوید خانه را خراب کرده‌ای',
    cues: _cDamage,
    body: _rentDamageBody,
    when: _tenantSide,
    rank: (f) => _r(_matter(f, 'deposit'), 3),
  ),
  // ---- موجر
  Issue(
    id: 'selfHelp',
    chip: 'خودم می‌توانم قفل را عوض کنم؟',
    cues: _cSelfHelp,
    body: (f) => _rentSelfHelpBody,
    when: _landlordSide,
    rank: (f) => _r(_evicting(f), 4, 1),
  ),
  Issue(
    id: 'lrenewed',
    chip: 'می‌گوید قرارداد تمدید شده',
    cues: _cLRenewed,
    body: (f) => _rentLandlordRenewedBody,
    when: _landlordSide,
    rank: (f) => _r(_evicting(f) && !f.no('ended'), 2, -1),
  ),
  Issue(
    id: 'object',
    chip: 'مستأجر اعتراض کرده یا مهلت خواسته',
    cues: _cLObject,
    body: (f) => _rentObjectBody,
    when: _landlordSide,
    rank: (f) => _r(_evicting(f) && f.yes('ended'), 1),
  ),
  Issue(
    id: 'lnoPlace',
    chip: 'می‌گوید جا پیدا نکرده‌ام',
    cues: _cLNoPlace,
    body: _rentLandlordNoPlaceBody,
    when: _landlordSide,
    rank: (f) => _r(_evicting(f) && !f.no('ended'), 3, -1),
  ),
  Issue(
    id: 'gone',
    chip: 'مستأجر رفته و وسایلش مانده',
    cues: _cGone,
    body: (f) => _rentGoneBody,
    when: _landlordSide,
  ),
  Issue(
    id: 'misuse',
    chip: 'ملک را برای کار دیگری استفاده می‌کند',
    cues: _cMisuse,
    body: (f) => _rentMisuseBody,
    when: _landlordSide,
    covers: const {'aim'},
    rank: (f) => _r(_aim(f, 'breach'), 2),
  ),
  Issue(
    id: 'lsublet',
    chip: 'ملک را به کس دیگری داده',
    cues: _cSublet,
    body: _rentSubletBody,
    when: _landlordSide,
    covers: const {'aim'},
    rank: (f) => _r(_aim(f, 'breach'), 3),
  ),
  Issue(
    id: 'ldepFirst',
    chip: 'می‌گوید اول پول پیشم را بده',
    cues: _cLDepFirst,
    body: (f) => _rentLandlordDepFirstBody,
    when: _landlordSide,
    rank: (f) => _r(_evicting(f), 3),
  ),
  Issue(
    id: 'loffset',
    chip: 'می‌گوید از پول پیش کم کن',
    cues: _cLOffset,
    body: (f) => _rentLandlordOffsetBody,
    when: _landlordSide,
    rank: (f) => _r(_aim(f, 'unpaid') || _aim(f, 'damage'), 3, -1),
  ),
  Issue(
    id: 'ldeposit',
    chip: 'ودیعه را کی باید پس بدهم؟',
    cues: _cLDeposit,
    body: (f) => _rentLandlordDepositBody,
    when: _landlordSide,
    rank: (f) => 3,
  ),
  Issue(
    id: 'early',
    chip: 'پیش از پایان مدت می‌توانم بلندش کنم؟',
    cues: _cEarly,
    body: (f) => _rentEarlyBody,
    when: _landlordSide,
    rank: (f) => f.yes('ended') ? -1 : _r(f.no('ended'), 4, 1),
  ),
  Issue(
    id: 'lraise',
    chip: 'می‌توانم اجاره را زیاد کنم؟',
    cues: _cRaise,
    body: (f) => _rentLandlordRaiseBody,
    when: _landlordSide,
  ),
  Issue(
    id: 'lbills',
    chip: 'قبض و شارژ را نداده',
    cues: _cBills,
    body: (f) => _rentLandlordBillsBody,
    when: _landlordSide,
    rank: (f) => _r(_aim(f, 'unpaid'), 2),
  ),
  Issue(
    id: 'lcantPay',
    chip: 'می‌گوید ندارم',
    cues: _cLCantPay,
    body: (f) => _rentLandlordCantPayBody,
    when: _landlordSide,
    rank: (f) => _r(_aim(f, 'unpaid'), 3, -1),
  ),
  Issue(
    id: 'lpaid',
    chip: 'می‌گوید پرداخت کرده‌ام',
    cues: _cLPaid,
    body: (f) => _rentLandlordPaidBody,
    when: _landlordSide,
    rank: (f) => _r(_aim(f, 'unpaid'), 2, -1),
  ),
  Issue(
    id: 'unpaid',
    chip: 'اجاره را هم نمی‌دهد',
    cues: _cUnpaid,
    body: _rentUnpaidBody,
    when: _landlordSide,
    covers: const {'aim'},
    rank: (f) => _aim(f, 'unpaid') ? -1 : _r(_evicting(f), 3, 1),
  ),
  Issue(
    id: 'lwear',
    chip: 'می‌گوید از اول خراب بود',
    cues: _cLWear,
    body: (f) => _rentLandlordWearBody,
    when: _landlordSide,
    rank: (f) => _r(_aim(f, 'damage'), 4, -1),
  ),
  Issue(
    id: 'lbuilt',
    chip: 'بی‌اجازه در ملک تغییر داده',
    cues: _cLBuilt,
    body: (f) => _rentLandlordBuiltBody,
    when: _landlordSide,
    rank: (f) => _r(_aim(f, 'breach') || _aim(f, 'damage'), 2),
  ),
  Issue(
    id: 'ldamage',
    chip: 'به ملک خسارت زده',
    cues: _cLDamage,
    body: (f) => _rentLandlordDamageBody,
    when: _landlordSide,
    covers: const {'aim'},
    rank: (f) => _aim(f, 'damage') ? -1 : _r(_evicting(f), 2, 1),
  ),
  Issue(
    id: 'lguarantor',
    chip: 'از ضامن یا چک تضمینش می‌توانم بگیرم؟',
    cues: _cLGuarantor,
    body: (f) => _rentLandlordGuarantorBody,
    when: _landlordSide,
    rank: (f) => _r(_aim(f, 'unpaid'), 1),
  ),
  Issue(
    id: 'lsilent',
    chip: 'جوابم را نمی‌دهد',
    cues: _cSilent,
    body: _rentSilentBody,
    when: _landlordSide,
    rank: (f) => 1,
  ),
];

// ================================================================= موضوع

final Topic rentTopic = Topic(
  id: 'rent',
  title: 'اجاره و ودیعه',
  claims: rentClaims,
  recap: rentRecap,
  petition: _rentPetition,
  brief: _rentBrief,
  fill: _rentFill,
  askReply: _rentAskReply,
  cues: {
    'دستور تخلیه|حکم تخلیه|اجاره[^ ]* (?:رو |را )?دو برابر|بلند (?:شی|شم|شو|بشی|بشم|شید)': 2,
    'اجاره|کرایه': 1,
    // «واسه خاطر کرایه خانه باهم درگیر شدیم»: دعوای مستأجر و موجر بر سر اجاره.
    '(?:کرایه|اجاره)[^؟]{0,30}(?:دعوا|درگیر|درگیری|بحث|اختلاف|نزاع)|(?:دعوا|درگیر|درگیری|نزاع|اختلاف)[^؟]{0,30}(?:کرایه|اجاره)': 2,
    'پول پیش|پول رهن|ودیعه|رهن(?:م| خونه| رو| کامل)|پیش خونه': 3,
    'صاحبخونه|موجر': 2,
    '(?:کرایه|اجاره)[^؟]{0,25}(?:عقب|معوق|نداده|نمیده|نمیدهد|نمی‌دهد|بدهکار|بدهی)': 3,
    '(?:صاحبخونه|موجر|مالک|مالکم)[^؟]{0,50}(?:بیرون|بلند) ?(?:کنه|کند|کنم|میکنه|میکنم|میکند)': 3,
    'مستاجر': 3,
    'اجاره ?نامه|اجاره بها|کرایه خونه|اجاره خونه|تخلیه|خونه رو خالی|اجاره نشین': 2,
    'خالی نمیکنه|بلند نمیشه|بیرونم (?:کنه|میکنه)|جوابم کرده|اجاره[^ ]* (?:رو |را )?(?:زیاد|گرون|بالا)': 2,
    'اجرت ?المثل|سرقفلی|مال الاجاره|عین مستاجره|مورد اجاره|اجور معوقه|حق کسب و پیشه': 2,
    'اجاره داد(?:م|ه ام|یم)|اجاره کرد(?:م|ه ام|یم)|رهن کرد(?:م|ه ام|یم)|رهن و اجاره': 2,
    // «صاحبخونه آبگرمکن رو درست نمی‌کنه»: خرابیِ خانهٔ اجاره‌ای.
    '(?:صاحبخونه|موجر) (?:[^ ]+ ){0,6}(?:تعمیر|درست|عوض|رسیدگی)(?:ش)? ن(?:میکن|کرد)|(?:خونه|ملک|واحد|مغازه)(?: ی)? (?:اجاره ای|استیجاری)':
        2,
  },
  anti: 'با هم (?:[^ ]+ ){0,3}اجاره کردیم|شریک|شراکت',
  slots: _rentSlots,
  opening: (f) {
    if (!f.has('role')) {
      return 'در اجاره، قانون هم برای مستأجر و هم برای موجر راه روشنی گذاشته است؛ فقط باید بدانم شما کدام طرف ماجرا هستید.';
    }
    return '';
  },
  issues: _rentIssues,
  follow: {
    'next': _rentPlan,
    'where': _rentWhere,
    'cost': (f) => moneyCost,
    'time': (f) => moneyTime,
    'evidence': _rentEvidence,
    'chance': _rentChance,
    'deadline': _rentDeadline,
    'refuse': _rentRefuse,
  },
  drafts: (f) {
    if (f.eq('role', 'landlord')) {
      return f.eq('aim', 'unpaid') || f.eq('aim', 'damage')
          ? const ['formal_notice', 'demand_money']
          : const ['formal_notice', 'eviction'];
    }
    return _rentDeposit(f)
        ? const ['formal_notice', 'demand_money']
        : const ['formal_notice'];
  },
);

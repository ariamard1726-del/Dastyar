/// تعریف دامنه‌ها و اسلات‌های موردنیاز برای استخراج از متن کاربر.

enum SlotType {
  category,
  amount,
  date,
  boolean,
  document,
  timeRange,
}

class SlotSpec {
  final String name;
  final SlotType type;
  final bool isRequired;
  final int priority;
  final String rationale;
  final Map<String, List<String>>? valueKeywords;
  final String prompt;
  final List<String> options;

  const SlotSpec({
    required this.name,
    required this.type,
    this.isRequired = true,
    this.priority = 1,
    this.rationale = '',
    this.valueKeywords,
    this.prompt = '',
    this.options = const [],
  });
}

class DomainSchema {
  final String domainId;
  final String titleFa;
  final List<SlotSpec> slots;

  const DomainSchema({
    required this.domainId,
    required this.titleFa,
    required this.slots,
  });

  List<SlotSpec> get requiredSlots =>
      slots.where((s) => s.isRequired).toList();

  List<SlotSpec> get prioritizedSlots =>
      [...slots]..sort((a, b) => a.priority.compareTo(b.priority));

  SlotSpec? slotByName(String name) {
    for (final s in slots) {
      if (s.name == name) return s;
    }
    return null;
  }
}

class DomainSchemaRegistry {
  DomainSchemaRegistry._();

  static final Map<String, DomainSchema> _schemas = <String, DomainSchema>{
    'cheque': _chequeSchema,
    'labor': _laborSchema,
    'lease': _leaseSchema,
    'family': _familySchema,
    'fraud_cyber': _fraudCyberSchema,
    'criminal_harm': _criminalHarmSchema,
    'litigation_defense': _litigationDefenseSchema,
    'debt': _debtSchema,
  };

  static DomainSchema? forDomain(String domainId) => _schemas[domainId];

  static List<String> get allDomainIds => _schemas.keys.toList()..sort();

  static Map<String, DomainSchema> get all => Map.unmodifiable(_schemas);
}

// ── تعریف ۸ دامنه ──

final DomainSchema _chequeSchema = const DomainSchema(
  domainId: 'cheque',
  titleFa: 'چک و دعاوی بانکی',
  slots: [
    SlotSpec(
      name: 'role',
      type: SlotType.category,
      priority: 1,
      rationale: 'نقش کاربر تعیین می‌کند چه مسیر حقوقی (کیفری، اجرائیه، حقوقی) برایش باز است.',
      prompt: 'نقش شما در مورد این چک چیست؟ (دارنده هستید یا صادرکننده/ضامن)',
      options: ['دارندهٔ چک هستم (طلبکار)', 'صادرکننده یا ضامن چک هستم'],
      valueKeywords: {
        'holder': ['دارنده', 'طلبکار', 'چکم برگشت', 'چک برگشتی دارم', 'پولم را بگیرم'],
        'issuer': ['صادرکننده', 'ضامن', 'چک دادم', 'چک کشیدم', 'بابت ضمانت داده بودم'],
      },
    ),
    SlotSpec(
      name: 'nature',
      type: SlotType.category,
      priority: 2,
      rationale: 'طبق مادهٔ ۱۳ قانون صدور چک، چک تضمینی/مشروط امکان شکایت کیفری را محدود می‌کند.',
      prompt: 'آیا چک بابت بدهی قطعی و به تاریخ روز صادر شده، یا بابت تضمین/امانت/مشروط/سفیدامضا بوده است؟',
      options: ['بابت بدهی قطعی و تاریخ روز', 'بابت تضمین، امانت، مشروط یا وعده‌دار'],
      valueKeywords: {
        'conditional': ['تضمین', 'ضمانت', 'امانت', 'مشروط', 'سفید', 'وعده'],
        'unconditional': ['بدهی قطعی', 'تاریخ روز'],
      },
    ),
    SlotSpec(
      name: 'cert_time',
      type: SlotType.category,
      priority: 3,
      rationale: 'مهلت ۶ ماههٔ شکایت کیفری از تاریخ گواهی عدم پرداخت، مسیر را تعیین می‌کند.',
      prompt: 'آیا گواهی عدم پرداخت از بانک گرفته‌اید و کمتر از ۶ ماه از تاریخ چک و گواهی گذشته است؟',
      options: ['بله، گواهی دارم و زیر ۶ ماه است', 'بیش از ۶ ماه گذشته است', 'هنوز برگشت نزده‌ام / گواهی ندارم'],
      valueKeywords: {
        'no_cert': ['هنوز برگشت نزده', 'گواهی ندارم'],
        'over_6m': ['بیش از ۶ ماه', 'بیشتر از ۶ ماه', 'یک سال گذشته'],
        'under_6m': ['زیر ۶ ماه', 'گواهی دارم'],
      },
    ),
    SlotSpec(
      name: 'amount',
      type: SlotType.amount,
      isRequired: false,
      priority: 4,
      rationale: 'مبلغ چک برای محاسبهٔ خسارت تأخیر تأدیه و تعیین صلاحیت دادگاه لازم است.',
      prompt: 'مبلغ چک چقدر است؟ (به تومان یا ریال)',
    ),
    SlotSpec(
      name: 'due_date',
      type: SlotType.date,
      isRequired: false,
      priority: 5,
      rationale: 'تاریخ سررسید چک مبدأ محاسبهٔ مهلت‌ها و خسارت است.',
      prompt: 'تاریخ سررسید چک چه زمانی بوده است؟ (مثلاً ۱۴۰۳/۰۵/۱۲)',
    ),
  ],
);

final DomainSchema _laborSchema = const DomainSchema(
  domainId: 'labor',
  titleFa: 'روابط کار و بیمه',
  slots: [
    SlotSpec(
      name: 'issue',
      type: SlotType.category,
      priority: 1,
      rationale: 'نوع مشکل (اخراج/حقوق/بیمه) مسیر شکایت در هیأت تشخیص را تعیین می‌کند.',
      prompt: 'مشکل اصلی شما با کارفرما کدام مورد است؟',
      options: ['اخراج یا عدم تمدید و بازگشت به کار', 'عدم پرداخت حقوق، عیدی یا سنوات', 'رد نکردن حق بیمهٔ تأمین اجتماعی'],
      valueKeywords: {
        'dismissal': ['اخراج', 'بازگشت به کار'],
        'insurance': ['بیمه', 'رد نکردن'],
        'wages': ['حقوق', 'سنوات', 'عیدی'],
      },
    ),
    SlotSpec(
      name: 'proof',
      type: SlotType.category,
      priority: 2,
      rationale: 'نوع مدرک تعیین می‌کند رابطهٔ کاری در هیأت تشخیص چگونه اثبات شود.',
      prompt: 'چه مدرکی برای اثبات رابطهٔ کاری دارید؟ (قرارداد کتبی، فیش واریز حقوق، لیست بیمه یا پیامک/شهادت)',
      options: ['قرارداد کتبی یا سابقهٔ بیمه دارم', 'قرارداد شفاهی ولی واریزی بانکی/پیامک دارم', 'هیچ مدرک کتبی یا بانکی ندارم'],
      valueKeywords: {
        'written': ['قرارداد کتبی', 'سابقه بیمه', 'کتبی'],
        'bank_sms': ['شفاهی', 'واریزی', 'پیامک'],
        'none': ['هیچ مدرک'],
      },
    ),
    SlotSpec(
      name: 'time',
      type: SlotType.category,
      priority: 3,
      rationale: 'مهلت شکایت از اخراج (۳۰ روز) و مهلت مطالبهٔ حقوق، حیاتی است.',
      prompt: 'اگر اخراج شده‌اید، چند روز از تاریخ اخراج گذشته است؟',
      options: ['کمتر از ۳۰ روز', 'بیش از ۳۰ روز', 'هنوز در کارگاه مشغول به کارم'],
      valueKeywords: {
        'under_30d': ['کمتر از ۳۰', 'هفته پیش اخراج', 'تازه اخراج'],
        'over_30d': ['بیش از ۳۰', 'چند ماه پیش', 'ماه پیش اخراج'],
        'active': ['مشغول به کار', 'هنوز کار می‌کنم'],
      },
    ),
    SlotSpec(
      name: 'amount',
      type: SlotType.amount,
      isRequired: false,
      priority: 4,
      rationale: 'مبلغ حقوق معوقه برای تعیین خواسته در دادخواست ضروری است.',
      prompt: 'مبلغ حقوق معوقه تقریباً چقدر است؟',
    ),
  ],
);

final DomainSchema _leaseSchema = const DomainSchema(
  domainId: 'lease',
  titleFa: 'اجاره و تخلیهٔ ملک',
  slots: [
    SlotSpec(
      name: 'role',
      type: SlotType.category,
      priority: 1,
      rationale: 'موجر یا مستأجر بودن، مسیر تخلیه یا مطالبهٔ ودیعه را تعیین می‌کند.',
      prompt: 'در این رابطهٔ اجاره، شما موجر (مالک) هستید یا مستأجر؟',
      options: ['موجر (مالک) هستم', 'مستأجر هستم'],
      valueKeywords: {
        'landlord': ['مستاجر من', 'مالک هستم', 'موجر هستم', 'مستاجرم'],
        'tenant': ['مستاجر هستم', 'صاحبخانه', 'صاحب خانه', 'پول پیشم'],
      },
    ),
    SlotSpec(
      name: 'expired',
      type: SlotType.category,
      priority: 2,
      rationale: 'با انقضای مدت، دستور تخلیهٔ فوری (مادهٔ ۳ قانون ۱۳۷۶) در دسترس است.',
      prompt: 'آیا مدت قرارداد اجاره به پایان رسیده است؟',
      options: ['بله، مدت قرارداد تمام شده', 'خیر، هنوز در میانهٔ مدت هستیم'],
      valueKeywords: {
        'yes': ['تمام شده', 'منقضی شده', 'پایان رسیده'],
        'no': ['میانه مدت', 'تمام نشده', 'هنوز تمام نشده'],
      },
    ),
    SlotSpec(
      name: 'witnesses',
      type: SlotType.category,
      priority: 3,
      rationale: 'امضای دو شاهد شرط صدور دستور تخلیهٔ فوری است.',
      prompt: 'نوع قرارداد اجارهٔ شما چگونه است؟',
      options: ['قرارداد کتبی با امضای دو شاهد یا سند رسمی', 'قرارداد عادی بدون امضای دو شاهد یا شفاهی'],
      valueKeywords: {
        'two_witnesses': ['دو شاهد', 'رسمی', 'کد رهگیری'],
        'no_witnesses': ['بدون امضای دو شاهد', 'بدون شاهد', 'شفاهی'],
      },
    ),
    SlotSpec(
      name: 'deposit_amount',
      type: SlotType.amount,
      isRequired: false,
      priority: 4,
      rationale: 'مبلغ ودیعه برای محاسبهٔ اجرت‌المثل و مطالبهٔ حقوقی لازم است.',
      prompt: 'مبلغ ودیعه (پول پیش) تقریباً چقدر است؟',
    ),
  ],
);

final DomainSchema _familySchema = const DomainSchema(
  domainId: 'family',
  titleFa: 'خانواده (مهریه، طلاق، حضانت)',
  slots: [
    SlotSpec(
      name: 'subtopic',
      type: SlotType.category,
      priority: 1,
      rationale: 'نوع موضوع (مهریه/نفقه/حضانت/طلاق) مسیر حقوقی را تعیین می‌کند.',
      prompt: 'موضوع اصلی پرونده یا پرسش خانوادگی شما کدام است؟',
      options: ['مطالبه یا تقسیط مهریه', 'نفقه و تمکین', 'درخواست طلاق', 'حضانت و ملاقات فرزند'],
      valueKeywords: {
        'mehrieh': ['مهریه'],
        'nafaqeh': ['نفقه', 'تمکین'],
        'custody': ['حضانت', 'ملاقات'],
        'divorce': ['طلاق'],
      },
    ),
    SlotSpec(
      name: 'side',
      type: SlotType.category,
      priority: 2,
      rationale: 'زوجه یا زوج بودن، خواسته‌ها و اختیارات قانونی را متفاوت می‌کند.',
      prompt: 'شما از طرف زوجه (خانم) پیگیر موضوع هستید یا زوج (آقا)؟',
      options: ['زوجه (خانم) هستم', 'زوج (آقا) هستم'],
      valueKeywords: {
        'wife': ['زوجه', 'شوهرم', 'خانم هستم'],
        'husband': ['زوج هستم', 'آقا هستم', 'خانمم', 'مهریه را اجرا گذاشته'],
      },
    ),
    SlotSpec(
      name: 'detail',
      type: SlotType.category,
      priority: 3,
      rationale: 'توافق، تعارض یا اجرائیه، مسیر بعدی (توافقی یا دادگاه) را تعیین می‌کند.',
      prompt: 'کدام وضعیت به شرایط فعلی شما نزدیک‌تر است؟',
      options: ['توافق نداریم و طرف مقابل همکاری نمی‌کند', 'حکم یا اجرائیه صادر شده و بحث توان مالی/اعسار مطرح است', 'زمینهٔ توافق بین زوجین وجود دارد'],
      valueKeywords: {
        'enforcement_insolvency': ['توان مالی', 'اعسار', 'اجرا گذاشته'],
        'mutual': ['توافق داریم', 'توافقی'],
        'contested': ['توافق نداریم', 'همکاری نمی'],
      },
    ),
  ],
);

final DomainSchema _fraudCyberSchema = const DomainSchema(
  domainId: 'fraud_cyber',
  titleFa: 'کلاهبرداری و جرایم رایانه‌ای',
  slots: [
    SlotSpec(
      name: 'kind',
      type: SlotType.category,
      priority: 1,
      rationale: 'عنوان اتهامی (کلاهبرداری، جرم رایانه‌ای، خیانت در امانت) تعیین‌کنندهٔ مسیر است.',
      prompt: 'نحوهٔ از دست رفتن مال یا وقوع جرم دقیقاً به چه شکلی بوده است؟',
      options: ['برداشت اینترنتی، لینک جعلی (فیشینگ) یا هک', 'فریب با مانور متقلبانه و صحنه‌سازی (کلاهبرداری)', 'مالی را به امانت دادم و پس نمی‌دهد', 'ملک یا مال مرا بدون اجازه به دیگری فروخته است'],
      valueKeywords: {
        'cyber': ['فیشینگ', 'اینترنتی', 'هک', 'لینک'],
        'trust_breach': ['امانت'],
        'unauthorized_sale': ['مال غیر', 'بدون اجازه فروخته'],
        'classic_fraud': ['مانور', 'صحنه سازی', 'صحنه‌سازی'],
      },
    ),
    SlotSpec(
      name: 'evidence',
      type: SlotType.category,
      priority: 2,
      rationale: 'وجود مدارک بانکی/کتبی امکان تعقیب سریع‌تر از طریق پلیس فتا را فراهم می‌کند.',
      prompt: 'چه مستنداتی در دست دارید؟ (رسید بانکی، قرارداد امانت، پیامک یا شاهد)',
      options: ['گردش حساب بانکی، اسکرین‌شات یا رسید کتبی دارم', 'فقط شاهد یا مکالمهٔ شفاهی دارم'],
      valueKeywords: {
        'strong': ['گردش حساب', 'رسید', 'اسکرین', 'اسکرین‌شات'],
        'weak': ['فقط شاهد', 'شفاهی'],
      },
    ),
    SlotSpec(
      name: 'amount',
      type: SlotType.amount,
      isRequired: false,
      priority: 3,
      rationale: 'مبلغ زیان برای تعیین عنوان و میزان مجازات مؤثر است.',
      prompt: 'مبلغ زیان تقریباً چقدر است؟',
    ),
  ],
);

final DomainSchema _criminalHarmSchema = const DomainSchema(
  domainId: 'criminal_harm',
  titleFa: 'شکایت کیفری و آسیب',
  slots: [
    SlotSpec(
      name: 'harm_type',
      type: SlotType.category,
      priority: 1,
      rationale: 'نوع رفتار (ضرب/تهدید/توهین/انتشار تصویر) عنوان اتهامی را تعیین می‌کند.',
      prompt: 'چه رفتاری علیه شما رخ داده است؟',
      options: ['ضرب و جرح و آسیب بدنی', 'تهدید یا اخاذی', 'توهین، فحاشی یا افترا', 'انتشار عکس/فیلم خصوصی در فضای مجازی'],
      valueKeywords: {
        'assault': ['ضرب', 'کتک'],
        'private_media': ['عکس خصوصی', 'فیلم خصوصی', 'انتشار تصویر'],
        'threat': ['تهدید', 'اخاذی'],
        'insult': ['توهین', 'فحاشی', 'افترا'],
      },
    ),
    SlotSpec(
      name: 'proof',
      type: SlotType.category,
      priority: 2,
      rationale: 'وجود گواهی پزشکی یا گزارش پلیس روند اثبات را تسریع می‌کند.',
      prompt: 'آیا مدرکی مانند گواهی پزشکی قانونی، گزارش پلیس، شاهد یا پیامک دارید؟',
      options: ['گواهی پزشکی قانونی / گزارش پلیس / پیامک دارم', 'فقط شاهد دارم', 'فعلاً مدرکی جمع‌آوری نکرده‌ام'],
      valueKeywords: {
        'documented': ['پزشکی قانونی', 'پلیس', 'پیامک'],
        'witness': ['شاهد'],
        'none': ['فعلا مدرکی', 'مدرکی ندارم'],
      },
    ),
  ],
);

final DomainSchema _litigationDefenseSchema = const DomainSchema(
  domainId: 'litigation_defense',
  titleFa: 'دفاع در دادرسی و اعتراض به رأی',
  slots: [
    SlotSpec(
      name: 'stage',
      type: SlotType.category,
      priority: 1,
      rationale: 'نوع ابلاغیه (احضاریه/غیابی/بدوی) تعیین می‌کند کدام مهلت و کدام لایحه لازم است.',
      prompt: 'ابلاغیه‌ای که در سامانهٔ ثنا دریافت کرده‌اید مربوط به کدام مرحله است؟',
      options: ['ابلاغ وقت رسیدگی یا احضاریه (پرونده در جریان است)', 'حکم غیابی صادر شده است', 'رأی حضوری بدوی صادر شده و می‌خواهم اعتراض کنم'],
      valueKeywords: {
        'default_judgment': ['غیابی'],
        'appeal': ['حضوری بدوی', 'تجدیدنظر'],
        'first_hearing': ['وقت رسیدگی', 'احضاریه'],
      },
    ),
    SlotSpec(
      name: 'deadline',
      type: SlotType.category,
      priority: 2,
      rationale: 'مهلت ۲۰ روزهٔ واخواهی/تجدیدنظر برای حفظ حق دفاع حیاتی است.',
      prompt: 'چند روز از تاریخ درج ابلاغیه در سامانهٔ ثنا گذشته است؟ (مهلت واخواهی ۲۰ روز)',
      options: ['کمتر از ۲۰ روز', 'بیش از ۲۰ روز ولی عذر موجه دارم', 'بیش از ۲۰ روز و رأی به اجرا رفته'],
      valueKeywords: {
        'within_20d': ['کمتر از ۲۰', 'مهلت دارم'],
        'excused_late': ['عذر موجه'],
        'late': ['به اجرا رفته', 'بیش از ۲۰'],
      },
    ),
  ],
);

final DomainSchema _debtSchema = const DomainSchema(
  domainId: 'debt',
  titleFa: 'طلب و بدهی',
  slots: [
    SlotSpec(
      name: 'role',
      type: SlotType.category,
      priority: 1,
      rationale: 'طلبکار یا بدهکار بودن، مسیر (مطالبه یا اعسار) را تعیین می‌کند.',
      prompt: 'شما طلبکار هستید یا بدهکار/خوانده؟',
      options: ['طلبکار هستم و می‌خواهم پولم را بگیرم', 'بدهکار هستم و توان پرداخت یکجای بدهی را ندارم'],
      valueKeywords: {
        'debtor': ['بدهکار هستم', 'توان پرداخت', 'اعسار'],
        'creditor': ['طلبکار', 'قرض دادم', 'پولم را بگیرم'],
      },
    ),
    SlotSpec(
      name: 'doc',
      type: SlotType.category,
      priority: 2,
      rationale: 'نوع سند (کتبی/بانکی/شفاهی) تعیین‌کنندهٔ نحوهٔ اثبات در دادگاه است.',
      prompt: 'چه مدرکی بابت این بدهی/طلب وجود دارد؟',
      options: ['رسید کتبی، قرارداد یا سفته', 'فیش واریز بانکی و پیامک', 'فقط شهادت شهود (شفاهی)'],
      valueKeywords: {
        'written': ['رسید کتبی', 'سفته', 'قرارداد'],
        'bank': ['فیش', 'واریز'],
        'oral': ['شفاهی', 'شهادت'],
      },
    ),
    SlotSpec(
      name: 'amount',
      type: SlotType.amount,
      isRequired: false,
      priority: 3,
      rationale: 'مبلغ بدهی برای تعیین خواسته در دادخواست و نصاب صلاحیت لازم است.',
      prompt: 'مبلغ بدهی تقریباً چقدر است؟',
    ),
  ],
);
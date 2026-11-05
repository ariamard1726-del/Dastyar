import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/persian_text.dart';

/// «آیا کاربر دارد سؤال می‌پرسد یا دارد وضعیتش را تعریف می‌کند؟»
///
/// چرا این کلاس لازم شد؟ رفتار قبلی همهٔ پیام‌های شخصی را به مصاحبهٔ
/// گام‌به‌گام می‌برد؛ حتی وقتی کاربر صریحاً یک پرسش حقوقی پرسیده بود
/// («چک برگشتی دارم، چه کار کنم؟»). نتیجه این بود که ربات به‌جای پاسخ،
/// سؤال بعدی خودش را می‌پرسید. این کلاس یک منبع یکتا برای سه تشخیص است:
///
///  * [isQuestion] — شکل پرسشی دارد؟ (علامت پرسش، واژهٔ پرسشی، درخواست راهنمایی)
///  * [hasLegalTerm] — واژهٔ حقوقی در جمله هست؟
///  * [looksLikeLegalQuestion] — پرسش حقوقی است؟ (پس اول باید پاسخ بگیرد)
///
/// این‌ها هیچ وابستگی‌ای به وضعیت گفتگو ندارند تا هم مشاور، هم کنترلر گفتگو و
/// هم ابزار ارزیابی بتوانند از یک قاعده استفاده کنند.
class ConversationRouter {
  ConversationRouter._();

  /// واژه‌های پرسشی که در گفتار روزمره هم رایج‌اند.
  static final RegExp _questionWords = PersianText.wordRe(<String>[
    'چیست', 'چیه', 'چطور', 'چگونه', 'چرا', 'آیا', 'چقدر', 'کجا', 'کدام',
    'کیست', 'یعنی', 'میشه', 'می‌شود', 'میتوانم', 'می‌تونم', 'باید', 'لازمه',
    'مجازه', 'جرمه', 'قانونی', 'قانونیه',
  ]);

  /// درخواست راهنمایی/مشورت؛ در گفتار فارسی جای «؟» را می‌گیرد.
  static const List<String> _advicePhrases = <String>[
    'چه کار کنم', 'چیکار کنم', 'چکار کنم', 'چه کنم', 'چی کار کنم',
    'چه کاری کنم', 'راهنمایی', 'راهنماییم کن', 'کمکم کن', 'کمک کن',
    'توصیه', 'مشورت', 'سوال دارم', 'سؤال دارم', 'سوال داشتم', 'سؤال داشتم',
    'نمیدانم چه', 'نمی‌دانم چه',
  ];

  /// واژه‌های حقوقی؛ با [PersianText.wordRe] تطبیق داده می‌شوند تا «چک» در
  /// «چکار» گیر نکند و «چک» در «چک‌ها» و «چکم» بگیرد.
  static final RegExp _legalTerms = PersianText.wordRe(<String>[
    // اسناد تجاری
    'چک', 'سفته', 'برات', 'قرارداد', 'سند', 'اظهارنامه', 'اجرائیه', 'ثبت',
    // خانواده
    'مهریه', 'مهر', 'نفقه', 'طلاق', 'خلع', 'حضانت', 'ملاقات', 'ارث', 'وصیت',
    'عده', 'تمکین', 'اجرت المثل', 'شیربها',
    // ملک و اجاره
    'اجاره', 'تخلیه', 'موجر', 'مستاجر', 'صاحبخانه', 'سرقفلی', 'ودیعه',
    'پول پیش', 'ملک', 'مالک', 'زمین', 'تصرف', 'حریم', 'ارتفاق',
    // کار
    'کارفرما', 'کارگر', 'کارگری', 'اخراج', 'سنوات', 'بیمه', 'مرخصی',
    'اضافه کاری', 'حقوق', 'مزد', 'پاداش', 'بیکاری',
    // کیفری
    'کلاهبرداری', 'فیشینگ', 'هک', 'امانت', 'خیانت', 'سرقت', 'دزدی',
    'توهین', 'فحاشی', 'فحش', 'تهدید', 'ضرب', 'جرح', 'کتک', 'دیه', 'ارش',
    'قصاص', 'محاربه', 'ارتشاء', 'اختلاس', 'جعل', 'افترا', 'توهین',
    // دادرسی
    'شکایت', 'شکوائیه', 'دادخواست', 'دادگاه', 'دادسرا', 'ابلاغیه', 'احضاریه',
    'ثنا', 'رای', 'حکم', 'قرار', 'تجدیدنظر', 'واخواهی', 'اعتراض', 'اعسار',
    'افلاس', 'حجر', 'قیم', 'امین', 'وکالت', 'وکیل', 'داوری', 'صلح',
    // مدنی
    'بیع', 'معامله', 'ثمن', 'عقد', 'فسخ', 'ضمانت', 'ضامن', 'ضمان', 'تعهد',
    'شرط', 'وجه التزام', 'غبن', 'تدلیس', 'خیار', 'مسئولیت', 'خسارت', 'ضرر',
    'اتلاف', 'تسبیب', 'عدوان', 'اجاره بها', 'رهن',
    // متفرقه
    'مالیات', 'گمرک', 'سربازی', 'گواهینامه', 'رانندگی', 'جریمه', 'خلافی',
    'پاسپورت', 'اتباع', 'شهروندی', 'پناهندگی', 'میراث', 'قانون', 'ماده', 'اصل',
  ]);

  static final RegExp _directArticleRe =
      RegExp(r'(?:ماده|اصل)\s*(?:واحده|\d+)');

  static final RegExp _questionMarkRe = RegExp(r'[؟?]');

  static String _norm(String rawText) =>
      PersianText.collapse(PersianText.normalize(rawText));

  /// آیا پیام شکل پرسشی دارد (حتی اگر پرسش حقوقی نباشد)؟
  static bool isQuestion(String rawText) {
    final n = _norm(rawText);
    if (n.isEmpty) return false;
    if (_questionMarkRe.hasMatch(n)) return true;
    if (_questionWords.hasMatch(n)) return true;
    return _advicePhrases.any(n.contains);
  }

  /// آیا پیام واژهٔ حقوقی دارد؟
  static bool hasLegalTerm(String rawText) {
    final n = _norm(rawText);
    if (n.isEmpty) return false;
    return _legalTerms.hasMatch(n);
  }

  /// آیا کاربر ارجاع مستقیم به یک ماده/اصل داده است؟
  static bool hasDirectArticle(String rawText) =>
      _directArticleRe.hasMatch(_norm(rawText));

  /// نشانه‌های «وضعیت شخصی»: ضمیر اول‌شخص یا فعل اول‌شخص.
  ///
  /// تفاوت مهم است: «مهلت واخواهی چقدر است؟» یک پرسش اطلاعاتی است و باید از
  /// متن قانون پاسخ بگیرد؛ اما «چک دادم بابت ضمانت برگشت زده، چه کار کنم؟»
  /// شرح یک پروندهٔ واقعی است و درخت مشاوره برای آن ساخته شده است.
  static final RegExp _personalCues = PersianText.wordRe(<String>[
    'من', 'مرا', 'خودم', 'مادرم', 'پدرم', 'همسرم', 'زنم', 'شوهرم', 'برادرم',
    'خواهرم', 'فرزندم', 'بچه‌ام', 'دوستم', 'همکارم', 'همسایه‌ام', 'رئیسم',
    'کارفرمایم', 'مستأجرم', 'موجرم', 'صاحبخانه‌ام', 'وکیل', 'پرونده‌ام',
    'چکم', 'قراردادم', 'حسابم', 'کارتم', 'حقوقم', 'بیمه‌ام', 'پولم', 'طلبم',
    'دارم', 'ندارم', 'دادم', 'گرفتم', 'بودم', 'هستم', 'رفتم', 'کردم',
    'کرده‌ام', 'شکایت کردم', 'اخراجم', 'برگشت زده', 'امضا کردم',
  ]);

  /// آیا پیام شرح یک وضعیت شخصی است (نه پرسش صرفاً اطلاعاتی)؟
  static bool isPersonalSituation(String rawText) {
    final n = _norm(rawText);
    if (n.isEmpty) return false;
    if (_personalCues.hasMatch(n)) return true;
    // «علیه من»، «برای من»، «به من» با فاصله هم پوشش داده می‌شود.
    return n.contains(' علیه من') ||
        n.startsWith('من ') ||
        n.contains(' برای من') ||
        n.contains(' به من ');
  }

  /// پرسش صرفاً اطلاعاتی است؟ (بدون نشانهٔ پروندهٔ شخصی)
  static bool isInformationalQuestion(String rawText) =>
      looksLikeLegalQuestion(rawText) && !isPersonalSituation(rawText);

  /// پرسش حقوقی است؟ این‌ها **همیشه** اول پاسخ می‌گیرند و نباید به مصاحبه
  /// یا درخواست انتخاب موضوع تبدیل شوند.
  static bool looksLikeLegalQuestion(String rawText) {
    final n = _norm(rawText);
    if (n.isEmpty) return false;
    if (hasDirectArticle(n)) return true;
    return isQuestion(n) && hasLegalTerm(n);
  }

  /// مواد نزدیک به پرسش، به شکل چیپ‌های قابل لمس.
  ///
  /// هر چیپ یک پرسش معتبر است («ماده ۴۶۶ قانون مدنی») که موتور دانش آن را
  /// با جست‌وجوی مستقیم ماده پاسخ می‌دهد؛ پس کاربر با یک لمس، به پاسخ
  /// می‌رسد و گفتگو در بن‌بست نمی‌ماند.
  static List<String> nearbyArticleChips(
    KnowledgeEngine engine,
    String rawQuery, {
    int k = 3,
  }) {
    final out = <String>[];
    if (rawQuery.trim().isEmpty) return out;
    final ranked = engine.rank(rawQuery, k: k + 3);
    for (final hit in ranked.hits) {
      if (hit.score < 0.3) continue;
      final chunk = hit.chunk;
      if (chunk.obsolete) continue;
      final isArticle = chunk.title.startsWith('ماده ') ||
          chunk.title.startsWith('اصل ');
      if (!isArticle) continue;
      final label = PersianText.collapse('${chunk.title} ${chunk.source}');
      if (label.isEmpty || out.contains(label)) continue;
      out.add(label);
      if (out.length >= k) break;
    }
    return out;
  }
}

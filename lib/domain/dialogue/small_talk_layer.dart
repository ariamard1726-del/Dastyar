import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/domain/legal_counselor.dart';

class SmallTalkLayer {
  const SmallTalkLayer();

  static const List<String> defaultIntakeChips = <String>[
    'چک برگشتی', 'اختلاف کاری', 'اجاره و ملک', 'خانواده و مهریه', 
    'کلاهبرداری', 'نزاع و ضرب و جرح', 'دعوای حقوقی', 'بدهی و مطالبه',
  ];

  static const List<String> activeSessionChips = <String>[
    'ادامه بررسی پرونده', 'سؤال جدید دارم',
  ];

  // محافظ کلمات حقوقی (اگر کلمه حقوقی در متن بود، SmallTalk آن را نمی‌بلعد)
  static final RegExp _legalWords = PersianText.wordRe([
    'چک', 'سفته', 'برات', 'اجاره', 'موجر', 'مستاجر', 'مهریه', 'نفقه', 
    'طلاق', 'حضانت', 'کارفرما', 'اخراج', 'کلاهبرداری', 'ضرب', 'جرح', 
    'دعوا', 'شکایت', 'دادگاه', 'بدهی', 'طلب', 'ماده', 'قانون'
  ]);

  static final RegExp _greetingRe = PersianText.wordRe([
    'سلام', 'درود', 'وقت بخیر', 'صبح بخیر', 'عصر بخیر', 'شب بخیر', 'سلام علیکم'
  ]);
  
  static final RegExp _howAreYouRe = PersianText.wordRe([
    'چطوری', 'چطورید', 'خوبی', 'خوبید', 'حالت چطوره', 'حال شما چطوره', 'چه خبر'
  ]);
  
  static final RegExp _thanksRe = PersianText.wordRe([
    'ممنون', 'مرسی', 'متشکرم', 'تشکر', 'سپاس', 'دستت درد نکنه'
  ]);
  
  static final RegExp _distressRe = PersianText.wordRe([
    'حالم خوب نیست', 'حالم بده', 'خسته ام', 'خسته شدم', 'اعصابم خرده', 
    'ناراحتم', 'کلافه ام', 'داغونم', 'استرس دارم', 'نگرانم'
  ]);
  
  static final RegExp _metaNextStepRe = PersianText.wordRe([
    'الان چکار کنم', 'الان چیکار کنم', 'باید چه کار کنم', 'قدم بعدی چیه', 'حالا چی'
  ]);
  
  static final RegExp _offTopicRe = PersianText.wordRe([
    'چه کتابی', 'چه فیلمی', 'هوا چطوره', 'ساعت چنده', 'جوک بگو', 'شعر بگو'
  ]);

  CounselorTurn? tryHandle(String rawText, {required bool hasActiveLegalContext}) {
    final t = PersianText.phrase(rawText); // نرمال‌سازی با تابع پروژه شما
    if (t.isEmpty) return null;

    // ۱. کلمات حقوقی همیشه در اولویت هستند و SmallTalk آن‌ها را رد می‌کند
    if (_legalWords.hasMatch(t)) return null;
    
    // ۲. پاسخ‌های کوتاه (بله/خیر) مربوط به پلنر است
    if (t.length <= 4) return null;

    // ۳. تشخیص نیت
    if (_greetingRe.hasMatch(t)) return _buildTurn(_reply('greeting', hasActiveLegalContext));
    if (_howAreYouRe.hasMatch(t)) return _buildTurn(_reply('howAreYou', hasActiveLegalContext));
    if (_thanksRe.hasMatch(t)) return _buildTurn(_reply('thanks', hasActiveLegalContext));
    if (_distressRe.hasMatch(t)) return _buildTurn(_reply('distress', hasActiveLegalContext));
    if (_metaNextStepRe.hasMatch(t)) return _buildTurn(_reply('metaNext', hasActiveLegalContext));
    if (_offTopicRe.hasMatch(t)) return _buildTurn(_reply('offTopic', hasActiveLegalContext));

    return null;
  }

  String _reply(String intent, bool active) {
    switch (intent) {
      case 'greeting':
        return active 
            ? 'سلام، وقت بخیر. در خدمتم. هر وقت آماده بودید، پرونده‌تان را از همان‌جا که بودیم ادامه دهیم.' 
            : 'سلام و وقت بخیر. من دستیار حقوقی شما هستم. بفرمایید چه موضوعی پیش آمده تا با هم بررسی کنیم.';
      case 'howAreYou':
        return active 
            ? 'خوبم، ممنون که پرسیدید. شما چطورید؟ هر وقت آماده بودید، ادامه پرونده‌تان را بگویید.' 
            : 'خوبم، ممنون که پرسیدید. شما چطورید؟ اگر موضوع حقوقی‌ای ذهنتان را مشغول کرده، همین‌جا بگویید.';
      case 'thanks':
        return active 
            ? 'خواهش می‌کنم، وظیفه است. اگر نکته دیگری در همین پرونده هست، بفرمایید.' 
            : 'خواهش می‌کنم. هر وقت سؤال حقوقی داشتید، در خدمتم.';
      case 'distress':
        return active 
            ? 'متأسفم که این‌قدر فشار رویتان است؛ کاملاً طبیعی است. عجله‌ای نیست. هر وقت آماده بودید، سؤال قبلی را پاسخ بدهید تا با هم مسیر را روشن کنیم.' 
            : 'متأسفم که حالتان خوب نیست و واقعاً درکتان می‌کنم. اگر موضوعی حقوقی باعث این فشار شده، همین‌جا بگویید؛ با هم قدم‌به‌قدم بررسی می‌کنیم.';
      case 'metaNext':
        return active 
            ? 'کاملاً درک می‌کنم که می‌خواهید زودتر به نتیجه برسید. برای اینکه راهنمایی‌ام دقیق باشد، کافی است پاسخ سؤال قبلی را بدهید تا بلافاصله قدم بعدی را مشخص کنم.' 
            : 'حتماً کمکتان می‌کنم. برای اینکه بدانم از کجا شروع کنیم، کمی بگویید دقیقاً چه اتفاقی افتاده، یا یکی از گزینه‌های زیر را انتخاب کنید.';
      case 'offTopic':
        return active 
            ? 'این موضوع از تخصص من خارج است، ولی خوشحالم که راحت صحبت می‌کنید. اجازه بدهید فعلاً پرونده حقوقی‌تان را به نتیجه برسانیم.' 
            : 'در این زمینه نمی‌توانم کمک کنم، چون کار من فقط موضوعات حقوقی است. اگر مسئله حقوقی دارید، یکی از گزینه‌ها را انتخاب کنید یا ماجرا را بنویسید.';
      default:
        return 'در خدمتم.';
    }
  }

  CounselorTurn _buildTurn(String text) {
    return CounselorTurn(
      text: text,
      chips: defaultIntakeChips,
      completed: false,
      cancelled: false,
    );
  }
}

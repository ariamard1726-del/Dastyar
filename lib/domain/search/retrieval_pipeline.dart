import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/utils/persian_normalizer.dart';
import 'package:dastyar/domain/dialogue/evidence.dart';

/// لایهٔ نازک روی `KnowledgeEngine` که بازیابی را از orchestration
/// (Assistant) جدا می‌کند.
///
/// چرا این کلاس وجود دارد؟
///   • `Assistant` نباید بداند که بازیابی از `engine.query` استفاده
///     می‌کند یا فردا از `retrieveWithEvidence` یا هر روش دیگر.
///   • در آینده می‌توان retrieval را با cache یا backend دیگر عوض کرد
///     بدون دست زدن به Assistant.
///   • تست `Assistant` با mock کردن این کلاس ساده‌تر می‌شود.
class RetrievalPipeline {
  final KnowledgeEngine _engine;

  RetrievalPipeline(this._engine);

  /// بازیابی پاسخ موتور با پیشنهادهای نزدیک.
  EngineReply retrieve(String question, {int maxAlternatives = 3}) {
    return _engine.query(question, maxAlternatives: maxAlternatives);
  }

  /// بازیابی ساخت‌یافته (EvidenceSet) برای planner در Phase 2.
  EvidenceSet retrieveWithEvidence(String question, {int k = 3}) {
    return _engine.retrieveWithEvidence(question, k: k);
  }

  // ---------------------------------------------------------------------
  // افت تدریجی کیفیت (Graceful Degradation)
  // ---------------------------------------------------------------------

  /// زیر این شباهت، پاسخ نمی‌دهیم تا چیزی ساختگی نگوییم.
  static const double refuseBelow = 0.50;

  /// زیر این شباهت (و بالای [refuseBelow])، «پاسخ پل» می‌دهیم.
  static const double bridgeBelow = 0.65;

  static final RegExp _extraLegalCueRe = RegExp(
      r'قانون|ماده|دادگاه|شکایت|وکیل|حقوق|چک|اجاره|طلاق|مهریه|نفقه|قرارداد|دادخواست|جرم|سربازی|خدمت|ارث|وصیت|ثبت|سند|ملک|بدهی|طلب|حکم|رأی|رای|جریمه|مجازات|زندان|حبس|کلاهبردار|توهین|تهدید|اخراج|بیمه|مالیات|شورا|خسارت|ضمانت|سفته');

  static final RegExp _chatRe = RegExp(
      r'کار[\s\u200c]*تو|تو[\s\u200c]*(?:کی|چی|خیلی)|اسمت|کی[\s\u200c]*هستی|چرا[\s\u200c]*(?:به[\s\u200c]*)?من|خوبی|چطوری|سلام[\s\u200c]*علیک|مرسی|ممنون');

  static bool _isNotLegal(String q) {
    if (_extraLegalCueRe.hasMatch(q)) return false;
    if (_offTopicRe.hasMatch(q) || _chatRe.hasMatch(q)) return true;
    final words = q.trim().split(RegExp(r'\s+'));
    return words.length >= 2 && words.length <= 3 && !RegExp(r'\d|[۰-۹]').hasMatch(q);
  }

  static const List<String> _outOfScopeReplies = [
    'این سؤال خارج از حوزه‌ی دستیار حقوقی است. اگر مشکل یا پرسش حقوقی دارید (مثل چک، اجاره، کار یا خانواده)، کوتاه بنویسید تا کمک کنم.',
    'این پیام خارج از حوزه‌ی دستیار حقوقی است. من فقط دربارهٔ مسائل حقوقی و قوانین ایران پاسخ می‌دهم. اگر موضوعی مثل شکایت، قرارداد یا مهریه دارید، بفرمایید.',
    'این پیام خارج از حوزه‌ی دستیار حقوقی است. متوجه منظورتان نشدم و به نظر نمی‌رسد موضوع حقوقی باشد. اگر مشکل قانونی دارید، ماجرا را در یک یا دو جمله بنویسید.',
    'این پیام خارج از حوزه‌ی دستیار حقوقی است. این موضوع از تخصص من بیرون است. در امور حقوقی مثل چک، طلاق، اجاره و کار می‌توانم کمک کنم.',
    'این پیام خارج از حوزه‌ی دستیار حقوقی است. برای این پیام مبنای حقوقی پیدا نکردم. اگر سؤال یا مشکل حقوقی دارید، همین‌جا بنویسید تا مرحله‌به‌مرحله بررسی کنیم.',
    'این پیام خارج از حوزه‌ی دستیار حقوقی است. اینجا دستیار حقوقی است و برای موضوعات دیگر پاسخ مطمئنی ندارم. هر وقت پرسش قانونی داشتید، در خدمتم.',
    'این پیام خارج از حوزه‌ی دستیار حقوقی است. اگر ناراحتی یا ایرادی از پاسخ‌هایم دارید بگویید. برای ادامه، مشکل حقوقی‌تان را کوتاه بنویسید تا دقیق‌تر کمک کنم.',
    'این پیام خارج از حوزه‌ی دستیار حقوقی است. حرف شما را متوجه نشدم. می‌توانید بنویسید چه مشکل حقوقی‌ای پیش آمده (مثلاً چک، اجاره، شکایت یا ارث)؟',
  ];

  static String _outOfScopeReply(String q) =>
      _outOfScopeReplies[DateTime.now().microsecondsSinceEpoch % _outOfScopeReplies.length];

  static final RegExp _offTopicRe = RegExp(
      r'هوا|فوتبال|والیبال|استقلال|پرسپولیس|آشپزی|دستور[\s\u200c]*پخت|قیمت[\s\u200c]*(دلار|سکه|طلا)|سریال|آهنگ|موسیقی|جوک|لطیفه|ساعت[\s\u200c]*چنده');
  static final RegExp _legalCueRe = RegExp(
      r'قانون|ماده|دادگاه|شکایت|وکیل|حقوق|چک|اجاره|طلاق|مهریه|قرارداد|دادخواست|جرم');

  static bool _isClearlyOffTopic(String q) =>
      _offTopicRe.hasMatch(q) && !_legalCueRe.hasMatch(q);

  /// پاسخ مناسب وقتی بازیابی مطمئن نیست.
  ///
  /// - شباهت < ۰٫۵۰ (یا نامعتبر): عذرخواهی مؤدبانه، صراحت دربارهٔ نبود
  ///   اطلاعات دقیق، و پیشنهاد مشورت با وکیل و «معاضدت کانون وکلا».
  /// - ۰٫۵۰ تا ۰٫۶۵: «پاسخ پل»؛ خلاصهٔ یک‌جمله‌ای **فقط از کلمات خود
  ///   کاربر** (خلاصه‌سازی استخراجی) + نام خوانای موضوع + پرسش جزئیات.
  /// - ≥ ۰٫۶۵: رشتهٔ خالی، یعنی پاسخ کامل را عادی تولید کنید.
  static String handleLowConfidenceRetrieval(
    String userQuery, {
    required double similarity,
    String? candidateTopic,
  }) {
    if (!similarity.isNaN && similarity >= bridgeBelow) return '';
    if ((similarity.isNaN || similarity < refuseBelow) &&
        _isNotLegal(userQuery)) {
      return _outOfScopeReply(userQuery);
    }
    if (false) {
      return 'این سؤال خارج از حوزه‌ی دستیار حقوقی است و من فقط دربارهٔ '
          'مسائل حقوقی و قوانین ایران پاسخ می‌دهم.\n\n'
          'اگر مشکل یا سؤال حقوقی دارید (مثل چک، اجاره، کار، خانواده یا '
          'شکایت)، همین‌جا کوتاه بنویسید تا کمک کنم.';
    }
    if (similarity.isNaN || similarity < refuseBelow) {
      return 'متأسفانه دربارهٔ این موضوع اطلاعات دقیق و مطمئنی در منابع من نیست '
          'و نمی‌خواهم با حدس زدن، شما را به اشتباه بیندازم.\n\n'
          'پیشنهاد می‌کنم موضوع را با یک وکیل دادگستری در میان بگذارید. اگر '
          'هزینهٔ وکیل برایتان سنگین است، می‌توانید از «معاضدت کانون وکلا» یا '
          'مراکز مشاورهٔ حقوقی رایگان کمک بگیرید.\n\n'
          'اگر بخواهید، می‌توانید سؤالتان را با جزئیات بیشتری بنویسید تا دوباره '
          'جست‌وجو کنم.';
    }
    final summary = extractiveSummary(userQuery);
    final topic = topicLabel(candidateTopic);
    final b = StringBuffer();
    if (summary.isNotEmpty) {
      b
        ..writeln('برداشت من از صحبت شما این است: «$summary»')
        ..writeln();
    }
    b.writeln(topic == null
        ? 'برای اینکه پاسخ دقیق و مستندی بدهم، به چند جزئیات بیشتر نیاز دارم:'
        : 'به نظر می‌رسد موضوع شما به $topic مربوط است، اما برای اینکه '
            'پاسخ دقیق و مستندی بدهم، به چند جزئیات بیشتر نیاز دارم:');
    b
      ..writeln('• طرف مقابل شما کیست (شخص، شرکت، کارفرما، صاحبخانه، اداره…)؟')
      ..write('• چه مدرکی در دست دارید (قرارداد، فیش واریز، چک، پیامک، شاهد…)؟');
    return b.toString();
  }

  /// نام خوانای موضوع‌ها (هم برچسب‌های شبکهٔ قصد، هم قصدهای قالب‌ها).
  static const Map<String, String> topicLabels = {
    'debt': 'دعاوی مالی',
    'demand_money': 'دعاوی مالی',
    'cheque': 'دعاوی چک',
    'cheque_execution': 'دعاوی چک',
    'cheque_complaint': 'دعاوی چک',
    'complaint': 'شکایت کیفری',
    'criminal_harm': 'جرایم علیه اشخاص (توهین، تهدید، ضرب و جرح)',
    'fraud_cyber': 'کلاهبرداری و جرایم رایانه‌ای',
    'family': 'حقوق خانواده',
    'labor': 'حقوق کار',
    'lease': 'اجاره و روابط موجر و مستأجر',
    'litigation_defense': 'دفاع در دعاوی و آیین دادرسی',
    'defense_brief': 'دفاع در دعاوی و آیین دادرسی',
    'insolvency': 'اعسار و تقسیط',
    'legal_aid': 'معاضدت قضایی و وکیل رایگان',
    'formal_notice': 'اظهارنامه و اخطار رسمی',
    'inheritance': 'ارث و ترکه',
    'contract': 'قراردادها',
  };

  static String? topicLabel(String? topic) {
    final t = topic?.trim() ?? '';
    if (t.isEmpty || t == 'none') return null;
    return topicLabels[t];
  }

  static const Set<String> _stopwords = {
    'و', 'در', 'به', 'از', 'که', 'را', 'رو', 'با', 'این', 'آن', 'اون',
    'برای', 'یک', 'یه', 'است', 'هست', 'هستم', 'بود', 'شد', 'من', 'تو',
    'شما', 'او', 'ما', 'هم', 'یا', 'تا', 'بر', 'چه', 'چی', 'آیا',
    'سلام', 'لطفا', 'ممنون', 'مرسی', 'خیلی', 'وقت', 'بخیر', 'خسته',
    'نباشید', 'ببخشید', 'میخواستم', 'بپرسم', 'سوال', 'سؤال', 'دارم',
    'داشتم', 'کنم', 'کنید', 'کرد', 'کردم', 'میشه', 'بگید', 'بگویید',
  };

  /// واژه‌های حقوقی که آگاهی‌بخشی جمله را بیشتر می‌کنند.
  static const Set<String> _legalTerms = {
    'چک', 'سفته', 'طلب', 'قرض', 'بدهی', 'پول', 'مبلغ', 'تومان', 'شکایت',
    'قرارداد', 'اجاره', 'ودیعه', 'رهن', 'مستاجر', 'صاحبخانه', 'کارفرما',
    'حقوق', 'بیمه', 'اخراج', 'مهریه', 'نفقه', 'طلاق', 'حضانت', 'ارث',
    'کلاهبرداری', 'سرقت', 'تهدید', 'توهین', 'کتک', 'دادگاه', 'دادسرا',
    'ابلاغیه', 'رای', 'حکم', 'اجراییه', 'وکیل', 'سند', 'فیش', 'شاهد',
  };

  /// خلاصهٔ استخراجی یک‌جمله‌ای: آگاهی‌بخش‌ترین جملهٔ خود کاربر را
  /// **بدون بازنویسی** برمی‌گرداند (حداکثر [maxWords] واژه).
  ///
  /// امتیاز هر جمله = تعداد واژه‌های غیرایست + ۲ × واژه‌های حقوقی + ۰٫۵ ×
  /// عددها. در تساوی، جملهٔ زودتر انتخاب می‌شود.
  static String extractiveSummary(String text, {int maxWords = 20}) {
    final sentences = text
        .split(RegExp(r'[.!؟?\n؛;]+|،\s*(?=ولی|اما|و\s+حالا)'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (sentences.isEmpty) return '';
    var best = '';
    var bestScore = -1.0;
    for (final s in sentences) {
      var score = 0.0;
      for (final tok in PersianNormalizer.tokens(s)) {
        if (_stopwords.contains(tok) || (tok.length < 2 && !_isDigit(tok))) {
          continue;
        }
        score += 1;
        if (_legalTerms.any((t) =>
            PersianNormalizer.containsPhraseTokens([tok], [t]))) {
          score += 2;
        }
        if (_isDigit(tok)) score += 0.5;
      }
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }
    if (bestScore <= 0) return '';
    final words = best.split(RegExp(r'\s+'));
    final clipped = words.length <= maxWords
        ? best
        : '${words.take(maxWords).join(' ')}…';
    return clipped.replaceAll(RegExp(r'^[،,\s]+|[،,\s]+$'), '');
  }

  static bool _isDigit(String t) => RegExp(r'^\d+$').hasMatch(t);
}

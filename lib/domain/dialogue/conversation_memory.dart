import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/core/utils/persian_normalizer.dart';

/// حافظهٔ کوتاه‌مدت گفتگو برای درک پرسش‌های پیگیری
/// («ماده بعدی‌اش؟»، «مهلتش چقدره؟»).
///
/// این کلاس در Phase 0.2 از `legal_counselor.dart` به اینجا منتقل شد
/// تا چرخهٔ وابستگی کاهش یابد و بتواند در `dialogue_state.dart`
/// (Phase 0.3) نیز به کار گرفته شود. رفتار کلاس نسبت به نسخهٔ قبلی
/// بدون تغییر است.
class ConversationMemory {
  String lastTopicQuery = '';
  String lastLawId = '';
  String lastLawTitle = '';
  int? lastArticleNum;
  String lastArticleKind = 'ماده';

  void clear() {
    lastTopicQuery = '';
    lastLawId = '';
    lastLawTitle = '';
    lastArticleNum = null;
    lastArticleKind = 'ماده';
  }

  static final RegExp _artNumRe = RegExp(r'^(ماده|اصل)\s+(\d+)$');

  void recordTurn(String userQuery, EngineReply reply) {
    final cleanQ = PersianText.collapse(PersianText.normalize(userQuery));
    if (cleanQ.length >= 4) {
      lastTopicQuery = userQuery.trim();
    }
    if (reply.contextHits.isNotEmpty) {
      final top = reply.contextHits.first.chunk;
      if (top.lawId.isNotEmpty && top.lawId != 'knowledge') {
        lastLawId = top.lawId;
        lastLawTitle = top.source;
        final m = _artNumRe.firstMatch(top.normTitle);
        if (m != null) {
          lastArticleKind = m.group(1)!;
          lastArticleNum = int.tryParse(m.group(2)!);
        }
      }
    }
  }

  static final List<String> _nextMarkers = [
    'ماده بعدی',
    'ماده بعد',
    'اصل بعدی',
    'اصل بعد',
    'بعدی اش',
    'بعدیش',
  ];
  static final List<String> _prevMarkers = [
    'ماده قبلی',
    'ماده قبل',
    'اصل قبلی',
    'اصل قبل',
    'قبلی اش',
    'قبلیش',
  ];
  static final List<String> _ellipticalMarkers = [
    'مهلتش',
    'مجازاتش',
    'شرایطش',
    'مدارکش',
    'حکمش',
    'کجا باید برم',
    'کجا شکایت کنم',
    'کجا مراجعه کنم',
    'چطور اقدام کنم',
    'چگونه اقدام کنم',
    'قابل گذشت است',
    'قابل گذشت هست',
    'اگر ندهد',
    'اگر نپردازد',
    'اگر قبول نکرد',
  ];

  /// بازنویسی هوشمند پرسش‌های کوتاهِ وابسته به پیام قبلی
  /// (بدون تغییر پرسش‌های مستقل).
  String resolveFollowUp(String rawQuestion) {
    final n = PersianText.collapse(PersianText.normalize(rawQuestion));
    if (lastArticleNum != null && lastLawTitle.isNotEmpty) {
      if (_nextMarkers.any(n.contains)) {
        final nextN = lastArticleNum! + 1;
        return '$lastArticleKind $nextN $lastLawTitle';
      }
      if (_prevMarkers.any(n.contains) && lastArticleNum! > 1) {
        final prevN = lastArticleNum! - 1;
        return '$lastArticleKind $prevN $lastLawTitle';
      }
    }

    if (lastTopicQuery.isEmpty) return rawQuestion;
    final words = PersianText.tokenizeIndex(rawQuestion);
    if (words.length <= 5 && _ellipticalMarkers.any(n.contains)) {
      return '$rawQuestion درباره $lastTopicQuery';
    }
    return rawQuestion;
  }
}

// ---------------------------------------------------------------------------
// پرکردن فعال اسلات‌ها (Active Slot Filling)
// ---------------------------------------------------------------------------

/// مقدار تمیزِ یک اسلاتِ استخراج‌شده.
///
/// - [raw]: مقدار خام/کانونی (مثلاً `bank_slip` یا متنی که از پیام کاربر
///   برداشته شد)،
/// - [display]: متن خوانا برای نمایش به کاربر («۵۰ میلیون تومان»)،
/// - [value]: مقدار عددی اختیاری (مبلغ به تومان، تاریخ `yyyymmdd`، یا
///   تعداد روزِ گذشته برای تاریخ نسبی).
///
/// این کلاس از `SlotValue` در `slot.dart` (لایهٔ DialogueState) جداست و
/// فقط در [DialogueStateManager] به کار می‌رود.
class SlotValue {
  const SlotValue({required this.raw, required this.display, this.value});

  final String raw;
  final String display;
  final num? value;

  @override
  bool operator ==(Object other) =>
      other is SlotValue &&
      other.raw == raw &&
      other.display == display &&
      other.value == value;

  @override
  int get hashCode => Object.hash(raw, display, value);

  @override
  String toString() => 'SlotValue($raw, $display, $value)';
}

/// مدیر وضعیت گفتگو برای پرکردن فعال اسلات‌های یک قصد.
///
/// جریان معمول:
/// ```dart
/// final m = DialogueStateManager(intent: 'demand_money');
/// m.extractAndUpdate('دوستم ۵۰ میلیون تومان قرض گرفته');
/// m.getNextQuestion(); // «متوجه شدم، مبلغ ۵۰ میلیون تومان ثبت شد. حالا …»
/// ```
///
/// کاملاً قطعی است: تنوع جمله‌ها با شمارندهٔ داخلی چرخانده می‌شود، نه Random.
class DialogueStateManager {
  DialogueStateManager({String? intent}) : _intent = intent;

  // نام اسلات‌ها
  static const String amount = 'amount';
  static const String proof = 'proof';
  static const String date = 'date';
  static const String incidentType = 'incidentType';
  static const String incomeStatus = 'incomeStatus';

  /// اسلات‌های هر قصد به ترتیب پرسیدن.
  static const Map<String, List<String>> intentSlots = {
    'demand_money': [amount, proof, date],
    'complaint': [incidentType, date, proof],
    'insolvency': [amount, incomeStatus],
  };

  static const Map<String, String> slotLabels = {
    amount: 'مبلغ',
    proof: 'مدرک',
    date: 'تاریخ',
    incidentType: 'نوع اتفاق',
    incomeStatus: 'وضعیت درآمد',
  };

  String? _intent;
  final Map<String, SlotValue> _slots = {};
  final Map<String, int> _askCounts = {};
  final List<String> _lastFilled = [];
  String? _pendingSlot;
  int _ackCounter = 0;

  String? get intent => _intent;

  /// تغییر قصد. اسلات‌های مشترک (مثل مبلغ) حفظ می‌شوند مگر [clearSlots].
  void setIntent(String? intent, {bool clearSlots = false}) {
    _intent = intent;
    _pendingSlot = null;
    if (clearSlots) {
      _slots.clear();
      _lastFilled.clear();
    }
  }

  Map<String, SlotValue> get slots => Map.unmodifiable(_slots);

  SlotValue? slot(String name) => _slots[name];

  /// اسلاتی که آخرین بار پرسیده شد (برای تفسیر پاسخ‌های کوتاه).
  String? get pendingSlot => _pendingSlot;

  List<String> get requiredSlots => intentSlots[_intent] ?? const [];

  List<String> get missingSlots =>
      [for (final s in requiredSlots) if (!_slots.containsKey(s)) s];

  bool get isComplete => _intent != null && missingSlots.isEmpty;

  void reset() {
    _slots.clear();
    _askCounts.clear();
    _lastFilled.clear();
    _pendingSlot = null;
    _ackCounter = 0;
  }

  // ----------------------------------------------------------- استخراج

  /// همهٔ اسلات‌های قابل استخراج از [userText] را پیدا و ذخیره می‌کند و
  /// اسلات‌های تازه‌پرشده (یا اصلاح‌شده) را برمی‌گرداند.
  Map<String, SlotValue> extractAndUpdate(String userText) {
    final found = <String, SlotValue>{};
    final prepared = prepare(userText);

    final d = extractDateFromPrepared(prepared);
    final withoutDate =
        d == null ? prepared.text : prepared.text.replaceFirst(d.$2, ' ');
    if (d != null) found[date] = d.$1;

    final a = extractAmount(withoutDate);
    if (a != null) found[amount] = a;

    final p = extractProof(userText);
    if (p != null) found[proof] = p;

    final i = extractIncident(userText);
    if (i != null) found[incidentType] = i;

    final inc = extractIncomeStatus(userText);
    if (inc != null) found[incomeStatus] = inc;

    // پاسخ کوتاه به آخرین پرسش («ندارم»، «یادم نیست»، «۵۰۰۰۰۰۰۰»).
    final pending = _pendingSlot;
    if (pending != null && !found.containsKey(pending)) {
      final f = _fallbackForPending(pending, userText, withoutDate);
      if (f != null) found[pending] = f;
    }

    _lastFilled.clear();
    for (final e in found.entries) {
      if (_slots[e.key] != e.value) {
        _slots[e.key] = e.value;
        _lastFilled.add(e.key);
      }
    }
    if (_pendingSlot != null && _slots.containsKey(_pendingSlot)) {
      _pendingSlot = null;
    }
    return {for (final k in _lastFilled) k: _slots[k]!};
  }

  SlotValue? _fallbackForPending(String slot, String text, String prepared) {
    final n = PersianNormalizer.normalizeForMatching(text);
    bool has(List<String> ps) =>
        ps.any((p) => PersianNormalizer.containsPhrase(n, p));
    const dontKnow = ['نمی‌دانم', 'نمیدونم', 'یادم نیست', 'خاطرم نیست', 'مطمئن نیستم'];
    const negative = ['ندارم', 'نه', 'خیر', 'هیچی', 'هیچ'];
    switch (slot) {
      case proof:
        if (has(negative)) {
          return const SlotValue(raw: 'none', display: 'بدون مدرک کتبی');
        }
      case date:
        if (has(dontKnow)) {
          return const SlotValue(raw: 'unknown', display: 'تاریخ دقیق نامعلوم');
        }
      case amount:
        if (has(dontKnow)) {
          return const SlotValue(raw: 'unknown', display: 'مبلغ دقیق نامعلوم');
        }
        final m = RegExp(r'^\s*(\d+(?:\.\d+)?)\s*$').firstMatch(prepared);
        final v = m == null ? null : num.tryParse(m.group(1)!);
        if (v != null && v >= 1000) {
          return SlotValue(
              raw: m!.group(1)!, display: formatAmount(v, 'تومان'), value: v);
        }
      case incomeStatus:
        if (has(negative)) {
          return const SlotValue(raw: 'no_income', display: 'بدون درآمد');
        }
      case incidentType:
        final words = text.trim().split(RegExp(r'\s+'));
        if (words.length >= 2) {
          final snippet = words.take(6).join(' ');
          return SlotValue(
            raw: 'other',
            display: words.length > 6 ? '$snippet…' : snippet,
          );
        }
    }
    return null;
  }

  // ------------------------------------------------------------- پرسش

  /// پرسش بعدی برای اولین اسلات خالی، همراه تأیید اسلاتی که تازه پر شد.
  ///
  /// اگر همهٔ اسلات‌ها پر باشد و چیز تازه‌ای برای تأیید باشد، جملهٔ
  /// جمع‌بندی برمی‌گردد؛ اگر نه، `null`. بدون قصد هم `null` است.
  String? getNextQuestion() {
    if (_intent == null || requiredSlots.isEmpty) return null;
    final ack = _acknowledgement();
    final missing = missingSlots;
    if (missing.isEmpty) {
      _pendingSlot = null;
      if (ack == null) return null;
      return '$ack اطلاعات اصلی پرونده کامل شد.';
    }
    final next = missing.first;
    final count = _askCounts[next] ?? 0;
    _askCounts[next] = count + 1;
    _pendingSlot = next;
    final variants = _questionVariants(_intent!, next);
    final q = variants[count % variants.length];
    return ack == null ? q : '$ack حالا $q';
  }

  String? _acknowledgement() {
    if (_lastFilled.isEmpty) return null;
    final parts = [
      for (final k in _lastFilled)
        if (requiredSlots.contains(k))
          '${slotLabels[k] ?? k} ${_slots[k]!.display}',
    ];
    _lastFilled.clear();
    if (parts.isEmpty) return null;
    final joined = parts.length == 1
        ? parts.first
        : '${parts.sublist(0, parts.length - 1).join('، ')} و ${parts.last}';
    final verb = parts.length == 1 ? 'ثبت شد' : 'ثبت شدند';
    final lead = switch (_ackCounter++ % 3) {
      0 => 'متوجه شدم،',
      1 => 'بسیار خب،',
      _ => 'ممنون،',
    };
    return '$lead $joined $verb.';
  }

  static List<String> _questionVariants(String intent, String slot) {
    switch ((intent, slot)) {
      case ('insolvency', amount):
        return const [
          'مبلغ بدهی یا محکومیت مالی شما چقدر است؟',
          'بفرمایید جمع بدهی‌ای که باید بپردازید حدوداً چقدر است؟',
          'برای درخواست اعسار، مبلغ محکومیت یا بدهی را بدانم؛ چقدر است؟',
        ];
      case (_, amount):
        return const [
          'مبلغ طلب شما چقدر است؟',
          'بفرمایید طرف مقابل دقیقاً چه مبلغی به شما بدهکار است؟',
          'حدوداً چقدر پول در میان است؟',
        ];
      case ('complaint', date):
        return const [
          'این اتفاق کی افتاد؟',
          'بفرمایید ماجرا در چه تاریخی رخ داد؟ (حتی تقریبی، مثل «ماه پیش»)',
          'یادتان هست چه روزی این اتفاق افتاد؟',
        ];
      case (_, date):
        return const [
          'پول را در چه تاریخی داده‌اید یا قرار بود کی پس بدهد؟',
          'بفرمایید سررسید یا تاریخ پرداخت چه زمانی بود؟ (حتی تقریبی)',
          'یادتان هست این مبلغ کی رد و بدل شد؟',
        ];
      case ('complaint', proof):
        return const [
          'چه مدرکی از این اتفاق دارید؟ (مثل فیلم، عکس، پیام، شاهد یا گواهی پزشکی قانونی)',
          'آیا شاهد، فیلم، پیام یا گواهی پزشکی قانونی دارید؟',
          'برای اثبات ماجرا چه چیزی در دست دارید؟',
        ];
      case (_, proof):
        return const [
          'چه مدرکی برای این طلب دارید؟ (مثل فیش واریز، چک، سفته، قرارداد یا پیامک)',
          'آیا فیش واریز، قرارداد، پیامک یا شاهدی دارید؟',
          'برای اثبات طلبتان چه مدرکی در دست است؟',
        ];
      case (_, incidentType):
        return const [
          'دقیقاً چه اتفاقی افتاده است؟ (مثلاً ضرب و شتم، توهین، تهدید، سرقت یا کلاهبرداری)',
          'لطفاً بفرمایید طرف مقابل چه کاری کرده است؟',
          'کمی از خود ماجرا بگویید؛ چه اتفاقی برایتان افتاد؟',
        ];
      case (_, incomeStatus):
        return const [
          'الان وضعیت درآمدتان چطور است؟ (مثلاً بیکار، حقوق‌بگیر یا شغل آزاد)',
          'بفرمایید درآمد ماهانهٔ ثابتی دارید یا نه؟',
          'برای اعسار مهم است بدانم از چه راهی و چقدر درآمد دارید؛ وضعیتتان چطور است؟',
        ];
    }
    return const ['لطفاً کمی بیشتر توضیح بدهید.'];
  }

  // -------------------------------------------------- پیش‌پردازش متن

  /// متن آمادهٔ استخراج عدد و تاریخ: ارقام یکدست، نیم‌فاصله → فاصله،
  /// جداکنندهٔ هزارگان حذف، و فاصله بین رقم و حرف.
  static ({String text}) prepare(String input) {
    var t = input.replaceAll('\u200c', ' ');
    t = PersianNormalizer.normalize(t);
    t = t.replaceAll('٫', '.');
    t = t.replaceAllMapped(
        RegExp(r'(\d)[,٬](?=\d{3})'), (m) => m.group(1)!);
    t = t.replaceAllMapped(
        RegExp(r'(\d)([^\d\s.,/\-])'), (m) => '${m.group(1)} ${m.group(2)}');
    t = t.replaceAllMapped(
        RegExp(r'([^\d\s.,/\-])(\d)'), (m) => '${m.group(1)} ${m.group(2)}');
    return (text: t.replaceAll(RegExp(r'\s+'), ' ').trim());
  }

  // ------------------------------------------------------------- مبلغ

  static const Map<String, num> _units = {
    'صفر': 0, 'یک': 1, 'یه': 1, 'دو': 2, 'سه': 3, 'چهار': 4, 'پنج': 5,
    'شش': 6, 'شیش': 6, 'هفت': 7, 'هشت': 8, 'نه': 9, 'ده': 10, 'یازده': 11,
    'دوازده': 12, 'سیزده': 13, 'چهارده': 14, 'پانزده': 15, 'پونزده': 15,
    'شانزده': 16, 'شونزده': 16, 'هفده': 17, 'هجده': 18, 'هیجده': 18,
    'نوزده': 19, 'بیست': 20, 'سی': 30, 'چهل': 40, 'پنجاه': 50, 'شصت': 60,
    'هفتاد': 70, 'هشتاد': 80, 'نود': 90, 'دویست': 200, 'سیصد': 300,
    'چهارصد': 400, 'پانصد': 500, 'پونصد': 500, 'ششصد': 600, 'هفتصد': 700,
    'هشتصد': 800, 'نهصد': 900,
  };

  static const Map<String, num> _scales = {
    'هزار': 1000,
    'میلیون': 1000000,
    'ملیون': 1000000,
    'میلیارد': 1000000000,
    'ملیارد': 1000000000,
  };

  static const Map<String, String> _currencies = {
    'تومان': 'تومان',
    'تومن': 'تومان',
    'ریال': 'ریال',
  };

  static final RegExp _edgePunct = RegExp(r'^[«»"()،؛:!؟?]+|[«»"()،؛:!؟?.]+$');

  static bool _isNumberToken(String t) =>
      RegExp(r'^\d+(\.\d+)?$').hasMatch(t) ||
      _units.containsKey(t) ||
      t == 'صد' ||
      t == 'نیم';

  /// مبلغ را از متن پیدا می‌کند: «50 میلیون تومان»، «پنجاه میلیون تومان»،
  /// «۲ میلیارد و ۵۰۰ میلیون»، «یک و نیم میلیون»، «50,000,000 تومان»،
  /// «۵۰۰ هزار ریال». فقط وقتی مبلغ است که واحد (هزار/میلیون/…) یا ارز
  /// (تومان/ریال) داشته باشد؛ پس «سه ماه» یا «۱۵ آبان» مبلغ نیستند.
  /// مقدار عددی همیشه به تومان است.
  static SlotValue? extractAmount(String text) {
    final prepared = prepare(text).text;
    final toks = prepared
        .split(' ')
        .map((t) => t.replaceAll(_edgePunct, ''))
        .where((t) => t.isNotEmpty)
        .toList();
    for (var i = 0; i < toks.length; i++) {
      if (!_isNumberToken(toks[i]) || toks[i] == 'نیم') continue;
      final r = _parseNumber(toks, i);
      if (r == null) continue;
      var end = r.end;
      String? currency;
      if (end < toks.length && _currencies.containsKey(toks[end])) {
        currency = _currencies[toks[end]];
        end++;
      }
      if (!r.hasScale && currency == null) {
        i = r.end - 1;
        continue;
      }
      final unit = currency ?? 'تومان';
      final toman = unit == 'ریال' ? r.value / 10 : r.value;
      final rawText = toks.sublist(i, end).join(' ');
      final display = unit == 'ریال'
          ? '${formatAmount(r.value, 'ریال')} (${formatAmount(toman, 'تومان')})'
          : formatAmount(r.value, 'تومان');
      return SlotValue(raw: rawText, display: display, value: toman);
    }
    return null;
  }

  static ({num value, int end, bool hasScale})? _parseNumber(
      List<String> toks, int start) {
    num total = 0;
    num current = 0;
    num lastScale = 0;
    var hasScale = false;
    var any = false;
    var i = start;
    while (i < toks.length) {
      final t = toks[i];
      final digit = RegExp(r'^\d+(\.\d+)?$').hasMatch(t);
      if (digit) {
        current += num.parse(t);
        any = true;
      } else if (_units.containsKey(t)) {
        current += _units[t]!;
        any = true;
      } else if (t == 'صد') {
        current = (current == 0 ? 1 : current) * 100;
        any = true;
      } else if (t == 'نیم' && any) {
        if (current == 0 && lastScale > 0) {
          total += lastScale / 2;
        } else {
          current += 0.5;
        }
      } else if (_scales.containsKey(t) && any) {
        final sc = _scales[t]!;
        total += (current == 0 ? 1 : current) * sc;
        current = 0;
        lastScale = sc;
        hasScale = true;
      } else if (t == 'و' &&
          any &&
          i + 1 < toks.length &&
          (_isNumberToken(toks[i + 1]))) {
        // ادامهٔ عدد مرکب
      } else {
        break;
      }
      i++;
    }
    if (!any) return null;
    return (value: total + current, end: i, hasScale: hasScale);
  }

  /// قالب‌بندی خوانای مبلغ: 1500000 → «۱ میلیون و ۵۰۰ هزار تومان».
  static String formatAmount(num value, String unit) {
    if (value <= 0) return PersianText.toFaDigits('0 $unit');
    if (value != value.roundToDouble()) {
      return PersianText.toFaDigits('${_trim(value)} $unit');
    }
    var n = value.round();
    final parts = <String>[];
    for (final (size, name) in const [
      (1000000000, 'میلیارد'),
      (1000000, 'میلیون'),
      (1000, 'هزار'),
    ]) {
      final q = n ~/ size;
      if (q > 0) {
        parts.add('$q $name');
        n -= q * size;
      }
    }
    if (n > 0) parts.add('$n');
    return PersianText.toFaDigits('${parts.join(' و ')} $unit');
  }

  static String _trim(num v) {
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  // ------------------------------------------------------------- تاریخ

  static const List<String> jalaliMonths = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
  ];

  static int _daysInMonth(int m) => m <= 6 ? 31 : (m <= 11 ? 30 : 30);

  static SlotValue _jalali(int y, int m, int d) {
    final disp = y > 0
        ? '$d ${jalaliMonths[m - 1]} $y'
        : '$d ${jalaliMonths[m - 1]}';
    return SlotValue(
      raw: y > 0
          ? '$y/${m.toString().padLeft(2, '0')}/${d.toString().padLeft(2, '0')}'
          : '${m.toString().padLeft(2, '0')}/${d.toString().padLeft(2, '0')}',
      display: PersianText.toFaDigits(disp),
      value: y > 0 ? y * 10000 + m * 100 + d : null,
    );
  }

  /// تاریخ را پیدا می‌کند: جلالی عددی (۱۴۰۳/۰۸/۱۵)، با نام ماه
  /// (۱۵ آبان ۱۴۰۳)، یا نسبی (دیروز، ماه پیش، سه هفته قبل، پارسال).
  /// برای تاریخ نسبی، [SlotValue.value] تعداد تقریبی روزهای گذشته است.
  static SlotValue? extractDate(String text) =>
      extractDateFromPrepared(prepare(text))?.$1;

  static (SlotValue, String)? extractDateFromPrepared(({String text}) p) {
    final t = p.text;

    final numeric =
        RegExp(r'(1[34]\d\d)\s*[/\-.]\s*(\d{1,2})\s*[/\-.]\s*(\d{1,2})')
            .firstMatch(t);
    if (numeric != null) {
      final y = int.parse(numeric.group(1)!);
      final m = int.parse(numeric.group(2)!);
      final d = int.parse(numeric.group(3)!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= _daysInMonth(m)) {
        return (_jalali(y, m, d), numeric.group(0)!);
      }
    }

    final months = jalaliMonths.join('|');
    final named = RegExp('(?:^| )(\\d{1,2}) ($months)(?: ماه)?(?: (1[34]\\d\\d))?(?= |\$)')
        .firstMatch(t);
    if (named != null) {
      final d = int.parse(named.group(1)!);
      final m = jalaliMonths.indexOf(named.group(2)!) + 1;
      final y = int.tryParse(named.group(3) ?? '') ?? 0;
      if (d >= 1 && d <= _daysInMonth(m)) {
        return (_jalali(y, m, d), named.group(0)!.trim());
      }
    }
    final monthYear =
        RegExp('(?:^| )($months)(?: ماه)? (1[34]\\d\\d)(?= |\$)').firstMatch(t);
    if (monthYear != null) {
      final m = jalaliMonths.indexOf(monthYear.group(1)!) + 1;
      final y = int.parse(monthYear.group(2)!);
      return (
        SlotValue(
          raw: '$y/${m.toString().padLeft(2, '0')}',
          display: PersianText.toFaDigits('${jalaliMonths[m - 1]} $y'),
          value: y * 10000 + m * 100,
        ),
        monthYear.group(0)!.trim(),
      );
    }

    // نسبی با عدد: «3 ماه پیش»، «سه هفته قبل»، «بیست و پنج روز پیش»، «چند ماه پیش»
    final words = (_units.keys.toList()..sort((a, b) => b.length - a.length))
        .join('|');
    final rel = RegExp(
            '(?:^| )((?:\\d+|(?:$words)(?: و (?:$words))*|چند)) ?(روز|هفته|ماه|سال) ?(پیش|قبل|گذشته)(?= |\$)')
        .firstMatch(t);
    if (rel != null) {
      final qRaw = rel.group(1)!;
      final unit = rel.group(2)!;
      num? q;
      if (qRaw != 'چند') {
        q = num.tryParse(qRaw) ??
            _parseNumber(qRaw.split(' '), 0)?.value;
      }
      final perUnit = const {'روز': 1, 'هفته': 7, 'ماه': 30, 'سال': 365}[unit]!;
      return (
        SlotValue(
          raw: rel.group(0)!.trim(),
          display: q == null
              ? 'چند $unit پیش'
              : PersianText.toFaDigits('${_trim(q)} $unit پیش'),
          value: q == null ? null : (q * perUnit).round(),
        ),
        rel.group(0)!.trim(),
      );
    }

    // نسبی بدون عدد
    for (final (phrase, display, days) in const [
      ('پریروز', 'پریروز', 2),
      ('دیروز', 'دیروز', 1),
      ('دیشب', 'دیشب', 1),
      ('امروز', 'امروز', 0),
      ('امشب', 'امشب', 0),
      ('امروز صبح', 'امروز', 0),
      ('هفته پیش', 'هفتهٔ پیش', 7),
      ('هفته قبل', 'هفتهٔ پیش', 7),
      ('هفته گذشته', 'هفتهٔ پیش', 7),
      ('ماه پیش', 'ماه پیش', 30),
      ('ماه قبل', 'ماه پیش', 30),
      ('ماه گذشته', 'ماه پیش', 30),
      ('سال پیش', 'سال پیش', 365),
      ('سال قبل', 'سال پیش', 365),
      ('سال گذشته', 'سال پیش', 365),
      ('پارسال', 'پارسال', 365),
    ]) {
      final m = RegExp('(?:^| )($phrase)(?= |\$)').firstMatch(t);
      if (m != null) {
        return (
          SlotValue(raw: phrase, display: display, value: days),
          m.group(1)!,
        );
      }
    }
    return null;
  }

  // ------------------------------------------------- واژه‌نامه‌ها

  /// واژه‌نامهٔ مدرک: عبارت → (کد، نمایش). بلندترین عبارت اول بررسی می‌شود.
  static const Map<String, (String, String)> proofLexicon = {
    'گواهی پزشکی قانونی': ('forensic', 'گواهی پزشکی قانونی'),
    'پزشکی قانونی': ('forensic', 'گواهی پزشکی قانونی'),
    'مدرکی ندارم': ('none', 'بدون مدرک کتبی'),
    'مدرک ندارم': ('none', 'بدون مدرک کتبی'),
    'هیچ مدرکی': ('none', 'بدون مدرک کتبی'),
    'شفاهی': ('none', 'بدون مدرک کتبی'),
    'فیش واریز': ('bank_slip', 'فیش واریز بانکی'),
    'رسید بانکی': ('bank_slip', 'فیش واریز بانکی'),
    'کارت به کارت': ('bank_slip', 'فیش واریز بانکی'),
    'فیش': ('bank_slip', 'فیش واریز بانکی'),
    'واریز': ('bank_slip', 'فیش واریز بانکی'),
    'تراکنش': ('bank_slip', 'فیش واریز بانکی'),
    'اسکرین شات': ('messages', 'پیامک یا پیام در پیام‌رسان'),
    'پیامک': ('messages', 'پیامک یا پیام در پیام‌رسان'),
    'پیام': ('messages', 'پیامک یا پیام در پیام‌رسان'),
    'واتساپ': ('messages', 'پیامک یا پیام در پیام‌رسان'),
    'تلگرام': ('messages', 'پیامک یا پیام در پیام‌رسان'),
    'چت': ('messages', 'پیامک یا پیام در پیام‌رسان'),
    'سفته': ('promissory_note', 'سفته'),
    'چک': ('cheque', 'چک'),
    'قرارداد': ('written_contract', 'قرارداد یا سند کتبی'),
    'قولنامه': ('written_contract', 'قرارداد یا سند کتبی'),
    'رسید': ('written_contract', 'قرارداد یا سند کتبی'),
    'دست نوشته': ('written_contract', 'قرارداد یا سند کتبی'),
    'سند': ('written_contract', 'قرارداد یا سند کتبی'),
    'شاهد': ('witness', 'شاهد'),
    'شهود': ('witness', 'شاهد'),
    'فیلم': ('media', 'فیلم، عکس یا صدا'),
    'ویدیو': ('media', 'فیلم، عکس یا صدا'),
    'دوربین': ('media', 'فیلم، عکس یا صدا'),
    'عکس': ('media', 'فیلم، عکس یا صدا'),
    'صدا': ('media', 'فیلم، عکس یا صدا'),
    'ویس': ('media', 'فیلم، عکس یا صدا'),
    'ضبط': ('media', 'فیلم، عکس یا صدا'),
  };

  /// واژه‌نامهٔ نوع اتفاق برای شکایت کیفری.
  static const Map<String, (String, String)> incidentLexicon = {
    'ضرب و جرح': ('assault', 'ضرب و شتم'),
    'ضرب و شتم': ('assault', 'ضرب و شتم'),
    'کتک': ('assault', 'ضرب و شتم'),
    'سیلی': ('assault', 'ضرب و شتم'),
    'مشت': ('assault', 'ضرب و شتم'),
    'چاقو': ('assault', 'ضرب و شتم'),
    'خیانت در امانت': ('breach_of_trust', 'خیانت در امانت'),
    'انتشار عکس': ('private_media', 'انتشار تصاویر خصوصی'),
    'پخش عکس': ('private_media', 'انتشار تصاویر خصوصی'),
    'پخش فیلم': ('private_media', 'انتشار تصاویر خصوصی'),
    'کلاهبرداری': ('fraud', 'کلاهبرداری'),
    'کلاه برداری': ('fraud', 'کلاهبرداری'),
    'کلاه گذاشت': ('fraud', 'کلاهبرداری'),
    'سرقت': ('theft', 'سرقت'),
    'دزدی': ('theft', 'سرقت'),
    'دزدید': ('theft', 'سرقت'),
    'دزدیدند': ('theft', 'سرقت'),
    'دزدیده': ('theft', 'سرقت'),
    'تهدید': ('threat', 'تهدید'),
    'فحاشی': ('insult', 'توهین و فحاشی'),
    'فحش': ('insult', 'توهین و فحاشی'),
    'ناسزا': ('insult', 'توهین و فحاشی'),
    'توهین': ('insult', 'توهین و فحاشی'),
    'افترا': ('defamation', 'افترا و هتک حیثیت'),
    'تهمت': ('defamation', 'افترا و هتک حیثیت'),
    'آبروریزی': ('defamation', 'افترا و هتک حیثیت'),
    'مزاحمت': ('harassment', 'مزاحمت'),
    'مزاحم': ('harassment', 'مزاحمت'),
    'هک': ('cyber', 'جرم رایانه‌ای'),
    'جعل': ('forgery', 'جعل'),
  };

  /// واژه‌نامهٔ وضعیت درآمد برای اعسار.
  static const Map<String, (String, String)> incomeLexicon = {
    'درآمد ندارم': ('no_income', 'بدون درآمد'),
    'درآمدی ندارم': ('no_income', 'بدون درآمد'),
    'هیچ درآمدی': ('no_income', 'بدون درآمد'),
    'کم درآمد': ('low_income', 'درآمد کم'),
    'درآمدم کم': ('low_income', 'درآمد کم'),
    'حقوقم کم': ('low_income', 'درآمد کم'),
    'بیکار': ('unemployed', 'بیکار'),
    'بی کار': ('unemployed', 'بیکار'),
    'بازنشسته': ('retired', 'بازنشسته'),
    'حقوق بگیر': ('salaried', 'حقوق‌بگیر'),
    'کارمند': ('salaried', 'حقوق‌بگیر'),
    'کارگر': ('salaried', 'حقوق‌بگیر'),
    'شغل آزاد': ('self_employed', 'شغل آزاد'),
    'کاسب': ('self_employed', 'شغل آزاد'),
    'مغازه دارم': ('self_employed', 'شغل آزاد'),
  };

  static List<MapEntry<String, (String, String)>> _sorted(
          Map<String, (String, String)> lex) =>
      lex.entries.toList()
        ..sort((a, b) {
          final la = PersianNormalizer.tokens(a.key).length;
          final lb = PersianNormalizer.tokens(b.key).length;
          if (la != lb) return lb - la;
          return b.key.length - a.key.length;
        });

  static final List<MapEntry<String, (String, String)>> _proofSorted =
      _sorted(proofLexicon);
  static final List<MapEntry<String, (String, String)>> _incidentSorted =
      _sorted(incidentLexicon);
  static final List<MapEntry<String, (String, String)>> _incomeSorted =
      _sorted(incomeLexicon);

  /// همهٔ مدرک‌های ذکرشده (بدون تکرار، به ترتیب آمدن در متن) در یک مقدار.
  static SlotValue? extractProof(String text) {
    final toks = PersianNormalizer.tokens(text);
    final covered = List<bool>.filled(toks.length, false);
    final hits = <(int, String, String)>[];
    for (final e in _proofSorted) {
      final (code, display) = e.value;
      final pt = PersianNormalizer.tokens(e.key);
      final at = _indexOfFree(toks, pt, covered);
      if (at < 0) continue;
      for (var j = 0; j < pt.length; j++) {
        covered[at + j] = true;
      }
      if (hits.any((h) => h.$2 == code)) continue;
      hits.add((at, code, display));
    }
    if (hits.isEmpty) return null;
    // «چکم برگشت خورد» موضوع دعواست، نه مدرک؛ مگر صریحاً مدرک بودنش گفته شود.
    if (hits.length == 1 &&
        hits.first.$2 == 'cheque' &&
        RegExp(r'برگشت|پاس[\s\u200c]*نش|صیادی|گم[\s\u200c]*شد|سرقت').hasMatch(text) &&
        !RegExp(r'دارم|مدرک|عکس|اصل|کپی|رسید|گواهی').hasMatch(text)) {
      return null;
    }
    // «مدرکی ندارم» در کنار مدرک واقعی بی‌معناست؛ مدرک واقعی برنده است.
    if (hits.length > 1) hits.removeWhere((h) => h.$2 == 'none');
    hits.sort((a, b) => a.$1.compareTo(b.$1));
    return SlotValue(
      raw: hits.map((h) => h.$2).join(','),
      display: hits.map((h) => h.$3).join('، '),
    );
  }

  static int _indexOfFree(
      List<String> toks, List<String> phrase, List<bool> covered) {
    final n = phrase.length;
    if (n == 0) return -1;
    for (var i = 0; i + n <= toks.length; i++) {
      var ok = true;
      for (var j = 0; j < n; j++) {
        if (covered[i + j] ||
            !PersianNormalizer.containsPhraseTokens([toks[i + j]], [phrase[j]])) {
          ok = false;
          break;
        }
      }
      if (ok) return i;
    }
    return -1;
  }

  static SlotValue? _firstFrom(
      List<MapEntry<String, (String, String)>> lex, String text) {
    final toks = PersianNormalizer.tokens(text);
    for (final e in lex) {
      if (PersianNormalizer.containsPhraseTokens(
          toks, PersianNormalizer.tokens(e.key))) {
        return SlotValue(raw: e.value.$1, display: e.value.$2);
      }
    }
    return null;
  }

  static SlotValue? extractIncident(String text) =>
      _firstFrom(_incidentSorted, text);

  static SlotValue? extractIncomeStatus(String text) =>
      _firstFrom(_incomeSorted, text);
}

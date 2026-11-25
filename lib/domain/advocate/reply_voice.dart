import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/phrases.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/drafting.dart';

/// ساختِ متنِ پاسخ، پیش از آنکه گفتگو بشود.
///
/// پیش‌تر این کار — برگرداندن ارجاع‌ها به نام ماده، کوتاه‌کردن متن، سقفِ
/// تکرارِ پرسشِ بی‌جواب و چیدن دکمه‌ها — با ۹ فیلد حالتی روی خودِ
/// [Advocate] انجام می‌شد؛ یعنی همان شیئی که پرونده، موضوع و مسیرها را
/// می‌شناسد، وضعیتِ «چه گفتیم و چه پرسیدیم» را هم نگه می‌داشت. حالا این
/// وضعیت یک صاحب دارد و می‌شود جدا آزمونش کرد.
///
/// صدا خودش تصمیم نمی‌گیرد چه گفته شود؛ فقط حرفِ آماده را به پاسخ تبدیل
/// می‌کند: استناد، برش، سقف تکرار و دکمه‌ها.

/// ارجاع‌های `[[کلید:شماره]]` در متن، پشت‌سرهم.
final RegExp refRun = RegExp(r'(?:\s*\[\[[a-z_0-9]+:[0-9]+m?\]\])+');

/// یک ارجاع `[[کلید:شماره]]`.
final RegExp refOne = RegExp(r'\[\[([a-z_0-9]+):([0-9]+)(m?)\]\]');

final RegExp _cutAt = RegExp(r'[.؟!]\s+|\n+');

final RegExp _listItem = RegExp(r'^(?:[۰-۹0-9]+\)|•)');

/// نام کوتاه و رایج قانون‌های پرتکرار، برای اینکه متن پاسخ سنگین نشود.
String shortLaw(String source) {
  if (source.contains('آیین دادرسی دادگاه') && source.contains('مدنی')) {
    return 'قانون آیین دادرسی مدنی';
  }
  final paren = source.indexOf(' (');
  if (paren > 8 && source.startsWith('قانون مجازات اسلامی')) {
    return source.contains('تعزیرات')
        ? 'قانون مجازات اسلامی (تعزیرات)'
        : source.substring(0, paren);
  }
  return source;
}

/// متن را در مرزِ جمله به دو بخش می‌کند: آنچه الان گفته می‌شود و باقی.
List<String> cutText(String body, int budget) {
  if (body.length <= budget + 60) return [body, ''];
  final ends = <int>[];
  for (final m in _cutAt.allMatches(body)) {
    if (m.end >= body.length) break;
    final head = body.substring(0, m.start + 1).trimRight();
    if (head.endsWith(':') || head.endsWith('،')) continue;
    ends.add(m.end);
  }
  if (ends.isEmpty) return [body, ''];
  var k = 0;
  while (k + 1 < ends.length && ends[k + 1] <= budget) {
    k++;
  }
  // فهرستِ شماره‌دار را وسطش نمی‌بُرم، اگر باقی‌اش جا شود.
  while (k + 1 < ends.length &&
      ends[k + 1] <= budget + 280 &&
      _listItem.hasMatch(body.substring(ends[k]))) {
    k++;
  }
  final pick = ends[k];
  if (body.length - pick < 60) return [body, ''];
  if (body.length <= budget + 280 &&
      _listItem.hasMatch(body.substring(pick))) {
    return [body, ''];
  }
  return [body.substring(0, pick).trimRight(), body.substring(pick).trim()];
}

/// دکمه‌های پاسخ به «ادامه بده».
const List<String> yesNoChips = ['بله، بگو', 'نه، لازم نیست'];

/// جای پرسشی که دو بار بی‌جواب مانده است.
const String askDroppedText =
    'این پرسش را دو بار پرسیدم و جواب ندادید؛ از آن می‌گذرم. هر وقت خواستید، خودتان بگویید.';

class ReplyVoice {
  ReplyVoice({
    required this.engine,
    required this.file,
    required this.unresolved,
    this.defaultBudget = 380,
  });

  final KnowledgeEngine engine;
  final CaseFile file;

  /// ارجاع‌هایی که متنشان در بانک پیدا نشد (برای آزمون؛ باید خالی بماند).
  final List<String> unresolved;

  final int defaultBudget;

  /// ادامهٔ متنی که در همین پاسخ جا نشد («ادامه بده»).
  String rest = '';

  /// آیا جا ماندهٔ متن به‌صورت پرسش پیشنهاد شده است.
  bool offeredMore = false;

  /// هستهٔ آخرین پرسشی که پرسیدم، و چند بار پشت‌سرهم تکرار شده است.
  String lastAsk = '';
  int askRepeats = 0;

  /// دکمهٔ مرتبط با همین حرفِ کاربر.
  String relevantChip = '';

  /// استنادهای آخرین پاسخ (برای «متن قانون را ببینم» و «کدام ماده؟»).
  List<LawText> lastLaws = const [];

  /// آخرین متنِ بدنهٔ پاسخ (برای پیگیری‌هایی که به آن اشاره می‌کنند).
  String lastBody = '';

  /// چه چیزهایی را تا این‌جا گفته‌ام (برای تکرارنکردن).
  final Set<String> said = {};

  int _vary = 0;

  /// آغاز گفتگوی تازه: چیزی از پاسخ‌های قبلی نماند.
  void reset() {
    rest = '';
    offeredMore = false;
    lastAsk = '';
    askRepeats = 0;
    relevantChip = '';
    lastLaws = const [];
    lastBody = '';
    said.clear();
    _vary = 0;
  }

  /// یکی از جمله‌های آماده را به ترتیب برمی‌دارد تا پاسخ‌ها تکراری نشوند.
  String pick(List<String> options) {
    final v = options[_vary % options.length];
    _vary++;
    return v;
  }

  /// هستهٔ پرسش، بی‌پیشوند.
  ///
  /// پیشوندها دو جورند: چرخشی («و سؤال خودم:»، «اجازه بدهید دوباره بپرسم:»)
  /// و موردی («سؤالم این بود:»، «برگردیم سر پروندهٔ خودمان:»). اگر متنِ کامل
  /// مقایسه شود، هر پیشوند یک پرسش تازه حساب می‌شود و شمارنده هیچ‌وقت به سقف
  /// نمی‌رسد — همان چیزی که در آزمونِ سقفِ تکرار دیدیم.
  static String askKey(String ask) {
    var t = ask;
    for (final p in Say.askAgain) {
      if (t.startsWith('$p ')) {
        t = t.substring(p.length + 1);
        break;
      }
    }
    final colon = t.lastIndexOf(': ');
    if (colon > 0 && colon < 60) t = t.substring(colon + 2);
    return t;
  }

  /// خروجیِ هر پاسخ: استنادها را به نام ماده برمی‌گرداند، متن را کوتاه
  /// نگه می‌دارد (باقی‌مانده با «ادامه بده» می‌آید) و پرسشِ [ask] را در
  /// پایان می‌گذارد تا گفتگو دوطرفه بماند.
  AdvocateReply out(
    String text, {
    List<String> chips = const [],
    String ask = '',
    bool full = false,
    int? budget,
    AnswerSource source = AnswerSource.topic,
  }) {
    final laws = <LawText>[];
    final seen = <String>{};
    var body = text.replaceAllMapped(refRun, (m) {
      // مواد یک قانون کنار هم می‌آیند: «مواد ۵۲۲ و ۵۱۹ قانون …».
      final byLaw = <String, List<String>>{};
      for (final r in refOne.allMatches(m[0] ?? '')) {
        final law = r[1] ?? '';
        final rep = (r[3] ?? '').isNotEmpty;
        final art = r[2] ?? '';
        final key = '$law:$art${rep ? 'm' : ''}';
        final kind = law == 'constitution' ? 'اصل' : 'ماده';
        final c = engine.findArticle(law, '$kind $art${rep ? ' مکرر' : ''}');
        if (c == null) {
          if (!unresolved.contains(key)) unresolved.add(key);
          continue;
        }
        final num = '${Sense.fa(art)}${rep ? ' مکرر' : ''}';
        final label = '$kind $num ${c.source}';
        final nums = byLaw.putIfAbsent(c.source, () => <String>[]);
        if (!nums.contains(num)) nums.add(num);
        if (seen.add(key)) {
          laws.add(LawText(label, c.source, c.body, '',
              status: engine.meta[c.lawId]?['status']?.toString() ?? ''));
        }
      }
      if (byLaw.isEmpty) return '';
      final names = <String>[];
      byLaw.forEach((source, nums) {
        final basic = source.contains('قانون اساسی');
        final one = basic ? 'اصل' : 'ماده';
        final many = basic ? 'اصول' : 'مواد';
        names.add(nums.length == 1
            ? '$one ${nums.first} ${shortLaw(source)}'
            : '$many ${nums.join(' و ')} ${shortLaw(source)}');
      });
      return ' (${names.join('؛ ')})';
    });
    body = body.trim();
    rest = '';
    offeredMore = false;
    if (!full) {
      final cut = cutText(body, budget ?? defaultBudget);
      body = cut[0];
      rest = cut[1];
    }
    if (laws.isNotEmpty) lastLaws = laws;
    var tail = ask;
    // سقفِ تکرارِ پرسشِ بی‌جواب: بار سوم جای پرسش، یک جملهٔ صریح می‌آید و
    // بعد از آن دیگر پرسیده نمی‌شود.
    var droppedAsk = false;
    if (tail.isNotEmpty) {
      final key = askKey(tail);
      if (key == lastAsk) {
        askRepeats++;
      } else {
        lastAsk = key;
        askRepeats = 0;
      }
      if (askRepeats >= 2) {
        droppedAsk = true;
        tail = askRepeats == 2 ? askDroppedText : '';
      }
    }
    if (!droppedAsk && tail.isEmpty && rest.isNotEmpty) {
      tail = pick(Say.more);
      offeredMore = true;
    }
    final first = laws.isNotEmpty && !file.disclaimed;
    if (first) {
      file.disclaimed = true;
      body = '$body\n\n${Say.disclaimer}';
    }
    if (tail.isNotEmpty) body = body.isEmpty ? tail : '$body\n\n$tail';
    // دکمهٔ مرتبط با حرف کاربر، جلوی بقیهٔ دکمه‌ها؛ بدون تکرار.
    final all = <String>[
      if (offeredMore) ...yesNoChips,
      if (relevantChip.isNotEmpty) relevantChip,
      ...chips,
      if (rest.isNotEmpty && !offeredMore) ChipTexts.moreChip,
      if (laws.isNotEmpty && (first || chips.isEmpty)) ChipTexts.lawChip,
    ];
    final uniq = <String>[];
    for (final c in all) {
      if (!uniq.contains(c)) uniq.add(c);
    }
    all
      ..clear()
      ..addAll(uniq);
    // «انصراف» را Advocate._withLeave آخرین دکمهٔ هر پاسخ می‌کند.
    return AdvocateReply(body, chips: all, laws: laws, source: source);
  }
}

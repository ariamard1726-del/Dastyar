part of 'advocate.dart';

// دو پاسخِ واژه‌محور: تطبیقِ واژه‌های کاربر با متنِ مواد، و مسیرهای تصمیمِ
// موضوعیِ زنده. اینها آخرین پاسخ‌های «تصمیم‌گیر» بودند که روی `Advocate` مانده
// بودند؛ تنها وابستگیِ بیرونی‌شان موتورِ قوانین است.

/// اجرای تطبیق واژهها درون isolate دائمی موتور، بدون مسدودکردن رشتهٔ UI.
TermMatch matchTermsInWorker(KnowledgeEngine engine, String raw) =>
    LawTerms(engine).match(raw);

/// پاسخ‌های واژه‌محور: `lawTerms` (متنِ مواد) و `topicFlow` (مسیرِ موضوع).
class TermReply {
  TermReply({
    required this.file,
    required this.dialog,
    required this.voice,
    required this.engine,
    required this.terms,
    this.preparedMatch,
  });

  final CaseFile file;
  final DialogueState dialog;
  final ReplyVoice voice;
  final KnowledgeEngine engine;

  /// تطبیقِ واژه‌های پرسش با متنِ قوانین.
  final LawTerms terms;
  final TermMatch? Function(String raw)? preparedMatch;

  bool get hasCase => file.topic.isNotEmpty || dialog.guide != null;

  bool _vague(String n) =>
      Sense.words(n) <= 9 &&
      Sense.has(n,
          'مشکل(?:ی)? (?:حقوقی |قانونی )?(?:دارم|پیش اومده|برام)|سوال(?:ی)? (?:حقوقی )?(?:داشتم|دارم)|مشاوره|کمک(?:م)? (?:کن|میخوام|کنید)|راهنمایی(?:م)? (?:کن|میخوام|کنید)|گرفتار شدم|یه مسئله');

  /// پیششرط سبُک برای اینکه اصلاً لازم باشد `LawTerms.match` در worker آماده شود.
  bool eligible(String raw, String n) {
    if (Sense.words(n) < 2 || _vague(n)) return false;
    if (Sense.has(n, '[0-9]|(?:ماده|اصل) ?(?:[0-9]|واحده)|آیین ?نامه|دستورالعمل|بخشنامه')) {
      return false;
    }
    if (Sense.has(n, 'قهر') || !Sense.has(n, _legalHint)) return false;
    return engine.qa.match(raw) == null;
  }

  AdvocateReply _out(
    String text, {
    List<String> chips = const [],
    String ask = '',
    bool full = false,
    int budget = _budget,
    AnswerSource source = AnswerSource.topic,
  }) =>
      voice.out(text,
          chips: chips, ask: ask, full: full, budget: budget, source: source);

/// پاسخ بر پایهٔ تطبیق واژه‌ها با متن قوانین (نگاه کنید به [LawTerms]).
AdvocateReply? lawTerms(String raw, String n) {
  if (Sense.words(n) < 2 || _vague(n)) return null;
  // شماره‌ها، ماده‌های مشخص و آیین‌نامه‌ها پیش‌تر و با قاعدهٔ خودشان جواب
  // می‌گیرند؛ بانک پرسش‌وپاسخ هم اولویت دارد.
  if (Sense.has(n, '[0-9]|(?:ماده|اصل) ?(?:[0-9]|واحده)|آیین ?نامه|دستورالعمل|بخشنامه')) return null;
  if (engine.qa.match(raw) != null) return null;
  // جمله‌ای که هیچ نشانهٔ حقوقی ندارد (سلام، خوراک، جغرافیا) با متن قانون
  // سنجیده نمی‌شود، حتی اگر دو واژه‌اش در قانون باشد.
  if (!Sense.has(n, _legalHint)) return null;
  final tm = preparedMatch?.call(raw) ?? terms.match(raw);
  final c = tm.chunk;
  if (tm.accepted && c != null) {
    final lawName = engine.meta[c.lawId]?['title']?.toString() ?? c.source;
    final words = tm.matched.map((w) => '«$w»').join('، ');
    final gap = tm.missing.isEmpty
        ? ''
        : advocateFormat('termMissingWord', {
            'words': tm.missing.map((w) => '«$w»').join('، '),
          });
    voice.rest = '';
    voice.offeredMore = false;
    return AdvocateReply(
      advocateFormat('termMatched', {
        'lawName': lawName,
        'title': PersianText.toFaDigits(c.title),
        'words': words,
        'gap': gap,
        'body': c.body,
      }),
      laws: [
        LawText(c.title, c.source, c.body, '',
            status: engine.meta[c.lawId]?['status']?.toString() ?? ''),
      ],
      source: AnswerSource.lawTerms,
    );
  }
  final unknown = tm.unknown;
  final known = [for (final w in tm.missing) if (!unknown.contains(w)) w, ...tm.matched];
  if (known.length < 2) return null;
  // لحن: این پاسخ یک گزارش داخلی نیست؛ کاربر باید بفهمد «چرا ماده‌ای
  // نگفتم» و چه چیزی کمکش می‌کند — نه اینکه فهرست واژه‌های ناشناس ببیند.
  final unknownText = unknown.isEmpty
      ? ''
      : advocateFormat('termUnknownWords', {
          'unknown': unknown.map((w) => '«$w»').join('، '),
        });
  return _out(
    advocateFormat('termNotAllFound', {
      'unknownText': unknownText,
      'known': known.map((w) => '«$w»').join('، '),
    }),
    ask: advocateText('termNotAllFoundAsk'),
  );
}

/// پاسخ مسیرهای تصمیم موضوعی زنده، فقط وقتی پرونده‌ای باز نیست. هر موضوع با
/// دروازهٔ واژه‌هایش فعال می‌شود؛ اگر هیچ برگی جز `ask` نباشد، `null`.
AdvocateReply? topicFlow(String raw, String n) {
  if (hasCase) return null;
  for (final flow in engine.topicFlows) {
    // فقط موضوع‌های «live» در گفتگو جواب می‌دهند؛ بقیه هنوز با پاسخ‌های قدیمی
    // (که آزمون‌های موجود روی آن‌ها قفل‌اند) تداخل پیدا می‌کنند.
    if (flow['live'] != true) continue;
    final leafId = TopicFlow.route(flow, raw);
    if (leafId == 'ask') continue;
    final r = _topicLeaf(flow, leafId);
    if (r != null) return r;
  }
  return null;
}

AdvocateReply? _topicLeaf(Map<String, dynamic> flow, String leafId) {
  final leaves = flow['leaves'];
  if (leaves is! Map) return null;
  final leaf = leaves[leafId];
  if (leaf is! Map) return null;
  final laws = <LawText>[];
  for (final a in (leaf['articles'] as List? ?? const []).cast<Map>()) {
    final lawId = a['law'].toString();
    final title = a['title'].toString();
    final at = engine.chunkOf(lawId, title);
    if (at == null) continue;
    final c = engine.chunks[at];
    laws.add(LawText(c.title, c.source, c.body, '',
        status: engine.meta[c.lawId]?['status']?.toString() ?? ''));
  }
  final refs = laws.map((l) => '«${l.title}»').join('، ');
  final text = '${leaf['title']}\n\n${leaf['text']}'
      '${refs.isEmpty ? '' : advocateFormat('topicLeafRefs', {'refs': PersianText.toFaDigits(refs)})}\n\n'
      '${flow['disclaimer'] ?? ''}';
  voice.rest = '';
  voice.offeredMore = false;
  return AdvocateReply(text, laws: laws, source: AnswerSource.topicFlow);
}
}

/// نشانه‌های حقوقیِ کلی؛ فقط برای تصمیم «این جمله حقوقی است؟».
const String _legalHint =
    'بیع|رهن|شرط|خیار|عقد|غبن|فاحش|کارشناس|قولنامه|طرفین|مبلغ|مالک|مستاجر|موجر|دعوا|اتهام|قصاص|تخلف|جعل|توهین|افترا|تهدید|قانون|حق |حقوق|جرم|مجازات|دادگاه|دادسرا|شکایت|قرارداد|(?:^| )سند|ارث|دیه|مهریه|جریمه|وکالت|وکیل|وصیت|ملک|معامله|خسارت|بدهی|(?:^| )طلب|محکوم|حکم |(?:^| )رای |تعهد|ضامن|ضمانت|فسخ|مالکیت|توقیف|زندان|حبس|قاضی|کارفرما|کارگر|اخراج|اجاره|موجر|مستاجر|چک|طلاق|نفقه|حضانت|بیمه|ورشکست|شرکت|سهام|ثبت|طلبکار|بدهکار|سرقت|دزد|کلاهبردار|تصرف|همسایه|دیوار|ودیعه|بانک|اجرای|دادخواست|لایحه|اجرائیه|کیفری|مدنی';

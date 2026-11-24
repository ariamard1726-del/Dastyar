part of 'advocate.dart';

// تطبیقِ واژه‌ها با متن قوانین و مسیرهای تصمیم موضوعی.
//
// راهنما و واژه‌نامه به `GuideReply` رفتند؛ آنچه این‌جا مانده، پاسخ‌هایی است
// که واژه‌های پرسش را با متنِ مواد می‌سنجند.

extension _LawTermsReply on Advocate {
  /// پاسخ بر پایهٔ تطبیق واژه‌ها با متن قوانین (نگاه کنید به [LawTerms]).
  AdvocateReply? _lawTermsReply(String raw, String n) {
    if (Sense.words(n) < 2 || _vague(n)) return null;
    // شماره‌ها، ماده‌های مشخص و آیین‌نامه‌ها پیش‌تر و با قاعدهٔ خودشان جواب
    // می‌گیرند؛ بانک پرسش‌وپاسخ هم اولویت دارد.
    if (Sense.has(n, '[0-9]|(?:ماده|اصل) ?(?:[0-9]|واحده)|آیین ?نامه|دستورالعمل|بخشنامه')) return null;
    if (engine.qa.match(raw) != null) return null;
    // جمله‌ای که هیچ نشانهٔ حقوقی ندارد (سلام، خوراک، جغرافیا) با متن قانون
    // سنجیده نمی‌شود، حتی اگر دو واژه‌اش در قانون باشد.
    if (!Sense.has(n, _legalHint)) return null;
    final tm = _terms.match(raw);
    final c = tm.chunk;
    if (tm.accepted && c != null) {
      final lawName = engine.meta[c.lawId]?['title']?.toString() ?? c.source;
      final words = tm.matched.map((w) => '«$w»').join('، ');
      final gap = tm.missing.isEmpty
          ? ''
          : ' واژهٔ ${tm.missing.map((w) => '«$w»').join('، ')} در این ماده نیست.';
      voice.rest = '';
      voice.offeredMore = false;
      return AdvocateReply(
        'در «$lawName» ${PersianText.toFaDigits(c.title)} واژه‌های $words با هم آمده‌اند.$gap\n\n${c.body}\n\n'
        'این ماده لزوماً حکم اصلی ماجرای شما نیست؛ اگر بگویید چه شده، می‌سنجم که به همین ماده مربوط است یا نه.',
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
        : 'واژه‌های ${unknown.map((w) => '«$w»').join('، ')} با همین ریخت در '
            'هیچ‌یک از قوانین من نیست (شاید با تعبیر دیگری آمده باشد). ';
    return _out(
      '$unknownText'
      'واژه‌های ${known.map((w) => '«$w»').join('، ')} در متن قوانین من هست، ولی '
      'ماده‌ای که همهٔ این‌ها را با هم داشته باشد پیدا نکردم؛ حدس نمی‌زنم و '
      'مادهٔ بی‌ربط هم نمی‌آورم.',
      ask: 'ماجرای شما دقیقاً چیست؟ چه کسی و چه کاری کرده است؟',
    );
  }
}

/// نشانه‌های حقوقیِ کلی؛ فقط برای تصمیم «این جمله حقوقی است؟» به کار می‌رود.
const String _legalHint =
    'بیع|رهن|شرط|خیار|عقد|غبن|فاحش|کارشناس|قولنامه|طرفین|مبلغ|مالک|مستاجر|موجر|دعوا|اتهام|قصاص|تخلف|جعل|توهین|افترا|تهدید|قانون|حق |حقوق|جرم|مجازات|دادگاه|دادسرا|شکایت|قرارداد|(?:^| )سند|ارث|دیه|مهریه|جریمه|وکالت|وکیل|وصیت|ملک|معامله|خسارت|بدهی|(?:^| )طلب|محکوم|حکم |(?:^| )رای |تعهد|ضامن|ضمانت|فسخ|مالکیت|توقیف|زندان|حبس|قاضی|کارفرما|کارگر|اخراج|اجاره|موجر|مستاجر|چک|طلاق|نفقه|حضانت|بیمه|ورشکست|شرکت|سهام|ثبت|طلبکار|بدهکار|سرقت|دزد|کلاهبردار|تصرف|همسایه|دیوار|ودیعه|بانک|اجرای|دادخواست|لایحه|اجرائیه|کیفری|مدنی';

extension _TopicFlowReply on Advocate {
  /// پاسخ مسیرهای تصمیم موضوعی زنده، فقط وقتی پرونده‌ای باز نیست. هر موضوع با
  /// دروازهٔ واژه‌هایش فعال می‌شود؛ اگر هیچ برگی جز `ask` نباشد، `null`.
  AdvocateReply? _topicReply(String raw, String n) {
    if (hasCase) return null;
    for (final flow in engine.topicFlows) {
      // فقط موضوع‌های «live» در گفتگو جواب می‌دهند؛ بقیه هنوز با پاسخ‌های قدیمی
      // (که آزمون‌های موجود روی آن‌ها قفل‌اند) تداخل پیدا می‌کنند.
      if (flow['live'] != true) continue;
      final leafId = TopicFlow.route(flow, raw);
      if (leafId == 'ask') continue;
      final r = _topicLeafReply(flow, leafId);
      if (r != null) return r;
    }
    return null;
  }

  AdvocateReply? _topicLeafReply(Map<String, dynamic> flow, String leafId) {
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
        '${refs.isEmpty ? '' : '\n\nمواد مستند: ${PersianText.toFaDigits(refs)}'}\n\n'
        '${flow['disclaimer'] ?? ''}';
    voice.rest = '';
    voice.offeredMore = false;
    return AdvocateReply(text, laws: laws, source: AnswerSource.topicFlow);
  }
}

import 'package:dastyar/domain/dialogue/dialogue_action.dart';
import 'package:dastyar/domain/dialogue/dialogue_state.dart';
import 'package:dastyar/domain/dialogue/domain_slot_schemas.dart';
import 'package:dastyar/domain/dialogue/evidence.dart';
import 'package:dastyar/domain/dialogue/slots.dart';

/// تصمیم‌گیرندهٔ نوبت بعدی گفتگو.
///
/// این کلاس مسئولیت `DialogueState` و `EvidenceSet` را می‌گیرد و
/// یکی از چهار `DialogueAction` را برمی‌گرداند. هیچ متنی تولید
/// نمی‌کند (تولید متن کار `ResponseComposer` است).
///
/// تصمیم‌گیری به ترتیب اولویت:
///   ۱. تعارض بین شواهد → `ExplainConflict`
///   ۲. دامنه نامشخص → `DisambiguateDomain`
///   ۳. اولین اسلات **اجباری** پرنشده با prompt غیرخالی → `AskForSlot`
///   ۴. همهٔ اسلات‌های اجباری پر شده + شواهد کافی → `GiveAnswer`
///   ۵. شواهد ناکافی → `AskForSlot` با hint شفاف‌سازی
class DialoguePlanner {
  const DialoguePlanner();

  /// تصمیم نوبت بعدی بر اساس `state` و `evidence`.
  DialogueAction plan(DialogueState state, EvidenceSet evidence) {
    // ۱. تعارض بین شواهد
    if (evidence.conflicts.isNotEmpty) {
      final alternatives = evidence.items
          .map((e) => e.articleId)
          .where((id) => id.isNotEmpty)
          .toList();
      // ignore: prefer_const_constructors
      return ExplainConflict(
        alternatives: alternatives,
        rationale:
            'بین شواهد موجود تعارض هست؛ نمی‌توانم بدون '
            'انتخاب شما پاسخ قطعی بدهم.',
      );
    }

    // ۲. دامنه نامشخص
    final schema = DomainSchemaRegistry.forDomain(state.domain);
    if (schema == null) {
      // ignore: prefer_const_constructors
      return DisambiguateDomain(candidates: DomainSchemaRegistry.allDomainIds);
    }

    // ۳. اولین اسلات پرنشدهٔ اجباری با prompt غیرخالی (طبق priority)
    final missing = _findNextMissingSlot(schema, state);
    if (missing != null) {
      return AskForSlot(
        slotKey: missing.name,
        rationale: missing.rationale,
        options: missing.options,
        hint: state.pendingSlot == missing.name
            ? 'قبلاً هم پرسیدم؛ لطفاً یک پاسخ روشن بدهید.'
            : null,
      );
    }

    // ۴. همه اسلات‌های الزامی پر شده
    if (evidence.hasSufficientSupport) {
      return const GiveAnswer(
        conclusions: [
          'بر اساس پاسخ‌های شما و شواهد موجود، تحلیل نهایی به شرح زیر است.',
        ],
      );
    }

    // ۵. همه پر شده ولی شواهد کافی نیست — hint برای شفاف‌سازی
    return const AskForSlot(
      slotKey: Slots.clarification,
      rationale: 'برای ارائهٔ پاسخ قطعی، نیاز به توضیح بیشتری دارم.',
      options: [],
      hint: 'شواهد کافی نیست؛ کاربر را به شفاف‌سازی هدایت کن.',
    );
  }

  // ---------------------------------------------------------------------
  // پرسش شفاف‌سازی (Clarification Fallback)
  // ---------------------------------------------------------------------

  /// زیر این اطمینان، پیام را اصلاً نفهمیده‌ایم و از کاربر توضیح می‌خواهیم.
  static const double clarifyUnknownBelow = 0.40;

  /// زیر این اطمینان (و بالای [clarifyUnknownBelow])، دو برداشت محتمل را
  /// به‌صورت پرسش دوگزینه‌ای به کاربر نشان می‌دهیم.
  static const double clarifyChoiceBelow = 0.65;

  /// پرسش شفاف‌سازی برای وقتی که مسیریاب قصد مطمئن نیست.
  ///
  /// - قصد `none` (و برچسب‌های غیرحقوقی مثل `chitchat`/`cancel`/
  ///   `out_of_scope`) حذف و بقیه به ترتیب احتمال مرتب می‌شوند.
  /// - بیشینه < ۰٫۴۰: عذرخواهی همدلانه، بازگویی کوتاه پیام کاربر (حداکثر ۸
  ///   واژه) و درخواست جزئیات: چه اتفاقی افتاده، طرف مقابل کیست، چه می‌خواهد.
  /// - ۰٫۴۰ تا ۰٫۶۵: دو قصد برتر به‌صورت پرسش «۱ یا ۲» با ایموجی، همراه
  ///   جملهٔ ربطی که به نزدیکی دو احتمال بستگی دارد.
  /// - ≥ ۰٫۶۵: شفاف‌سازی لازم نیست و `null` برمی‌گردد.
  ///
  /// متن از قطعه‌ها ساخته می‌شود (نه از آرایهٔ پرسش‌های آماده) و برای
  /// [variant] یکسان همیشه یکسان است؛ برای تنوع از
  /// [ClarificationPromptGenerator] (شمارنده‌دار) استفاده کنید.
  String? generateClarificationPrompt(
    String userText,
    Map<String, double> intentProbabilities, {
    int variant = 0,
  }) =>
      buildClarification(userText, intentProbabilities, variant: variant)?.text;

  /// همان [generateClarificationPrompt] با گزینه‌های ساخت‌یافته، تا پاسخ
  /// «۱» یا «۲» کاربر با [ClarificationPrompt.resolveChoice] به قصد برگردد.
  ClarificationPrompt? buildClarification(
    String userText,
    Map<String, double> intentProbabilities, {
    int variant = 0,
  }) {
    final ranked = rankIntents(intentProbabilities);
    final top = ranked.isEmpty ? 0.0 : ranked.first.value;
    if (top >= clarifyChoiceBelow) return null;
    final v = variant < 0 ? -variant : variant;
    if (top < clarifyUnknownBelow) {
      return ClarificationPrompt(
        text: _unknownPrompt(userText, v),
        options: const [],
        kind: ClarificationKind.rephrase,
      );
    }
    final options = ranked.take(2).map((e) => e.key).toList();
    final gap = ranked.length > 1 ? ranked[0].value - ranked[1].value : 1.0;
    return ClarificationPrompt(
      text: _choicePrompt(options, gap, v),
      options: List.unmodifiable(options),
      kind: ClarificationKind.choice,
    );
  }

  /// برچسب‌هایی که هرگز گزینهٔ شفاف‌سازی نمی‌شوند.
  static const Set<String> nonClarifiableIntents = {
    'none',
    'cancel',
    'chitchat',
    'out_of_scope',
  };

  /// قصدهای معتبر به ترتیب احتمال نزولی (تساوی: ترتیب الفبایی، قطعی).
  static List<MapEntry<String, double>> rankIntents(Map<String, double> p) {
    final list = p.entries
        .where((e) =>
            !nonClarifiableIntents.contains(e.key) &&
            !e.value.isNaN &&
            e.value > 0)
        .toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return list;
  }

  /// برچسب نمایشی هر قصد: ایموجی + عنوان فارسی + توضیح کوتاه.
  static const Map<String, (String, String, String)> intentLabels = {
    'demand_money': ('💰', 'مطالبهٔ پول', 'می‌خواهید طلب یا پولتان را پس بگیرید'),
    'complaint': ('⚖️', 'شکایت کیفری', 'می‌خواهید از کسی به‌خاطر جرم شکایت کنید'),
    'cheque_execution': ('🧾', 'اجرائیهٔ چک', 'می‌خواهید وجه چک را مستقیم از طریق اجرا وصول کنید'),
    'cheque_complaint': ('🚨', 'شکایت کیفری چک', 'می‌خواهید از صادرکنندهٔ چک شکایت کیفری کنید'),
    'formal_notice': ('📨', 'اظهارنامه', 'می‌خواهید رسماً به طرف مقابل اخطار بدهید'),
    'defense_brief': ('🛡️', 'دفاع در پرونده', 'علیه شما شکایت یا دعوایی مطرح شده'),
    'insolvency': ('🤲', 'اعسار و تقسیط', 'توان پرداخت یکجای بدهی یا هزینه را ندارید'),
    'legal_aid': ('🤝', 'وکیل رایگان (معاضدت)', 'هزینهٔ وکیل برایتان سنگین است'),
    'cheque': ('🧾', 'موضوع چک', 'مشکل شما به یک چک مربوط است'),
    'debt': ('💰', 'طلب و بدهی', 'پای یک طلب یا قرض در میان است'),
    'labor': ('👷', 'کار و کارگری', 'مشکل با کارفرما، حقوق یا بیمه دارید'),
    'lease': ('🏠', 'اجاره و مستأجر', 'اختلاف بر سر اجاره، ودیعه یا تخلیه است'),
    'family': ('👨‍👩‍👧', 'خانواده', 'موضوع مهریه، نفقه، طلاق یا حضانت است'),
    'fraud_cyber': ('💻', 'کلاهبرداری و فضای مجازی', 'فریب خورده‌اید یا در فضای مجازی آسیب دیده‌اید'),
    'criminal_harm': ('⚖️', 'توهین، تهدید یا آسیب', 'کسی به شما آسیب زده یا تهدیدتان کرده'),
    'litigation_defense': ('🛡️', 'ابلاغیه و دفاع', 'ابلاغیه یا رأیی برایتان آمده'),
    'article_lookup': ('📖', 'متن یک ماده', 'متن دقیق یک مادهٔ قانونی را می‌خواهید'),
    'legal_question': ('❓', 'یک پرسش حقوقی کلی', 'جواب یک سؤال حقوقی را می‌خواهید'),
    'draft_request': ('✍️', 'تنظیم متن حقوقی', 'می‌خواهید دادخواست، شکواییه یا لایحه بنویسید'),
    'general_intake': ('🗂️', 'شرح کلی ماجرا', 'می‌خواهید اول ماجرا را تعریف کنید'),
    'counsel_answer': ('💬', 'ادامهٔ گفتگوی قبلی', 'جواب سؤال قبلی من است'),
  };

  static (String, String, String) labelFor(String intent) =>
      intentLabels[intent] ?? ('📌', intent.replaceAll('_', ' '), '');

  /// حداکثر [maxWords] واژهٔ اول پیام کاربر، برای بازگویی کوتاه.
  static String snippetOf(String text, {int maxWords = 8}) {
    final words = text
        .replaceAll(RegExp('[«»"]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    if (words.length <= maxWords) return words.join(' ');
    return '${words.take(maxWords).join(' ')}…';
  }

  String _unknownPrompt(String userText, int v) {
    final snippet = snippetOf(userText);
    final apology = switch (v % 3) {
      0 => 'ببخشید، منظورتان را درست متوجه نشدم',
      1 => 'عذر می‌خواهم، هنوز تصویر روشنی از مشکلتان ندارم',
      _ => 'شرمنده، مطمئن نیستم درست فهمیده باشم',
    };
    final echo = snippet.isEmpty
        ? ''
        : ' — از «$snippet» فهمیدم موضوع برایتان مهم است';
    final reassure = switch (v % 2) {
      0 => 'نگران نباشید؛ با چند جملهٔ بیشتر می‌توانم دقیق راهنمایی‌تان کنم.',
      _ => 'مهم است که درست راهنمایی‌تان کنم، پس کمی بیشتر توضیح بدهید.',
    };
    final b = StringBuffer()
      ..write('$apology$echo. ')
      ..writeln(reassure)
      ..writeln()
      ..writeln('• دقیقاً چه اتفاقی افتاده است؟')
      ..writeln('• طرف مقابل کیست (شخص، شرکت، کارفرما، صاحبخانه، اداره…)؟')
      ..write('• در نهایت چه می‌خواهید (پولتان را پس بگیرید، شکایت کنید، '
          'از خودتان دفاع کنید…)؟');
    return b.toString();
  }

  String _choicePrompt(List<String> options, double gap, int v) {
    final connective = gap < 0.05
        ? 'راستش هر دو احتمال تقریباً برابره.'
        : gap < 0.15
            ? 'دو برداشت به ذهنم می‌رسد و یکی فقط کمی پررنگ‌تر است.'
            : 'به نظرم بیشتر گزینهٔ اول است، ولی می‌خواهم مطمئن شوم.';
    final lead = switch (v % 2) {
      0 => 'برای اینکه مسیر درستی پیشنهاد کنم، بفرمایید کدام به وضعیت شما نزدیک‌تر است:',
      _ => 'کمکم کنید دقیق‌تر بفهمم؛ کدام‌یک حال شما را بهتر توصیف می‌کند؟',
    };
    const keycaps = ['1️⃣', '2️⃣'];
    final b = StringBuffer()
      ..writeln(connective)
      ..writeln(lead)
      ..writeln();
    for (var i = 0; i < options.length; i++) {
      final (emoji, title, hint) = labelFor(options[i]);
      b.writeln(hint.isEmpty
          ? '${keycaps[i]} $emoji $title'
          : '${keycaps[i]} $emoji $title — $hint');
    }
    if (options.length == 1) {
      b.writeln('${keycaps[1]} 🤔 موضوع دیگری است');
    }
    b
      ..writeln()
      ..write('لطفاً فقط عدد ۱ یا ۲ را بنویسید.');
    return b.toString();
  }

  /// پیدا کردن اولین اسلات پرنشدهٔ **اجباری** با prompt غیرخالی،
  /// به ترتیب priority.
  ///
  /// **⚠️ نکتهٔ مهم**: اسلات‌های اختیاری (`amount`, `due_date`,
  /// `deposit_amount`) در Phase 2.4 پرسیده نمی‌شوند. فهرست اجباری‌ها و
  /// ترتیب آن‌ها مستقیماً از قرارداد یکتای [Slots.coreByDomain] می‌آید.
  SlotSpec? _findNextMissingSlot(DomainSchema schema, DialogueState state) {
    for (final spec in schema.requiredSlots) {
      if (spec.prompt.isEmpty) continue;
      if (state.hasReliableSlot(spec.name)) continue;
      return spec;
    }
    return null;
  }
}

/// نوع پرسش شفاف‌سازی.
enum ClarificationKind {
  /// پیام نامفهوم بود؛ از کاربر خواستیم با جزئیات بیشتر بنویسد.
  rephrase,

  /// دو برداشت محتمل به‌صورت گزینهٔ «۱ یا ۲» نشان داده شد.
  choice,
}

/// پرسش شفاف‌سازی همراه گزینه‌هایش.
class ClarificationPrompt {
  const ClarificationPrompt({
    required this.text,
    required this.options,
    required this.kind,
  });

  final String text;

  /// قصدهای پیشنهادی به ترتیب نمایش («۱» = اولی).
  final List<String> options;

  final ClarificationKind kind;

  static final RegExp _one = RegExp(r'^(1|۱|١|یک|يک|اول|اولی|گزینه ?(1|۱) ?)$');
  static final RegExp _two = RegExp(r'^(2|۲|٢|دو|دوم|دومی|گزینه ?(2|۲) ?)$');

  /// پاسخ کاربر را به قصد برمی‌گرداند؛ اگر «۲» = «موضوع دیگری است» باشد یا
  /// پاسخ نامفهوم باشد، null.
  String? resolveChoice(String reply) {
    if (kind != ClarificationKind.choice) return null;
    final r = reply
        .trim()
        .replaceAll(RegExp(r'[\s.،!؟?\u200c]+$'), '')
        .replaceAll('\uFE0F\u20E3', '')
        .trim();
    if (_one.hasMatch(r)) return options.isNotEmpty ? options[0] : null;
    if (_two.hasMatch(r)) return options.length > 1 ? options[1] : null;
    return null;
  }
}

/// تولیدکنندهٔ پرسش شفاف‌سازی با شمارندهٔ تنوع (به‌جای Random) تا خروجی
/// در تست‌ها قابل پیش‌بینی باشد.
class ClarificationPromptGenerator {
  ClarificationPromptGenerator({
    DialoguePlanner planner = const DialoguePlanner(),
    int start = 0,
  })  : _planner = planner,
        _counter = start;

  final DialoguePlanner _planner;
  int _counter;

  /// تعداد پرسش‌های تولیدشده تا اینجا.
  int get counter => _counter;

  ClarificationPrompt? next(String userText, Map<String, double> probs) {
    final p = _planner.buildClarification(userText, probs, variant: _counter);
    if (p != null) _counter++;
    return p;
  }

  void reset([int to = 0]) => _counter = to;
}

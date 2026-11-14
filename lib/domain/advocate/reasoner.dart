import 'package:dastyar/domain/advocate/case_file.dart';

/// وضع یک ادعا با واقعیت‌هایی که تا اینجا معلوم است.
enum Standing {
  /// همهٔ شرط‌ها برقرار است.
  strong,

  /// هیچ شرطی رد نشده، ولی تکلیف بعضی هنوز روشن نیست.
  open,

  /// دست‌کم یک شرط برقرار نیست.
  weak,
}

/// سنجش یک شرط روی پرونده.
class ElementView {
  final Element element;

  /// برقرار (true)، نابرقرار (false) یا هنوز نامعلوم (null).
  final bool? holds;

  const ElementView(this.element, this.holds);
}

/// سنجش یک ادعا: تک‌تک شرط‌ها و جمع‌بندی.
class ClaimView {
  final Claim claim;
  final List<ElementView> elements;

  const ClaimView(this.claim, this.elements);

  int get met => elements.where((e) => e.holds == true).length;

  /// شمارهٔ (از ۱) شرط‌هایی که برقرار نیستند.
  List<int> get failed => [
        for (var i = 0; i < elements.length; i++)
          if (elements[i].holds == false) i + 1,
      ];

  /// شمارهٔ (از ۱) شرط‌هایی که هنوز نامعلوم‌اند.
  List<int> get open => [
        for (var i = 0; i < elements.length; i++)
          if (elements[i].holds == null) i + 1,
      ];

  Standing get standing => failed.isNotEmpty
      ? Standing.weak
      : (open.isNotEmpty ? Standing.open : Standing.strong);
}

/// استدلال حقوقی روی واقعیت‌های پرونده.
///
/// این کلاس هیچ متنی نمی‌سازد و چیزی دربارهٔ زبان نمی‌داند. فقط سه کار
/// می‌کند: می‌گوید با این واقعیت‌ها کدام ادعاها روی میز است؛ هر ادعا را
/// شرط‌به‌شرط می‌سنجد؛ و می‌گوید پرسش بعدی کدام باشد تا نتیجه زودتر روشن
/// شود.
class Reasoner {
  const Reasoner._();

  /// ادعاهایی که با واقعیت‌های فعلی مطرح‌اند، به ترتیب اولویتِ موضوع.
  static List<ClaimView> assess(Topic t, CaseFile f) => [
        for (final c in t.claims)
          if (c.elements.isNotEmpty && (c.when == null || c.when!(f)))
            ClaimView(c, [for (final e in c.elements) ElementView(e, e.test(f))]),
      ];

  /// هر پرسش چقدر به روشن‌شدن نتیجه کمک می‌کند.
  ///
  /// ادعای اول سنگین‌تر از بعدی‌هاست، و در هر ادعا اولین شرطِ نامعلوم
  /// سنگین‌تر از بقیه (ترتیب شرط‌ها همان ترتیبی است که یک وکیل می‌پرسد).
  /// شرطی که رد شده یا برقرار است دیگر پرسشی نمی‌خواهد. واقعیتی که فقط
  /// برای حساب‌کردن مبلغ لازم است کمترین وزن را دارد.
  static Map<String, int> weights(Topic t, CaseFile f) {
    final top = <String, int>{};
    final count = <String, int>{};
    final views = assess(t, f);
    for (var i = 0; i < views.length; i++) {
      final v = views[i];
      if (v.standing == Standing.weak) continue;
      final rank = i == 0 ? 4 : (i == 1 ? 2 : 1);
      var firstOpen = true;
      for (final e in v.elements) {
        if (e.holds != null) continue;
        final w = rank * (firstOpen ? 2 : 1);
        firstOpen = false;
        for (final id in e.element.needs) {
          if (w > (top[id] ?? 0)) top[id] = w;
          count[id] = (count[id] ?? 0) + 1;
        }
      }
    }
    // سنگین‌ترین نیاز تعیین‌کننده است؛ تعداد ادعاها فقط گرهِ برابری را باز
    // می‌کند.
    final out = <String, int>{
      for (final id in top.keys) id: top[id]! * 10 + count[id]!,
    };
    for (final v in views) {
      if (v.standing == Standing.weak) continue;
      for (final id in v.claim.uses) {
        out.putIfAbsent(id, () => 1);
      }
    }
    return out;
  }

  /// پرسش بعدی از میان پرسش‌های قابل‌پرسیدن ([askable] به ترتیب موضوع).
  ///
  /// پرسش‌های پایه همیشه جلوترند. بعد پرسشی که بیشترین اثر را روی نتیجه
  /// دارد؛ اگر هیچ‌کدام به ادعایی گره نخورده باشد، همان ترتیب موضوع.
  static Slot? nextQuestion(Topic t, CaseFile f, List<Slot> askable) {
    if (askable.isEmpty) return null;
    for (final s in askable) {
      if (s.first) return s;
    }
    final w = weights(t, f);
    var best = askable.first;
    var bestW = w[best.id] ?? 0;
    for (final s in askable.skip(1)) {
      final sw = w[s.id] ?? 0;
      if (sw > bestW) {
        best = s;
        bestW = sw;
      }
    }
    return best;
  }
}

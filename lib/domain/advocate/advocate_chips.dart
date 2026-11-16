part of 'advocate.dart';

// دکمه‌های پیشنهادی زیر هر پاسخ.

extension _Chips on Advocate {
  /// پیشنهادهای متناسب با همین گفتگو: پرسش‌هایی که به حرف‌های خودِ کاربر
  /// نزدیک‌ترند جلوتر می‌آیند، و «نوشتن متن» فقط وقتی که پرونده پخته شده یا
  /// خودش حرفِ شکایت و دادخواست را زده باشد.
  List<String> _suggest(Topic t) {
    final cand = <Issue>[];
    final fit = <String, int>{};
    for (final i in t.issues) {
      if (file.covered.contains(i.id)) continue;
      final w = i.when;
      if (w != null && !w(file)) continue;
      // رتبهٔ منفی یعنی این بحث به این پرونده نمی‌خورد؛ فقط اگر خودِ
      // کاربر بپرسد جواب می‌گیرد.
      final r = i.rank;
      final rv = r == null ? 0 : r(file);
      if (rv < 0) continue;
      fit[i.id] = rv;
      cand.add(i);
    }
    final near = <String, int>{};
    for (var k = 0; k < cand.length; k++) {
      final i = cand[k];
      var sc = Sense.has(_heard, i.cues) ? 3 : 0;
      for (final w in Sense.norm(i.chip).split(' ')) {
        if (w.length >= 4 && _heard.contains(w)) sc++;
      }
      sc += 2 * (fit[i.id] ?? 0);
      // در تساوی، ترتیبِ خودِ موضوع حفظ می‌شود.
      near[i.id] = sc * 100 - k;
    }
    cand.sort((a, b) => (near[b.id] ?? 0).compareTo(near[a.id] ?? 0));
    final asks = <String>[for (final i in cand.take(2)) i.chip];
    for (final e in _followChips.entries) {
      if (asks.length >= 3) break;
      if (file.covered.contains('f:${e.key}')) continue;
      if (!t.follow.containsKey(e.key)) continue;
      asks.add(e.value);
    }
    final docs = <String>[for (final g in filings) g.chip];
    if (docs.isNotEmpty) {
      // چینش ثابت: اول پرسشی که به همین گفتگو نزدیک‌تر است، بعد دادخواست،
      // بعد لایحه، و بعد بقیهٔ پرسش‌ها.
      return [
        if (asks.isNotEmpty) asks.first,
        ...docs,
        ...asks.skip(1),
      ];
    }
    final ripe = _nextSlot(t) == null ||
        Sense.has(_heard, 'شکایت|دادخواست|اظهارنامه|لایحه|شکوائیه|بنویس');
    final d = t.drafts;
    if (d != null && ripe) {
      for (final id in d(file)) {
        final title = _draftTitles[id];
        if (title != null) {
          asks.add(title);
          break;
        }
      }
    }
    return asks;
  }

  /// بیرون از پرونده، نمونه‌های آماده فقط پیش از آن‌که کاربر ماجرایی گفته
  /// باشد نشان داده می‌شود؛ بعد از آن ربطی به حرف او ندارد.
  List<String> _idleChips() {
    final t = _current();
    return t == null ? const [] : _suggest(t);
  }

  /// نمونه‌های آغاز گفتگو؛ فقط وقتی کاربر هنوز هیچ ماجرایی نگفته است.
  List<String> _starters() =>
      _loose.length <= 1 && _guide == null && file.topic.isEmpty
          ? Advocate.starterChips
          : const [];
}

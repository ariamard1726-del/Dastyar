part of 'advocate.dart';

// واقعیت‌های پرونده: چه چیزی شنیده شد، چه چیزی برعکس شد، و پرونده کِی بسته شد.
//
// این بخش تنها جایی است که `file.facts` را می‌نویسد. اگر جایی دیگر هم
// واقعیتی را عوض کند، دو منبعِ حقیقت ساخته می‌شود و «شنیدم» و «برعکس شد»
// دیگر به هم نمی‌خورند.

/// آیا مقدارِ تازهٔ یک واقعیتِ محوری از مقدارِ فعلی مهم‌تر است؟
bool _outranks(Slot s, String now, String old) {
  final a = s.priority.indexOf(now);
  final b = s.priority.indexOf(old);
  return a >= 0 && (b < 0 || a < b);
}

/// آیا کاربر همین مقدار را صریح و از زبان خودش گفته است؟
bool _saidSure(Slot s, String n, String v) {
  final r = s.readSure;
  return r != null && r(n) == v;
}

String _join(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  return '${items.sublist(0, items.length - 1).join('، ')} و ${items.last}';
}


extension _CaseFacts on CaseFlow {
  String _factsKey() {
    final keys = file.facts.keys.toList()..sort();
    final sb = StringBuffer(file.topic);
    for (final k in keys) {
      sb.write('|$k=${file.facts[k]}');
    }
    return sb.toString();
  }

  void closeCase() {
    file.clearCase();
    dialog.clearCase();
    voice.lastBody = '';
    voice.lastAsk = '';
    voice.askRepeats = 0;
    flips.clear();
  }

  /// واقعیت‌های تازهٔ پیام را در پرونده می‌نشاند و فهرست تغییرها را می‌دهد.
  ///
  /// [live] یعنی این همان پیامی است که کاربر الان فرستاده (نه مرور پیام‌های
  /// قبلی)؛ فقط در این حالت جوابِ کوتاه به پرسشِ معلق تفسیر می‌شود.
  List<Slot> absorb(Topic t, String n, {bool live = true}) {
    final out = <Slot>[];
    if (live) {
      echo.clear();
      flips.clear();
    }
    final unsure = Sense.saysDontKnow(n);
    final hedged = unsure && Sense.has(n, ' یا نه |شاید|مطمئن نیستم');
    final plainSwitch = live && Sense.wantsPlainToman(n);
    final reads = <String, String?>{for (final s in t.slots) s.id: s.read(n)};
    // «آره مدتش تموم شده»: بله‌ای که پشتش واقعیتِ بله/نه‌ایِ دیگری آمده،
    // جوابِ همان واقعیت است نه پرسشِ معلق.
    var otherBool = false;
    var otherAny = false;
    for (final e in reads.entries) {
      if (e.key == file.pending || e.value == null) continue;
      otherAny = true;
      if (e.value == 'yes' || e.value == 'no') otherBool = true;
    }
    for (final s in t.slots) {
      var v = reads[s.id];
      if (v != null && hedged && (v == 'yes' || v == 'no')) v = '?';
      if (live && v == null && s.id == file.pending && !plainSwitch) {
        final rp = s.readPending;
        final r = rp == null ? null : rp(n);
        if (r != null && !(otherBool && (r == 'yes' || r == 'no'))) v = r;
        if (v == null) {
          if (unsure) {
            if (!otherAny) v = '?';
          } else if (!otherBool) {
            if (Sense.saysYes(n) && s.yesValue.isNotEmpty) {
              v = s.yesValue;
            } else if (Sense.saysNo(n) && s.noValue.isNotEmpty) {
              v = s.noValue;
            }
          }
        }
      }
      if (v == null) continue;
      if (v == file.facts[s.id]) {
        if (live && v != '?') echo.add(s);
        continue;
      }
      if (v == '?' && file.has(s.id)) continue;
      // محورِ پرونده با اشارهٔ گذرا به موضوعی دیگر عوض نمی‌شود.
      if (s.sticky &&
          v != '?' &&
          file.has(s.id) &&
          s.id != file.pending &&
          !_outranks(s, v, file.get(s.id)) &&
          !_saidSure(s, n, v) &&
          !(live && Sense.has(n, _amend))) {
        continue;
      }
      final old = file.facts[s.id];
      if (live &&
          old != null &&
          (old == 'yes' || old == 'no') &&
          (v == 'yes' || v == 'no')) {
        flips[s.id] = old;
      }
      file.facts[s.id] = v;
      if (v != '?') out.add(s);
    }
    if (plainSwitch &&
        !out.any((s) => s.id == 'amount' || s.id == 'salary')) {
      for (final s in t.slots) {
        if (s.id != 'amount' && s.id != 'salary') continue;
        final cur = file.n(s.id);
        if (cur != null &&
            cur >= 1000000 &&
            cur < 1000000000 &&
            cur % 1000000 == 0) {
          final plain = cur ~/ 1000000;
          flips[s.id] = '$cur';
          file.facts[s.id] = '$plain';
          out.add(s);
          break;
        }
      }
    }
    return out;
  }

  bool roleUnknown(Topic t) {
    for (final s in t.slots) {
      if (s.id == 'role') return !file.has('role');
    }
    return false;
  }

}

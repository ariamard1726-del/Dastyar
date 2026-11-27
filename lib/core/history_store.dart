part of 'history.dart';

/// ذخیرهٔ گفتگوها روی همین گوشی، به‌صورت رمزنگاری‌شده و افزایشی.
///
/// پیش‌تر کل تاریخچه در یک کلید بود و با هر پیام، همهٔ گفتگوها از نو رمز
/// می‌شدند؛ هم هزینه‌اش با طول گفتگو درجه‌دوم بود و هم نوشتن‌های هم‌زمان
/// می‌توانستند نسخهٔ قدیمی را روی تازه بنشانند. اکنون:
///
/// - هر گفتگو کلید جدا دارد (`history_v1:m:<id>`) و با هر پیام فقط همان
///   گفتگو و فهرست کوتاه سرصفحه‌ها نوشته می‌شود.
/// - نوشتن‌ها در یک صف سریالی اجرا می‌شوند و نوشتن‌های پشت‌سرهم یک گفتگو در
///   یک دسته جمع می‌شوند؛ پس ترتیب نوشتن هرگز جابه‌جا نمی‌شود.
/// - خطای یک رکورد، آن رکورد را رد می‌کند، نه کل تاریخچه را.

class HistoryStore {
  /// کلید فهرست. همان کلید نسخهٔ قبلی است تا دادهٔ کهنه بی‌مشکل پیدا و
  /// مهاجرت شود؛ محتوایش اکنون فقط سرصفحه‌هاست.
  static const String _key = 'history_v1';
  static const String _msgPrefix = 'history_v1:m:';
  /// ۴: محموله علاوه بر پرونده، وضعیت گفتگو (`dialogue`) هم دارد.
  /// ۳ فقط `case` داشت و دکمههای بازیابی شده بیصدا معنای خود را ازدست میدادند.
  /// ۲ تنها پیامها را مینوشت.
  static const int _format = 4;

  static const int maxSessions = 30;
  static const int maxMessages = 100;
  static final RegExp _spacesRe = RegExp(r'\s+');

  final List<ChatSession> sessions = [];
  SharedPreferences? _prefs;

  /// گفتگوهایی که باید نوشته شوند (آخرین نسخه برنده است).
  final Map<String, ChatSession> _dirty = {};

  /// گفتگوهایی که باید از حافظه پاک شوند.
  final Set<String> _pendingDeletes = {};

  /// زنجیرهٔ نوشتن؛ همهٔ نوشتن‌ها پشت آن صف می‌شوند.
  Future<void> _writer = Future<void>.value();

  /// آخرین خطای ذخیره‌سازی؛ برای نمایش در صفحهٔ «اطلاعات» و عیب‌یابی.
  String? lastError;

  /// پیامی که کاربر باید بداند (مثلاً حذف خودکار گفتگوی قدیمی). برخلاف
  /// [lastError] یک شکست نیست، ولی نباید بیص بماند.
  String? lastNotice;

  Future<SharedPreferences> _prefsOrLoad() async {
    final ready = _prefs;
    if (ready != null) return ready;
    final loaded = await SharedPreferences.getInstance();
    _prefs = loaded;
    return loaded;
  }

  static String _msgKey(String id) => '$_msgPrefix$id';

  Future<void> load() async {
    sessions.clear();
    try {
      final prefs = await _prefsOrLoad();
      final stored = prefs.getString(_key);
      if (stored == null || stored.isEmpty) return;
      final wasPlain = !PrivacyService.isEncrypted(stored);
      final raw = await PrivacyService.open(stored);
      if (raw == null || raw.isEmpty) {
        // محمولهای مهرومومشده با کلید موقت اجراهای پیشین (`encf1:`)
        // اکنون قابل خواندن نیستند؛ نگهداشتنشان یعنی امید دادن به بازگشتی
        // که وجود ندارد. حذف صریح است، نه سکوت.
        if (stored.startsWith(PrivacyService.fallbackPrefix)) {
          // محمولههای تکتک گفتگوها هم همان سرنوشت را دارند؛ پاککردن فهرست
          // بهتنهایی رکوردهای ناخوانا را روی دستگاه باقی میگذارد.
          for (final k in prefs.getKeys().toList()) {
            if (k.startsWith(_msgPrefix) &&
                (prefs.getString(k) ?? '').startsWith(
                    PrivacyService.fallbackPrefix)) {
              await prefs.remove(k);
            }
          }
          await prefs.remove(_key);
          lastNotice = 'تاریخچهٔ قبلی با کلید موقت مهروموم شده بود و قابل '
              'خواندن نیست؛ پاک شد.';
        }
        return;
      }
      final decoded = jsonDecode(raw);

      // قالب قدیمی: یک فهرست کامل با متن پیام‌ها.
      if (decoded is List) {
        await _adoptLegacy(decoded);
        return;
      }
      if (decoded is! Map) return;
      final heads = decoded['sessions'];
      if (heads is! List) return;
      for (final h in heads) {
        if (h is! Map) continue;
        final s = await _readSession(h);
        if (s != null) sessions.add(s);
      }
      sessions.sort((a, b) => b.updated.compareTo(a.updated));
      if (sessions.length > maxSessions) {
        for (final s in sessions.sublist(maxSessions)) {
          _pendingDeletes.add(s.id);
        }
        sessions.removeRange(maxSessions, sessions.length);
        lastNotice = 'تعداد گفتگوها به $maxSessions محدود است؛ قدیمیترینها '
            'پاک شدند.';
      }
      // دادهٔ قدیمیِ رمزنشده یک بار به قالب رمزنگاری‌شده منتقل می‌شود.
      if (wasPlain || _pendingDeletes.isNotEmpty) await flush();
    } catch (e) {
      lastError = 'بازخوانی تاریخچه: $e';
    }
  }

  /// خواندن یک گفتگو از فهرست؛ اگر رکوردش خراب یا گم باشد، `null`.
  Future<ChatSession?> _readSession(Map<dynamic, dynamic> head) async {
    final id = (head['id'] ?? '').toString();
    if (id.isEmpty) return null;
    try {
      final prefs = await _prefsOrLoad();
      final stored = prefs.getString(_msgKey(id));
      if (stored == null || stored.isEmpty) return null;
      final raw = await PrivacyService.open(stored);
      if (raw == null || raw.isEmpty) {
        if (stored.startsWith(PrivacyService.fallbackPrefix)) {
          // حذف در همان صف نوشتن، پیش از بازنویسی فهرست انجام میشود.
          _pendingDeletes.add(id);
        }
        return null;
      }
      final decoded = jsonDecode(raw);
      // قالب ۲: فقط آرایهٔ پیامها. قالب ۳: `{v, messages, case?}`.
      // پروندهٔ وکیل باید همانطور برگردد تا «بله/نه»ها جابهجا نشوند.
      final messages = decoded is Map
          ? ChatSession.parseMessages(decoded['messages'])
          : ChatSession.parseMessages(decoded);
      final caseJson = decoded is Map ? ChatSession.parseCase(decoded['case']) : null;
      final dialogueJson =
          decoded is Map ? ChatSession.parseCase(decoded['dialogue']) : null;
      if (messages.isEmpty) return null;
      return ChatSession(
        id: id,
        title: (head['title'] ?? '').toString(),
        updated: head['updated'] is int ? head['updated'] as int : 0,
        messages: messages,
        caseJson: caseJson,
        dialogueJson: dialogueJson,
      );
    } catch (_) {
      // یک گفتگوی خراب، بقیهٔ تاریخچه را از بین نمی‌برد.
      return null;
    }
  }

  /// انتقال قالب نسخهٔ ۱ (یک آرایهٔ کامل) به قالب افزایشی.
  Future<void> _adoptLegacy(List raw) async {
    for (final e in raw) {
      if (e is! Map) continue;
      try {
        final s = ChatSession.fromJson(Map<String, dynamic>.from(e));
        if (s.id.isNotEmpty && s.messages.isNotEmpty) sessions.add(s);
      } catch (_) {
        // رکورد خراب رد می‌شود؛ بقیه می‌مانند.
      }
    }
    sessions.sort((a, b) => b.updated.compareTo(a.updated));
    if (sessions.length > maxSessions) {
      for (final s in sessions.sublist(maxSessions)) {
        _pendingDeletes.add(s.id);
      }
      sessions.removeRange(maxSessions, sessions.length);
    }
    for (final s in sessions) {
      _dirty[s.id] = s;
    }
    await flush();
  }

  Future<void> _writeSession(ChatSession s) async {
    if (!PrivacyService.persistenceAllowed) {
      lastError = 'ذخیرهٔ تاریخچه خاموش است: رمزنگاری بومی دردسترس نیست.';
      return;
    }
    final prefs = await _prefsOrLoad();
    var messages = s.messages;
    if (messages.length > maxMessages) {
      messages = messages.sublist(messages.length - maxMessages);
      s.messages = messages;
      lastNotice = 'این گفتگو به $maxMessages پیام محدود شد؛ قدیمیترین پیامها '
          'دیگر ذخیره نمیشوند.';
    }
    final payload = <String, dynamic>{
      'v': _format,
      'messages': [for (final m in messages) m.toJson()],
      // پرونده داخل همان محمولهٔ رمزنگاریشده مینویسد، نه در فهرست سرصفحهها.
      if (s.caseJson != null) 'case': s.caseJson,
      if (s.dialogueJson != null) 'dialogue': s.dialogueJson,
    };
    final sealed = await PrivacyService.seal(jsonEncode(payload));
    if (!await prefs.setString(_msgKey(s.id), sealed)) {
      throw StateError('SharedPreferences.setString failed');
    }
  }

  Future<void> _writeIndex() async {
    if (!PrivacyService.persistenceAllowed) {
      lastError = 'ذخیرهٔ فهرست تاریخچه خاموش است: رمزنگاری بومی دردسترس نیست.';
      return;
    }
    final prefs = await _prefsOrLoad();
    final heads = [
      for (final s in sessions)
        {
          'id': s.id,
          'title': s.title,
          'updated': s.updated,
          'count': s.messages.length,
        }
    ];
    final sealed =
        await PrivacyService.seal(jsonEncode({'v': _format, 'sessions': heads}));
    if (!await prefs.setString(_key, sealed)) {
      throw StateError('SharedPreferences.setString failed');
    }
  }

  /// نوشتن دستهٔ فعلی؛ تا وقتی چیزی برای نوشتن هست ادامه می‌دهد.
  Future<void> _drain() async {
    while (_dirty.isNotEmpty || _pendingDeletes.isNotEmpty) {
      final batch = Map<String, ChatSession>.from(_dirty);
      _dirty.clear();
      final gone = Set<String>.from(_pendingDeletes);
      _pendingDeletes.clear();
      final prefs = await _prefsOrLoad();
      for (final id in gone) {
        try {
          await prefs.remove(_msgKey(id));
        } catch (_) {}
      }
      for (final s in batch.values) {
        // خطای یک گفتگو، نوشتن بقیه را متوقف نمی‌کند.
        try {
          await _writeSession(s);
        } catch (e) {
          lastError = 'ذخیرهٔ گفتگو «${s.title}»: $e';
        }
      }
      try {
        await _writeIndex();
      } catch (e) {
        lastError = 'ذخیرهٔ فهرست تاریخچه: $e';
      }
    }
  }

  /// همهٔ نوشتن‌ها پشت این زنجیره صف می‌شوند؛ ترتیب حفظ می‌شود.
  Future<void> _flush() {
    final next = _writer.then((_) => _drain());
    _writer = next.catchError((Object e) {
      lastError = 'ذخیرهٔ تاریخچه: $e';
    });
    return next;
  }

  /// انتظار برای تمام‌شدن نوشتن‌های در صف (هنگام بستن برنامه).
  Future<void> flush() async {
    try {
      await _flush();
    } catch (_) {
      // خطا در [lastError] ثبت شده است.
    }
  }

  static String makeTitle(String firstUserText) {
    final t = firstUserText.replaceAll(_spacesRe, ' ').trim();
    return PersianText.truncate(t, 40, ellipsis: '...');
  }

  Future<void> upsert(ChatSession s) async {
    if (!PrivacyService.persistenceAllowed) {
      lastError = 'تاریخچه ذخیره نشد: رمزنگاری بومی دردسترس نیست.';
      return;
    }
    if (s.messages.length > maxMessages) {
      s.messages = s.messages.sublist(s.messages.length - maxMessages);
      lastNotice = 'این گفتگو به $maxMessages پیام محدود شد؛ قدیمیترین پیامها '
          'دیگر ذخیره نمیشوند.';
    }
    sessions.removeWhere((x) => x.id == s.id);
    sessions.insert(0, s);
    if (sessions.length > maxSessions) {
      for (final old in sessions.sublist(maxSessions)) {
        _pendingDeletes.add(old.id);
      }
      sessions.removeRange(maxSessions, sessions.length);
      lastNotice = 'تعداد گفتگوها به $maxSessions محدود است؛ قدیمیترینها '
          'پاک شدند.';
    }
    _dirty[s.id] = s;
    await flush();
  }

  Future<void> delete(String id) async {
    sessions.removeWhere((x) => x.id == id);
    _dirty.remove(id);
    _pendingDeletes.add(id);
    await flush();
  }

  /// پاک کردن هم باید پشت همان صف باشد؛ در غیر اینصورت نوشتنِ درصفی که پس
  /// از پاک کردن میرسد، تاریخچهای را که کاربر پاک کرد دوباره مینویسد.
  Future<void> clear() {
    final next = _writer.then((_) => _clearNow());
    _writer = next.catchError((Object e) {
      lastError = 'پاک کردن تاریخچه: $e';
    });
    return next;
  }

  Future<void> _clearNow() async {
    sessions.clear();
    _dirty.clear();
    _pendingDeletes.clear();
    lastNotice = null;
    try {
      final prefs = await _prefsOrLoad();
      for (final k in prefs.getKeys().toList()) {
        if (k == _key || k.startsWith(_msgPrefix)) await prefs.remove(k);
      }
    } catch (e) {
      lastError = 'پاک کردن تاریخچه: $e';
    }
  }

  /// صدور متنی تاریخچه برای خودِ کاربر (اسناد حساس از پیش ذخیره نشدهاند).
  /// چون محدودیت $maxSessions/$maxMessages وجود دارد، کاربر باید بتواند
  /// گفتگوهایش را قبل از حذف خودکار بیرون ببرد.
  static String exportText(Iterable<ChatSession> sessions) {
    final b = StringBuffer();
    for (final s in sessions) {
      if (s.messages.isEmpty) continue;
      b.writeln('# ${s.title.isEmpty ? "گفتگو" : s.title}');
      for (final m in s.messages) {
        final body = m.text.trim();
        if (body.isEmpty) continue;
        b.writeln('${m.fromUser ? 'شما' : 'دستیار'}: $body');
      }
      b.writeln();
    }
    return b.toString().trim();
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/core/privacy.dart';

class StoredMsg {
  final String text;
  final bool fromUser;

  /// دکمه‌های پیشنهادی همان پیام. پیش‌تر ذخیره نمی‌شدند و گفتگوی
  /// بازیابی‌شده همهٔ دکمه‌هایش را از دست می‌داد.
  final List<String> chips;

  StoredMsg(this.text, this.fromUser, {this.chips = const []});

  Map<String, dynamic> toJson() => {
        't': text,
        'u': fromUser,
        if (chips.isNotEmpty) 'c': chips,
      };

  factory StoredMsg.fromJson(Map<String, dynamic> j) => StoredMsg(
        (j['t'] ?? '').toString(),
        j['u'] == true,
        chips: parseChips(j['c']),
      );

  /// دکمه‌های ذخیره‌شده؛ ورودی نامعتبر فهرست خالی می‌دهد.
  static List<String> parseChips(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e != null && e.toString().trim().isNotEmpty) e.toString(),
    ];
  }
}

class ChatSession {
  final String id;
  String title;
  int updated;
  List<StoredMsg> messages;

  /// پروندهٔ وکیل در پایان این گفتگو (`CaseFile.toJson`)؛ `null` یعنی
  /// گفتگو پیش از این نسخه ذخیره شده و پرونده را باید از پیام‌ها بازسازی کرد.
  Map<String, dynamic>? caseJson;

  ChatSession({
    required this.id,
    required this.title,
    required this.updated,
    required this.messages,
    this.caseJson,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updated': updated,
        'messages': messages.map((m) => m.toJson()).toList(),
        if (caseJson != null) 'case': caseJson,
      };

  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        updated: j['updated'] is int ? j['updated'] as int : 0,
        messages: parseMessages(j['messages']),
        caseJson: parseCase(j['case']),
      );

  /// پروندهٔ ذخیره‌شده؛ ورودی نامعتبر `null` می‌دهد (و گفتگو با بازپخش
  /// پیام‌ها باز می‌شود، نه با کرش).
  static Map<String, dynamic>? parseCase(Object? raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  /// پیام‌های یک رکورد ذخیره‌شده؛ ورودی نامعتبر فهرست خالی می‌دهد.
  static List<StoredMsg> parseMessages(Object? raw) {
    final out = <StoredMsg>[];
    if (raw is! List) return out;
    for (final e in raw) {
      if (e is! Map) continue;
      out.add(StoredMsg.fromJson(Map<String, dynamic>.from(e)));
    }
    return out;
  }
}

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
  static const int _format = 2;

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
      if (raw == null || raw.isEmpty) return;
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
      }
      // دادهٔ قدیمیِ رمزنشده یک بار به قالب رمزنگاری‌شده منتقل می‌شود.
      if (wasPlain) await flush();
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
      if (raw == null || raw.isEmpty) return null;
      final messages = ChatSession.parseMessages(jsonDecode(raw));
      if (messages.isEmpty) return null;
      return ChatSession(
        id: id,
        title: (head['title'] ?? '').toString(),
        updated: head['updated'] is int ? head['updated'] as int : 0,
        messages: messages,
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
    final prefs = await _prefsOrLoad();
    var messages = s.messages;
    if (messages.length > maxMessages) {
      messages = messages.sublist(messages.length - maxMessages);
      s.messages = messages;
    }
    final raw = jsonEncode(messages.map((m) => m.toJson()).toList());
    final sealed = await PrivacyService.seal(raw);
    await prefs.setString(_msgKey(s.id), sealed);
  }

  Future<void> _writeIndex() async {
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
    await prefs.setString(_key, sealed);
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
    if (s.messages.length > maxMessages) {
      s.messages = s.messages.sublist(s.messages.length - maxMessages);
    }
    sessions.removeWhere((x) => x.id == s.id);
    sessions.insert(0, s);
    if (sessions.length > maxSessions) {
      for (final old in sessions.sublist(maxSessions)) {
        _pendingDeletes.add(old.id);
      }
      sessions.removeRange(maxSessions, sessions.length);
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

  Future<void> clear() async {
    // نوشتن‌های در صف تمام شوند تا فهرست پاک‌شده دوباره نوشته نشود.
    await flush();
    sessions.clear();
    _dirty.clear();
    _pendingDeletes.clear();
    try {
      final prefs = await _prefsOrLoad();
      for (final k in prefs.getKeys().toList()) {
        if (k == _key || k.startsWith(_msgPrefix)) await prefs.remove(k);
      }
    } catch (e) {
      lastError = 'پاک‌کردن تاریخچه: $e';
    }
  }
}

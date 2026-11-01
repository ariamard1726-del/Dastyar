import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'persian_text.dart';
import 'privacy.dart';

class StoredMsg {
  final String text;
  final bool fromUser;
  StoredMsg(this.text, this.fromUser);

  Map<String, dynamic> toJson() => {'t': text, 'u': fromUser};

  factory StoredMsg.fromJson(Map<String, dynamic> j) =>
      StoredMsg((j['t'] ?? '').toString(), j['u'] == true);
}

class ChatSession {
  final String id;
  String title;
  int updated;
  List<StoredMsg> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.updated,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updated': updated,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        updated: (j['updated'] ?? 0) as int,
        messages: ((j['messages'] ?? []) as List)
            .map((e) => StoredMsg.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class HistoryStore {
  static const String _key = 'history_v1';
  static const int maxSessions = 30;
  static const int maxMessages = 100;
  static final RegExp _spacesRe = RegExp(r'\s+');

  final List<ChatSession> sessions = [];
  SharedPreferences? _prefs;

  Future<void> load() async {
    sessions.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      final stored = prefs.getString(_key);
      if (stored == null || stored.isEmpty) return;
      final wasPlain = !PrivacyService.isEncrypted(stored);
      final raw = await PrivacyService.open(stored);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List;
      for (final e in list) {
        final s = ChatSession.fromJson(e as Map<String, dynamic>);
        if (s.id.isNotEmpty && s.messages.isNotEmpty) sessions.add(s);
      }
      sessions.sort((a, b) => b.updated.compareTo(a.updated));
      if (wasPlain && sessions.isNotEmpty) {
        await _persist();
      }
    } catch (_) {
      sessions.clear();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      final raw = jsonEncode(sessions.map((s) => s.toJson()).toList());
      final sealed = await PrivacyService.seal(raw);
      await prefs.setString(_key, sealed);
    } catch (_) {}
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
      sessions.removeRange(maxSessions, sessions.length);
    }
    await _persist();
  }

  Future<void> delete(String id) async {
    sessions.removeWhere((x) => x.id == id);
    await _persist();
  }

  Future<void> clear() async {
    sessions.clear();
    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}

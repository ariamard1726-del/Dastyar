import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  final List<ChatSession> sessions = [];
  SharedPreferences? _prefs;

  Future<void> load() async {
    sessions.clear();
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_key);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List;
      for (final e in list) {
        final s = ChatSession.fromJson(e as Map<String, dynamic>);
        if (s.id.isNotEmpty && s.messages.isNotEmpty) sessions.add(s);
      }
      sessions.sort((a, b) => b.updated.compareTo(a.updated));
    } catch (_) {
      sessions.clear();
    }
  }

  Future<void> _persist() async {
    try {
      final raw = jsonEncode(sessions.map((s) => s.toJson()).toList());
      await _prefs?.setString(_key, raw);
    } catch (_) {}
  }

  static String makeTitle(String firstUserText) {
    final t = firstUserText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= 40) return t;
    return '${t.substring(0, 40)}...';
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
      await _prefs?.remove(_key);
    } catch (_) {}
  }
}

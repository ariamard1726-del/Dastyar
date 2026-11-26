part of 'history.dart';

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

  /// وضعیت «روی میز» در لحظهٔ پایان گفتگو (`DialogueState.toJson`)؛ دکمههای
  /// بازیابی شده بدون آن فقط شکلاند، نه معنا.
  Map<String, dynamic>? dialogueJson;

  ChatSession({
    required this.id,
    required this.title,
    required this.updated,
    required this.messages,
    this.caseJson,
    this.dialogueJson,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updated': updated,
        'messages': messages.map((m) => m.toJson()).toList(),
        if (caseJson != null) 'case': caseJson,
        if (dialogueJson != null) 'dialogue': dialogueJson,
      };

  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        updated: j['updated'] is int ? j['updated'] as int : 0,
        messages: parseMessages(j['messages']),
        caseJson: parseCase(j['case']),
        dialogueJson: parseCase(j['dialogue']),
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

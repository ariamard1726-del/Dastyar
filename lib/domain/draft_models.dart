import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/privacy.dart';
import 'package:dastyar/domain/templates.dart';

class DraftCmd {
  static const String cancel = 'انصراف';
  static const String back = 'برگشت';
  static const String skip = 'رد کردن';
  static const String blank = 'جای خالی بماند';
  static const String edit = 'ویرایش یک پاسخ';
  static const String finish = 'پایان';
  static const String yes = 'بله';
  static const String no = 'خیر';
}

class DraftSession {
  static const int schemaVersion = 1;

  final LegalTemplate template;
  final Map<String, String> values = {};
  int index = 0;
  int? editing;
  bool pickingEdit = false;
  bool done = false;

  DraftSession(this.template);

  TemplateField? get current {
    final ed = editing;
    if (ed != null && ed >= 0 && ed < template.fields.length) {
      return template.fields[ed];
    }
    if (index >= 0 && index < template.fields.length) {
      return template.fields[index];
    }
    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'templateId': template.id,
        'templateVersion': template.version,
        'index': index,
        'editing': editing,
        'pickingEdit': pickingEdit,
        'done': done,
        'values': Map<String, String>.of(values),
      };

  static DraftSession? fromJson(
    Map<String, dynamic> j,
    List<LegalTemplate> templates,
  ) {
    final rawVer = j['schemaVersion'];
    if (rawVer is int && rawVer > schemaVersion) return null;
    final tid = (j['templateId'] ?? '').toString();
    if (tid.isEmpty) return null;
    LegalTemplate? tpl;
    for (final t in templates) {
      if (t.id == tid) {
        tpl = t;
        break;
      }
    }
    if (tpl == null) return null;
    final s = DraftSession(tpl);
    final rawIdx = j['index'];
    if (rawIdx is int && rawIdx >= 0 && rawIdx <= tpl.fields.length) {
      s.index = rawIdx;
    }
    final rawEd = j['editing'];
    if (rawEd is int && rawEd >= 0 && rawEd < tpl.fields.length) {
      s.editing = rawEd;
    }
    s.pickingEdit = j['pickingEdit'] == true;
    s.done = j['done'] == true;
    final rawVals = j['values'];
    if (rawVals is Map) {
      rawVals.forEach((k, v) {
        if (k != null && v != null) {
          s.values[k.toString()] = v.toString();
        }
      });
    }
    return s;
  }
}

/// ذخیره‌گاه رمزنگاری‌شدهٔ موقت برای پیش‌نویس ناتمام کاربر (بازیابی پس از بستن ناگهانی برنامه).
class DraftCheckpointStore {
  DraftCheckpointStore._();

  static const String _key = 'active_draft_v1';

  /// تمام خواندن/نوشتنها پشت یک صف سریالیاند. «گفتگوی جدید»، «باز کردن
  /// گفتگو» و ذخیرهٔ خودکار پیشنویس میتوانند پشت سر هم رخ دهند؛ بدون
  /// صف، پاک کردن قدیمی میتوانست بعد از ذخیرهٔ تازه بنشیند و پیشنویس کاربر
  /// را ببرد.
  static Future<void> _queue = Future<void>.value();

  static Future<T> _serial<T>(Future<T> Function() job) {
    final next = _queue.then((_) => job());
    _queue = next.then((_) {}, onError: (Object _) {});
    return next;
  }

  static Future<bool> save(DraftSession session) => _serial(() async {
        if (!PrivacyService.persistenceAllowed) return false;
        if (session.done) {
          // صدا نزدن به `clear` باعث قفلشدن صف میشود: خودمان داخل همان صف هستیم.
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(_key);
          } catch (_) {}
          return false;
        }
        try {
          final prefs = await SharedPreferences.getInstance();
          final raw = jsonEncode(session.toJson());
          final sealed = await PrivacyService.seal(raw);
          return await prefs.setString(_key, sealed);
        } catch (_) {
          return false;
        }
      });

  static Future<DraftSession?> load(List<LegalTemplate> templates) =>
      _serial(() async {
        if (templates.isEmpty) return null;
        try {
          final prefs = await SharedPreferences.getInstance();
          final stored = prefs.getString(_key);
          if (stored == null || stored.isEmpty) return null;
          final raw = await PrivacyService.open(stored);
          if (raw == null || raw.isEmpty) {
            if (stored.startsWith(PrivacyService.fallbackPrefix)) {
              await prefs.remove(_key);
            }
            return null;
          }
          final decoded = jsonDecode(raw);
          if (decoded is! Map<String, dynamic>) return null;
          final s = DraftSession.fromJson(decoded, templates);
          if (s == null || s.done) return null;
          return s;
        } catch (_) {
          return null;
        }
      });

  static Future<void> clear() => _serial(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_key);
        } catch (_) {}
      });
}

class DraftReply {
  final String text;
  final List<String> chips;
  final bool isDocument;
  final bool ended;
  final String note;

  const DraftReply(
    this.text, {
    this.chips = const [],
    this.isDocument = false,
    this.ended = false,
    this.note = '',
  });
}

class LawText {
  final String title;
  final String source;
  final String body;
  final String note;

  /// وضعیت بازبینی متن قانون: `verified`، `unverified` یا خالی (نامعلوم).
  /// در UI به کاربر نشان داده می‌شود تا متن تأییدنشده با ظاهر رسمی نیاید.
  final String status;

  LawText(this.title, this.source, this.body, this.note, {this.status = ''});

  /// آیا این متن با منبع رسمی تطبیق داده شده است؟
  bool get verified => status == 'verified';
}

class IntentResult {
  final LegalTemplate? template;
  final List<LegalTemplate> choices;
  const IntentResult(this.template, this.choices);
  bool get none => template == null && choices.isEmpty;
}

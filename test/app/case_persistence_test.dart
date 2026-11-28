import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/core/privacy.dart';
import 'package:dastyar/ui/app_settings.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/ui/chat_controller.dart';

/// پروندهٔ گفتگو باید با خود گفتگو ذخیره و بازیابی شود.
///
/// پیش‌تر برای بازکردن گفتگوی ذخیره‌شده، همهٔ پیام‌های کاربر دوباره از کل
/// خط لوله می‌گذشتند (`Advocate.replay`)؛ اگر قاعده‌ای عوض شده بود، پروندهٔ
/// بازیابی‌شده با پروندهٔ اصلی یکی نبود و پاسخ «بله/نه»های قبلی از دست
/// می‌رفت.
List<LegalTemplate> _templates() {
  final out = <LegalTemplate>[];
  for (final f in Directory('assets/templates').listSync()) {
    if (f is File && f.path.endsWith('.json')) {
      final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      out.add(LegalTemplate.fromJson(m));
    }
  }
  out.sort((a, b) => a.id.compareTo(b.id));
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;
  late List<LegalTemplate> templates;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
    templates = _templates();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  ChatController make(HistoryStore history) => ChatController(
        engine: engine,
        repo: TemplateRepository()..templates.addAll(templates),
        history: history,
        settings: AppSettings()..saveHistory = true,
      );

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  test('پرونده در تاریخچه ذخیره می‌شود و همان‌طور برمی‌گردد', () async {
    final history = HistoryStore();
    await history.load();
    final a = make(history);

    await a.submit('صاحبخونه پول پیشمو نمیده');
    await settle();
    expect(a.advocate.file.topic, isNotEmpty);
    expect(history.sessions, isNotEmpty);
    final saved = history.sessions.first;
    expect(saved.caseJson, isNotNull, reason: 'پرونده ذخیره نشده است');
    final topic = a.advocate.file.topic;
    final facts = Map<String, String>.from(a.advocate.file.facts);
    a.dispose();

    // گفتگوی ذخیره‌شده در نشستی تازه باز می‌شود.
    final b = make(history);
    b.loadSession(saved);
    expect(b.advocate.file.topic, topic);
    expect(b.advocate.file.facts, facts);
    b.dispose();
  });

  test('وضعیت گفتگو با تاریخچه ذخیره و همانطور بازیابی میشود', () async {
    final history = HistoryStore();
    await history.load();
    final a = make(history);
    await a.submit('صاحبخونه پول پیشمو نمیده');
    await settle();
    final expected = jsonEncode(a.advocate.dialog.toJson());
    final saved = history.sessions.first;
    expect(saved.dialogueJson, isNotNull,
        reason: 'وضعیت روی میز در محموله نوشته نشده است');
    a.dispose();

    final b = make(history);
    b.loadSession(saved);
    expect(jsonEncode(b.advocate.dialog.toJson()), expected);
    b.dispose();
  });

  test('پرونده پس از بستهشدن و بارگذاری دوبارهٔ تاریخچه هم میماند', () async {
    final history = HistoryStore();
    await history.load();
    final a = make(history);

    await a.submit('صاحبخونه پول پیشمو نمیده');
    await settle();
    final topic = a.advocate.file.topic;
    final facts = Map<String, String>.from(a.advocate.file.facts);
    final id = a.sessionId;
    a.dispose();

    // یک نمونهٔ تازه، مثل راهاندازی مجدد برنامه: پرونده应从 prefs خوانده
    // شود، نه از حافظهٔ نمونهٔ قبلی.
    final reopened = HistoryStore();
    await reopened.load();
    final saved = reopened.sessions.firstWhere((s) => s.id == id);
    expect(saved.caseJson, isNotNull,
        reason: 'پرونده در محمولهٔ ذخیرهشده نوشته نشده است');
    final b = make(reopened);
    b.loadSession(saved);
    expect(b.advocate.file.topic, topic);
    expect(b.advocate.file.facts, facts);
    b.dispose();
  });

  test('محمولهٔ قدیمی فقط-پیامها هم خوانده میشود', () async {
    const id = 'old-format-1';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'history_v1',
      await PrivacyService.seal(jsonEncode({
        'v': 2,
        'sessions': [
          {'id': id, 'title': 'قدیمی', 'updated': 1, 'count': 1},
        ],
      })),
    );
    await prefs.setString(
      'history_v1:m:$id',
      await PrivacyService.seal(
          jsonEncode([{'t': 'صاحبخونه پول پیشمو نمیده', 'u': true}])),
    );

    final reopened = HistoryStore();
    await reopened.load();
    expect(reopened.sessions, hasLength(1));
    expect(reopened.sessions.single.messages.single.text,
        'صاحبخونه پول پیشمو نمیده');
    expect(reopened.sessions.single.caseJson, isNull);
  });

  test('گفتگوی قدیمی بدون پرونده، با بازپخش پیام‌ها باز می‌شود', () async {
    final history = HistoryStore();
    await history.load();
    final c = make(history);

    final legacy = ChatSession(
      id: 'legacy-1',
      title: 'قدیمی',
      updated: 1,
      messages: [StoredMsg('صاحبخونه پول پیشمو نمیده', true)],
    );
    c.loadSession(legacy);
    expect(c.advocate.file.topic, isNotEmpty);
    c.dispose();
  });

  test('پروندهٔ خالی در رکورد ذخیره نمی‌شود', () async {
    final history = HistoryStore();
    await history.load();
    final c = make(history);

    await c.submit('سلام');
    await settle();
    expect(history.sessions, isNotEmpty);
    expect(history.sessions.first.caseJson, isNull);
    c.dispose();
  });

  test('رکورد JSON پرونده را نگه می‌دارد و ورودی بدشکل را رد می‌کند', () {
    final s = ChatSession(
      id: '1',
      title: 't',
      updated: 2,
      messages: const [],
      caseJson: {'v': 1, 'topic': 'rent'},
    );
    final back = ChatSession.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(back.caseJson, isNotNull);
    expect(back.caseJson!['topic'], 'rent');

    final bad = ChatSession.fromJson({'id': '2', 'case': 'not-a-map'});
    expect(bad.caseJson, isNull);
  });
  test('دکمه‌های پیشنهادی با گفتگو ذخیره و بازیابی می‌شوند', () async {
    final history = HistoryStore();
    await history.load();
    final a = make(history);

    await a.submit('صاحبخونه پول پیشمو نمیده');
    await settle();
    final withChips =
        a.messages.where((m) => !m.fromUser && m.chips.isNotEmpty).toList();
    expect(withChips, isNotEmpty, reason: 'پاسخ هیچ دکمه‌ای نداشت');
    final saved = history.sessions.first;
    a.dispose();

    final b = make(history);
    b.loadSession(saved);
    final restored =
        b.messages.where((m) => !m.fromUser && m.chips.isNotEmpty).toList();
    expect(restored, isNotEmpty, reason: 'دکمه‌ها پس از بازیابی گم شدند');
    expect(restored.first.chips, withChips.first.chips);
    b.dispose();
  });

  test('دکمه‌های نامعتبر در رکورد JSON رد می‌شوند', () {
    final m = StoredMsg.fromJson({'t': 'x', 'u': false, 'c': 'not-a-list'});
    expect(m.chips, isEmpty);
    final m2 = StoredMsg.fromJson({
      't': 'x',
      'u': false,
      'c': ['الف', null, '  ', 'ب'],
    });
    expect(m2.chips, ['الف', 'ب']);
  });

}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/domain/understanding/topic_guess.dart';
import 'package:dastyar/ui/chat_controller.dart';
import 'package:dastyar/ui/chat_models.dart';
import 'package:dastyar/ui/draft_flow.dart';
import 'package:dastyar/ui/guess_flow.dart';
import 'package:dastyar/ui/reply_flow.dart';

List<LegalTemplate> _loadTemplatesSync() {
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
    templates = _loadTemplatesSync();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('GuessFlow در انزوا', () {
    test('وقتی قاعده‌ها موضوع را بشناسند سراغ مدل نمی‌رود', () async {
      final advocate = Advocate(engine);
      final posted = <ChatMessage>[];
      var calls = 0;
      final flow = GuessFlow(
        advocate: advocate,
        guesser: (String _) async {
          calls++;
          return const TopicGuess('labor', 0.9, 'rent', 0.1, confident: true);
        },
        post: posted.add,
        changed: () {},
        scrollToEnd: () {},
        isAlive: () => true,
        onProblem: (_) {},
      );

      final res = await flow.read(
        'صاحبخانه پول پیشم را پس نمی‌دهد',
        isCurrent: () => true,
      );
      expect(calls, 0);
      expect(res.guess, isNull);
      expect(res.shown, isFalse);
      expect(res.stale, isFalse);
      expect(posted, isEmpty);
      expect(flow.thinking, isFalse);
    });

    test('در انتظار مدل، thinking روشن می‌شود و نتیجهٔ تازه در lastGuess می‌ماند',
        () async {
      final gate = Completer<TopicGuess?>();
      final posted = <ChatMessage>[];
      var changes = 0;
      var scrolls = 0;
      final flow = GuessFlow(
        advocate: Advocate(engine),
        guesser: (_) => gate.future,
        post: posted.add,
        changed: () => changes++,
        scrollToEnd: () => scrolls++,
        isAlive: () => true,
        onProblem: (_) {},
      );

      final pending = flow.read(
        'رئیسم به من گفته دیگر لازم نیست بیایی',
        isCurrent: () => true,
      );
      expect(flow.thinking, isTrue);
      expect(posted.length, 1);
      expect(posted.single.fromUser, isTrue);
      expect(changes, 1);
      expect(scrolls, 1);

      const expected = TopicGuess('labor', 0.92, 'rent', 0.05, confident: true);
      gate.complete(expected);
      final res = await pending;
      expect(flow.thinking, isFalse);
      expect(res.stale, isFalse);
      expect(res.shown, isTrue);
      expect(res.guess?.label, 'labor');
      expect(flow.lastGuess?.label, 'labor');
    });

    test('خطای مدل ثبت می‌شود و تغییر گفتگو نتیجهٔ کهنه را دور می‌ریزد',
        () async {
      final problems = <String>[];
      var current = true;
      final gate = Completer<TopicGuess?>();
      final flow = GuessFlow(
        advocate: Advocate(engine),
        guesser: (_) => gate.future,
        post: (_) {},
        changed: () {},
        scrollToEnd: () {},
        isAlive: () => true,
        onProblem: problems.add,
      );

      final pending = flow.read(
        'رئیسم به من گفته دیگر لازم نیست بیایی',
        isCurrent: () => current,
      );
      current = false;
      gate.completeError(StateError('boom'));
      final res = await pending;

      expect(res.stale, isTrue);
      expect(res.shown, isTrue);
      expect(flow.thinking, isFalse);
      expect(flow.lastGuess, isNull);
      expect(problems.length, 1);
    });
  });

  group('ReplyFlow و ChatController', () {
    test('پیشنهاد سندِ وکیل با «بله» مستقیماً وارد DraftFlow می‌شود', () async {
      final repo = TemplateRepository()..templates.addAll(templates);
      final settings = AppSettings()..saveHistory = false;
      final messages = <ChatMessage>[];
      final advocate = Advocate(
        engine,
        draftTitles: {for (final t in repo.templates) t.id: t.title},
      );
      late ReplyFlow replyFlow;
      final draftFlow = DraftFlow(
        engine: engine,
        repo: repo,
        advocate: advocate,
        settings: settings,
        post: messages.add,
        changed: () {},
        scrollToEnd: () {},
        save: () => unawaited(replyFlow.saveSession()),
        isAlive: () => true,
      );
      final guessFlow = GuessFlow(
        advocate: advocate,
        guesser: null,
        post: messages.add,
        changed: () {},
        scrollToEnd: () {},
        isAlive: () => true,
        onProblem: (msg) => replyFlow.addProblem(msg),
      );
      replyFlow = ReplyFlow(
        engine: engine,
        history: HistoryStore(),
        settings: settings,
        advocate: advocate,
        draftFlow: draftFlow,
        guessFlow: guessFlow,
        messages: messages,
        changed: () {},
        scrollToEnd: () {},
        isAlive: () => true,
      );

      // موضوع را به مرحلهٔ پیشنهاد تنظیم سند می‌رسانیم.
      await replyFlow.submit('صاحبخونه پول پیشمو نمیده');
      advocate.dialog.offer = 'draft';
      advocate.dialog.offerDraft = 'demand_money';
      await replyFlow.submit('بله');

      expect(draftFlow.isDrafting, isTrue);
      expect(draftFlow.draft?.template.id, 'demand_money');
      expect(advocate.offeredDraft, isNull);
    });

    test('saveSession و loadSession پرونده و تاریخچه را دقیق برمی‌گردانند',
        () async {
      final repo = TemplateRepository()..templates.addAll(templates);
      final history = HistoryStore();
      await history.load();
      final ctrl = ChatController(
        engine: engine,
        repo: repo,
        history: history,
        settings: AppSettings()..saveHistory = true,
      );

      await ctrl.submit('صاحبخونه پول پیشمو نمیده');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(history.sessions.length, 1);
      final saved = history.sessions.single;

      ctrl.newChat();
      expect(ctrl.messages, isEmpty);
      expect(ctrl.advocate.hasCase, isFalse);

      ctrl.loadSession(saved);
      expect(ctrl.sessionId, saved.id);
      expect(ctrl.advocate.file.topic, 'rent');
      expect(ctrl.messages.every((m) => m.revealed), isTrue);
      ctrl.dispose();
    });

    test('transcript، hasSensitive، loadError و initialDraft در کنترلر کار می‌کنند',
        () async {
      final repo = TemplateRepository()..templates.addAll(templates);
      final demand = templates.firstWhere((t) => t.id == 'demand_money');
      final initial = DraftSession(demand);
      DraftStep.answer(initial, 'تهران');
      final ctrl = ChatController(
        engine: engine,
        repo: repo,
        history: HistoryStore(),
        settings: AppSettings()..saveHistory = false,
        loadError: 'هشدار بارگذاری',
        initialDraft: initial,
      );

      expect(ctrl.hasSensitive, isTrue);
      expect(ctrl.isDrafting, isTrue);
      expect(ctrl.transcript(), isNotEmpty);
      expect(ctrl.messages.first.sensitive, isTrue);

      ctrl.resetAfterHistoryClear();
      expect(ctrl.isDrafting, isFalse);
      expect(ctrl.messages, isEmpty);
      expect(ctrl.hasSensitive, isFalse);
      ctrl.dispose();
    });
  });
}

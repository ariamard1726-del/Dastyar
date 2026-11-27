import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/dialogue_state.dart';
import 'package:dastyar/domain/advocate/reply_voice.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';

/// قرارداد فاز ۳: گرهِ مرکزی (`Advocate`) سقف بازگشت صریح دارد (`maxReplyDepth`)
/// و `file.turns` در هر پیامِ کاربر دقیقاً یکی بالا می‌رود (نه در فراخوانیِ
/// خودساختهٔ `again: true`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  Advocate fresh() => Advocate(engine);

  test('سقف بازگشت روی ReplyLoopGuard: عمق ۱ مجاز، عمق ۲ و !again خطا', () {
    final guard = ReplyLoopGuard(maxDepth: Advocate.maxReplyDepth);

    // یک نوبتِ عادی بدون بازگشت.
    final single = guard.run<int>(again: false, body: () => 1);
    expect(single, 1);
    expect(guard.lastDepth, 0);
    expect(guard.lastEntries, 1);
    expect(guard.depth, 0);

    // بازگشت مجاز (عمق ۱) فقط با `again: true`.
    final oneHop = guard.run<int>(
      again: false,
      body: () => guard.run<int>(again: true, body: () => 2),
    );
    expect(oneHop, 2);
    expect(guard.lastDepth, 1);
    expect(guard.lastEntries, 2);
    expect(guard.depth, 0);

    // بازگشت دوم (عمق ۲ > maxReplyDepth) باید فوری با StateError بشکند.
    expect(
      () => guard.run<void>(
        again: false,
        body: () => guard.run<void>(
          again: true,
          body: () => guard.run<void>(again: true, body: () {}),
        ),
      ),
      throwsStateError,
    );
    expect(guard.depth, 0);

    // فراخوانی بازگشتی بدون `again: true` نباید بتواند نوبت را دو بار بشمارد.
    expect(
      () => guard.run<void>(
        again: false,
        body: () => guard.run<void>(again: false, body: () {}),
      ),
      throwsStateError,
    );
    expect(guard.depth, 0);

    // بعد از خطا هم نگهبان قفل نمی‌ماند و نوبت بعدی عادی کار می‌کند.
    expect(guard.run<int>(again: false, body: () => 3), 3);
    expect(guard.lastDepth, 0);
    expect(guard.lastEntries, 1);
  });

  test('ساختنِ حلقهٔ routes → reply → routes با سقف بازگشت متوقف می‌شود', () {
    final file = CaseFile()..topic = 'rent';
    final dialog = DialogueState()..offer = 'argue';
    final voice = ReplyVoice(engine: engine, file: file, unresolved: <String>[]);
    final guard = ReplyLoopGuard(maxDepth: Advocate.maxReplyDepth);

    ChipPlan makeChipPlan() => ChipPlan(
          file: file,
          dialog: dialog,
          filings: const <Filing>[],
          draftTitles: const <String, String>{},
        );

    final picker = TopicPicker(
      file: file,
      dialog: dialog,
      intentNet: null,
      open: (t, n, {bool guessed = false}) => AdvocateReply('باز شد'),
      voice: () => voice,
    );
    final talk = TalkReply(
      file: file,
      dialog: dialog,
      voice: voice,
      intentNet: null,
      chipPlan: makeChipPlan,
    );
    final argument = CaseArgument(
      file,
      voice,
      (t) => recapOf(t, file),
      <String, String>{},
    );
    final law = LawAnswer(
      engine: engine,
      voice: voice,
      party: (n) => '',
    );
    final flow = CaseFlow(
      file: file,
      dialog: dialog,
      voice: voice,
      argument: argument,
      picker: picker,
      talk: talk,
      law: law,
      chipPlan: makeChipPlan,
      filings: () => const <Filing>[],
      draftTitles: const <String, String>{},
      echo: const <Slot>[],
      flips: const <String, String>{},
      glossary: (n) => null,
      openGuide: (g, raw, n, {bool? switched}) => AdvocateReply('راهنما'),
      fillFor: (id) => const <String, String>{},
      draftIds: const <String>[],
    );
    final talkRoute = TalkRoute(
      file: file,
      dialog: dialog,
      voice: voice,
      engine: engine,
      talk: talk,
      picker: picker,
      chipPlan: makeChipPlan,
      closeCase: () {},
    );

    final yesNorm = Sense.norm('بله');
    late final ReplyRoutes routes;
    routes = ReplyRoutes(
      file: file,
      dialog: dialog,
      voice: voice,
      flow: flow,
      picker: picker,
      talk: talk,
      talkRoute: talkRoute,
      // حلقهٔ ساختگی: اگر مسیر پیشنهاد دوباره به خودش برگردد، باید با
      // StateError متوقف شود، نه با سرریز پشته.
      reply: (raw, {bool again = true}) => guard.run<AdvocateReply>(
        again: again,
        body: () {
          dialog.offer = 'argue';
          return routes.offer('بله', yesNorm, true)!;
        },
      ),
    );

    expect(
      () => guard.run<AdvocateReply>(
        again: false,
        body: () => routes.offer('بله', yesNorm, true)!,
      ),
      throwsStateError,
    );
    expect(guard.depth, 0);
  });

  test('file.turns در هر پیامِ کاربر دقیقاً یکی بزرگ می‌شود', () {
    final a = fresh();
    expect(a.file.turns, 0);

    const messages = <String>[
      'سلام',
      'صاحبخونه پول پیشمو نمیده',
      '۱۵۰ میلیون',
      'شوهرم منو زد و تهدید کرد',
      'انصراف',
      'لاک‌پشت بنفش دارم',
    ];
    for (var i = 0; i < messages.length; i++) {
      final before = a.file.turns;
      a.respond(messages[i]);
      expect(a.file.turns, before + 1, reason: messages[i]);
      expect(a.lastReplyDepth, lessThanOrEqualTo(Advocate.maxReplyDepth));
    }
    expect(a.file.turns, messages.length);

    a.reset();
    expect(a.file.turns, 0);
    expect(a.lastReplyDepth, 0);
    expect(a.lastReplyEntries, 0);

    a.replay(messages.take(3));
    expect(a.file.turns, 3);
  });

  test('مسیر بازگشتیِ offer با again: true نوبت را فقط یکی می‌شمارد', () {
    final a = fresh();
    for (final msg in const [
      'صاحبخونه پول پیشمو نمیده',
      '۱۵۰ میلیون',
      'آره قرارداد تموم شده، یه ماهه خونه رو خالی کردم',
    ]) {
      a.respond(msg);
    }

    var guard = 0;
    var last = a.respond('نمیدونم');
    while (!last.chips.contains('بله، بگو') && guard < 14) {
      guard++;
      last = a.respond('نمیدونم');
    }
    expect(last.chips, contains('بله، بگو'));
    expect(a.dialog.offer, anyOf('argue', 'next'));

    final beforeTurns = a.file.turns;
    final yes = a.respond(ChipTexts.moreChip);
    expect(yes.chips, isNotEmpty);
    expect(a.lastReplyDepth, 1);
    expect(a.lastReplyDepth, lessThanOrEqualTo(Advocate.maxReplyDepth));
    expect(a.lastReplyEntries, 2);
    expect(a.file.turns, beforeTurns + 1);
  });

  test('پیشنهادِ سند (offer == draft) بازگشت نمی‌زند و نوبت یکی بالا می‌رود', () {
    final a = Advocate(engine, draftTitles: const {
      'demand_money': 'دادخواست مطالبه وجه',
    });
    a.respond('صاحبخونه پول پیشمو نمیده');
    a.voice.rest = '';
    a.voice.offeredMore = false;
    a.dialog.offer = 'draft';
    final beforeTurns = a.file.turns;

    final r = a.respond('بله');
    expect(r.chips, isNotEmpty);
    expect(a.lastReplyDepth, 0);
    expect(a.lastReplyEntries, 1);
    expect(a.file.turns, beforeTurns + 1);
  });
}

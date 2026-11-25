import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/domain/understanding/topic_guess.dart';
import 'package:dastyar/domain/understanding/topic_reader.dart';
import 'package:dastyar/ui/chat_controller.dart';

/// حدسِ مدل فقط «نظر دوم» است: جایی که قاعده‌ها موضوع را شناخته‌اند اثری
/// ندارد؛ حدسِ مطمئن پرونده را باز می‌کند و کاربر می‌تواند ردش کند؛ حدسِ
/// نامطمئن به پرسش از خودِ کاربر می‌رسد.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  // جمله‌ای که قاعده‌ها موضوعش را نمی‌شناسند.
  const unknown = 'رئیسم به من گفته دیگر لازم نیست بیایی';

  TopicGuess sure(String label, [String second = 'other']) =>
      TopicGuess(label, 0.4, second, 0.05, confident: true, plausible: true);
  TopicGuess unsure(String label, String second) =>
      TopicGuess(label, 0.12, second, 0.1, plausible: true);

  test('همهٔ موضوع‌های نگاشت‌شده در وکیل وجود دارند', () {
    final ids = Advocate.topics.map((t) => t.id).toSet();
    guessTopics.forEach((label, list) {
      expect(list, isNotEmpty, reason: label);
      for (final id in list) {
        expect(ids, contains(id), reason: label);
      }
    });
  });

  test('جمله‌ای که قاعده‌ها نمی‌شناسند: بدون حدس پرونده‌ای باز نمی‌شود', () {
    final a = Advocate(engine);
    expect(a.wantsGuess(unknown), isTrue);
    a.respond(unknown);
    expect(a.file.topic, isEmpty);
  });

  test('حدسِ مطمئن پرونده را باز می‌کند و می‌گوید که برداشتِ خودش است', () {
    final a = Advocate(engine);
    final r = a.respond(unknown, guess: sure('labor'));
    expect(a.file.topic, 'labor');
    expect(r.chips, contains(ChipTexts.wrongChip));
    expect(r.chips, contains(ChipTexts.wrongChip));
    expect(r.chips.first, ChipTexts.wrongChip);
    expect(a.wantsGuess('حقوقم را هم نداده'), isFalse);
  });

  test('کاربر می‌تواند حدسِ غلط را رد کند', () {
    for (final reply in [ChipTexts.wrongChip, 'نه موضوعم این نیست']) {
      final a = Advocate(engine);
      a.respond(unknown, guess: sure('rent'));
      expect(a.file.topic, 'rent');
      final r = a.respond(reply);
      expect(a.file.topic, isEmpty, reason: reply);
    expect(r.chips, contains(ChipTexts.leaveChip));
    }
  });

  test('ردِ حدس فقط برای پیامِ بلافاصله بعدی معنا دارد', () {
    final a = Advocate(engine);
    a.respond(unknown, guess: sure('labor'));
    a.respond('قرارداد کتبی دارم');
    a.respond(ChipTexts.wrongChip);
    expect(a.file.topic, 'labor');
  });

  test('حدسِ نامطمئن: از کاربر می‌پرسد و با انتخاب او پرونده باز می‌شود', () {
    final a = Advocate(engine);
    final r = a.respond(unknown, guess: unsure('labor', 'rent'));
    expect(a.file.topic, isEmpty);
    expect(r.chips,
        ['کار و کارفرما', 'اجاره و ودیعه', ChipTexts.noneChip, ChipTexts.leaveChip]);
    expect(r.chips, contains(ChipTexts.noneChip));
    expect(a.wantsGuess('کار و کارفرما'), isFalse);
    a.respond('اجاره و ودیعه');
    expect(a.file.topic, 'rent');
  });

  test('حدسِ نامطمئن با یک گزینه: «بله» همان را باز می‌کند', () {
    final a = Advocate(engine);
    final r = a.respond(unknown, guess: unsure('labor', 'general'));
    expect(r.chips,
        ['کار و کارفرما', ChipTexts.noneChip, ChipTexts.leaveChip]);
    a.respond('بله');
    expect(a.file.topic, 'labor');
  });

  test('«هیچ‌کدام» پرونده‌ای باز نمی‌کند و از کاربر می‌خواهد تعریف کند', () {
    final a = Advocate(engine);
    a.respond(unknown, guess: unsure('labor', 'rent'));
    final r = a.respond(ChipTexts.noneChip);
    expect(a.file.topic, isEmpty);
    expect(r.text, contains('چه اتفاقی افتاده'));
    // پرسشِ «کدام؟» دیگر معتبر نیست.
    a.respond('اجاره و ودیعه');
    expect(a.file.topic, isNot('labor'));
  });

  test('حدسِ ضعیف یا دسته‌ای که پرونده ندارد نادیده گرفته می‌شود', () {
    for (final g in [
      const TopicGuess('labor', 0.05, 'rent', 0.04),
      sure('general'),
      sure('crime'),
      sure('chat'),
      sure('other'),
    ]) {
      final plain = Advocate(engine);
      final hinted = Advocate(engine);
      final want = plain.respond(unknown).text;
      final got = hinted.respond(unknown, guess: g).text;
      expect(hinted.file.topic, isEmpty, reason: '$g');
      expect(got, want, reason: '$g');
    }
  });

  test('جایی که قاعده‌ها موضوع را شناخته‌اند حدس هیچ چیز را عوض نمی‌کند', () {
    final samples = [
      for (final line in File('eval/intent_eval.txt').readAsLinesSync())
        if (!line.startsWith('#') && line.indexOf('|') > 0)
          line.substring(line.indexOf('|') + 1).trim(),
    ];
    expect(samples.length, greaterThan(100));
    var known = 0;
    for (final text in samples) {
      final plain = Advocate(engine);
      final want = plain.respond(text);
      if (plain.file.topic.isEmpty) continue;
      known++;
      final hinted = Advocate(engine);
      expect(hinted.wantsGuess(text), isFalse, reason: text);
      final got = hinted.respond(text, guess: sure('neighbor', 'cyber'));
      expect(hinted.file.topic, plain.file.topic, reason: text);
      expect(got.text, want.text, reason: text);
    }
    expect(known, greaterThan(30));
  });

  test('وسط یک پرونده و برای پیام‌های کوتاه حدس خواسته نمی‌شود', () {
    final a = Advocate(engine);
    expect(a.wantsGuess('سلام'), isFalse);
    expect(a.wantsGuess('ماده 10 قانون کار چه می‌گوید'), isFalse);
    a.respond('صاحبخانه پول پیشم را پس نمی‌دهد');
    expect(a.file.topic, 'rent');
    expect(a.wantsGuess(unknown), isFalse);
    // حدسی که وسط پرونده برسد هم اثری ندارد.
    a.respond('قرارداد یک ساله بود', guess: sure('labor'));
    expect(a.file.topic, 'rent');
  });

  test('حدسِ مطمئن بر راهنمای آماده‌ای که با یک واژه انتخاب شده مقدم است', () {
    const text = 'من ضامن شده ام و بانک حقوقم را کسر میکند';
    final plain = Advocate(engine);
    plain.respond(text);
    expect(plain.file.topic, isEmpty);
    final a = Advocate(engine);
    a.respond(text, guess: sure('guarantee', 'debt'));
    expect(a.file.topic, 'guarantee');
    // حدسِ نامطمئن راهنما را کنار نمی‌زند.
    final b = Advocate(engine);
    final want = Advocate(engine).respond(text).text;
    expect(b.respond(text, guess: unsure('guarantee', 'debt')).text, want);
  });

  test('«یک سؤال حقوقی دارم» با حدسِ مدل پرونده باز نمی‌کند', () {
    final a = Advocate(engine);
    a.respond('سلام من یک سوال حقوقی دارم', guess: sure('accused'));
    expect(a.file.topic, isEmpty);
  });

  group('کنترلر گفتگو', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    ChatController build(Future<TopicGuess?> Function(String)? guesser) {
      return ChatController(
        engine: engine,
        repo: TemplateRepository(),
        history: HistoryStore(),
        settings: AppSettings()..saveHistory = false,
        guesser: guesser,
      );
    }

    test('فقط وقتی قاعده‌ها نمی‌دانند مدل را صدا می‌زند', () async {
      final asked = <String>[];
      final c = build((t) async {
        asked.add(t);
        return sure('labor');
      });
      await c.submit('صاحبخانه پول پیشم را پس نمی‌دهد');
      expect(asked, isEmpty);
      expect(c.advocate.file.topic, 'rent');
      c.newChat();
      await c.submit(unknown);
      expect(asked, [unknown]);
      expect(c.advocate.file.topic, 'labor');
      expect(c.messages.length, 2);
      expect(c.messages[0].fromUser, isTrue);
      expect(c.messages[1].chips.first, ChipTexts.wrongChip);
      expect(c.thinking, isFalse);
    });

    test('تا رسیدن حدس، پیام کاربر دیده می‌شود و پیام بعدی نوبت می‌گیرد',
        () async {
      final gate = Completer<TopicGuess?>();
      final c = build((t) => gate.future);
      final first = c.submit(unknown);
      await Future<void>.delayed(Duration.zero);
      expect(c.thinking, isTrue);
      expect(c.messages.length, 1);
      expect(c.messages.single.text, unknown);
      final second = c.submit('قرارداد کتبی دارم');
      await Future<void>.delayed(Duration.zero);
      expect(c.messages.length, 1);
      gate.complete(sure('labor'));
      await first;
      await second;
      expect(c.thinking, isFalse);
      expect([for (final m in c.messages) m.fromUser],
          [true, false, true, false]);
      expect(c.messages[2].text, 'قرارداد کتبی دارم');
      expect(c.advocate.file.topic, 'labor');
    });

    test('خطای مدل یا نبودِ حدس گفتگو را نمی‌شکند', () async {
      final c = build((t) => Future.error(StateError('boom')));
      await c.submit(unknown);
      expect(c.messages.length, 2);
      expect(c.advocate.file.topic, isEmpty);
      final d = build((t) async => null);
      await d.submit(unknown);
      expect(d.messages.length, 2);
      expect(d.thinking, isFalse);
    });

    test('اگر در فاصلهٔ خواندن، گفتگو عوض شود جوابِ کهنه نمی‌آید', () async {
      final gate = Completer<TopicGuess?>();
      final c = build((t) => gate.future);
      final pending = c.submit(unknown);
      await Future<void>.delayed(Duration.zero);
      c.newChat();
      gate.complete(sure('labor'));
      await pending;
      expect(c.messages, isEmpty);
      expect(c.advocate.file.topic, isEmpty);
    });
  });

  test('گزارش فهم: قاعده‌ها به‌تنهایی و قاعده‌ها + مدل روی جمله‌های محک', () {
    final reader = TopicReader.fromAssets(
      File('assets/brain/noql.bin').readAsBytesSync(),
      File('assets/brain/noql_vocab.json').readAsStringSync(),
      File('assets/brain/noql_head.json').readAsStringSync(),
    );
    // موضوع وکیل → دستهٔ سنجش.
    final labelOf = <String, String>{};
    guessTopics.forEach((label, ids) {
      for (final id in ids) {
        labelOf[id] = label;
      }
    });
    const noCase = {'crime', 'general', 'chat', 'other'};
    final rows = <List<String>>[];
    for (final line
        in File('eval/understanding_probe.tsv').readAsLinesSync()) {
      if (line.trim().isEmpty || line.startsWith('#')) continue;
      final parts = line.split('\t');
      if (parts.length < 3) continue;
      rows.add([parts[0].trim(), parts[2].trim()]);
    }
    expect(rows.length, greaterThanOrEqualTo(39));

    String judge(Set<String> gold, Advocate a, AdvocateReply r) {
      final topic = a.file.topic;
      if (topic.isNotEmpty) {
        return gold.contains(labelOf[topic] ?? topic) ? 'opened-right' : 'opened-WRONG';
      }
      final offered = [
        for (final t in Advocate.topics)
          if (r.chips.contains(t.title) && r.chips.contains(ChipTexts.noneChip))
            labelOf[t.id] ?? t.id,
      ];
      if (offered.isNotEmpty) {
        return offered.any(gold.contains) ? 'asked-right' : 'asked-wrong';
      }
      return gold.any(noCase.contains) ? 'none-ok' : 'none-missed';
    }

    final out = StringBuffer();
    final tally = <String, Map<String, int>>{'rules': {}, 'model': {}};
    var calls = 0;
    for (final row in rows) {
      final gold = row[0].split('|').toSet();
      final text = row[1];
      final plain = Advocate(engine);
      final a = judge(gold, plain, plain.respond(text));
      final hinted = Advocate(engine);
      TopicGuess? g;
      if (hinted.wantsGuess(text)) {
        g = reader.read(text);
        calls++;
      }
      final b = judge(gold, hinted, hinted.respond(text, guess: g));
      tally['rules']![a] = (tally['rules']![a] ?? 0) + 1;
      tally['model']![b] = (tally['model']![b] ?? 0) + 1;
      out.writeln('${a == b ? ' ' : '*'} ${a.padRight(13)} ${b.padRight(13)} '
          '${(g == null ? '-' : g.toString()).padRight(34)} [${row[0]}] $text');
    }
    final head = StringBuffer()
      ..writeln('Understanding on eval/understanding_probe.tsv '
          '(${rows.length} sentences, first message only)')
      ..writeln('model called for $calls sentences; '
          'open >= ${reader.open} with margin >= ${reader.margin}, '
          'ask >= ${reader.ask}')
      ..writeln('rules only   : ${tally['rules']}')
      ..writeln('rules + model: ${tally['model']}')
      ..writeln('columns: changed? | rules only | rules + model | guess | [gold] sentence')
      ..writeln();
    File('reports/understanding.txt').writeAsStringSync('$head$out');
    // مدل نباید جایی را که قاعده‌ها درست باز کرده بودند خراب کند.
    expect(tally['model']!['opened-right'] ?? 0,
        greaterThanOrEqualTo(tally['rules']!['opened-right'] ?? 0));
  });
}

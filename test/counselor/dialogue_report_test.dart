import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/legal_counselor.dart';
import 'package:dastyar/domain/templates.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;
  const List<LegalTemplate> templates = <LegalTemplate>[];

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  test('dialogue report (prints a table, never fails on content)', () {
    final File f = File('eval/dialogues.txt');
    final List<String> lines = f.readAsLinesSync();
    final List<List<String>> dialogues = <List<String>>[];
    List<String> cur = <String>[];
    for (final String l in lines) {
      if (l.trim().isEmpty) {
        if (cur.isNotEmpty) dialogues.add(cur);
        cur = <String>[];
      } else {
        cur.add(l.trim());
      }
    }
    if (cur.isNotEmpty) dialogues.add(cur);

    final StringBuffer out = StringBuffer();
    out.writeln('DLG-BEGIN');
    int d = 0;
    for (final List<String> msgs in dialogues) {
      d++;
      CounselingSession? session;
      int t = 0;
      for (final String m in msgs) {
        t++;
        String topic;
        String text;
        if (session == null) {
          final started = LegalCounselor.start(
            m,
            engine,
            templates,
            replies: engine.replies,
          );
          if (started == null) {
            out.writeln('D$d.T$t | NO-START | $m');
            continue;
          }
          session = started.$1;
          topic = session.topicId;
          text = started.$2.text;
        } else {
          final CounselorTurn turn = LegalCounselor.step(
            session,
            m,
            engine,
            templates,
            replies: engine.replies,
          );
          topic = session.topicId;
          text = turn.text;
        }
        final String shortText = text.replaceAll('\n', ' ');
        final String cut =
            shortText.length > 70 ? shortText.substring(0, 70) : shortText;
        out.writeln('D$d.T$t | $topic | $m | $cut');
      }
    }
    out.writeln('DLG-END');
    // ignore: avoid_print
    print(out.toString());
    expect(dialogues, isNotEmpty);
  });
}

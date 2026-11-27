import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/advocate/law_terms.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';

/// worker باید همان جواب مسیر همگام بدهد؛ تنها محل اجرا عوض میشود.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('پاسخِ worker با پاسخِ همگام یکی است', () async {
    final engine = KnowledgeEngine();
    await engine.load(startWorker: true);
    addTearDown(engine.dispose);

    const q = 'ماده ۱۰ قانون مدنی دربارهٔ چه چیزی است؟';
    final sync = engine.query(q);
    final prepared = await engine.prepareQuery(q);

    expect(prepared, isNotNull, reason: 'worker پاسخ نداد');
    expect(prepared!.text, isNotEmpty);
    expect(prepared.text, sync.text, reason: ' worker ایندکس متفاوتی دارد');
    expect(
      prepared.contextHits.map((h) => h.chunk.title).toList(),
      sync.contextHits.map((h) => h.chunk.title).toList(),
    );
    expect(prepared.alternatives, sync.alternatives);
    expect(prepared.conflictChains, sync.conflictChains);
  });

  test('تطبیق واژه و پیگیری راهنما با پاسخ آمادهٔ worker هم‌نتیجه با مسیر همگام است',
      () async {
    final engine = KnowledgeEngine();
    await engine.load(startWorker: true);
    addTearDown(engine.dispose);

    const termQ = 'مهلت خیار غبن فاحش در قانون چیست؟';
    final syncTerm = LawTerms(engine).match(termQ);
    final workerTerm = await engine.prepareWith(matchTermsInWorker, termQ);
    expect(workerTerm, isNotNull);
    expect(workerTerm!.accepted, syncTerm.accepted);
    expect(workerTerm.chunk?.title, syncTerm.chunk?.title);
    expect(workerTerm.matched, syncTerm.matched);

    final a1 = Advocate(engine);
    final a2 = Advocate(engine);
    expect(a1.wantsTermMatch(termQ), isTrue);
    final r1 = a1.respond(termQ);
    final r2 = a2.respond(termQ, termMatch: workerTerm);
    expect(r2.text, r1.text);
    expect(r2.source, r1.source);

    // راهنمای باز + پیگیری با guideReply از پیش آماده
    a1.respond('نحوه مطالبه مهریه');
    a2.respond('نحوه مطالبه مهریه');
    const followRaw = 'ماده مهریه کدام است؟';
    final g = a1.dialog.guide;
    expect(g, isNotNull);
    final gQuery = '${g!.title} ${Sense.norm(followRaw)}';
    final gReply = await engine.prepareQuery(gQuery);
    expect(gReply, isNotNull);
    final gf1 = a1.respond(followRaw);
    final gf2 = a2.respond(followRaw, guideQuery: gQuery, guideReply: gReply);
    expect(gf2.text, gf1.text);
    expect(gf2.source, gf1.source);
  });
}

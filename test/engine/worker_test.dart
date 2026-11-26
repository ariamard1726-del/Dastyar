import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';

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
}

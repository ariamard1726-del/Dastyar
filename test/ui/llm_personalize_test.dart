import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/core/llm.dart';
import 'package:dastyar/domain/assistant.dart';
import 'package:dastyar/domain/lawyer/llm_writer.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/ui/chat_controller.dart';
import 'package:dastyar/ui/chat_models.dart';

class FakeLlm extends LlmBackend {
  final String out;
  FakeLlm(this.out);
  @override
  String get name => 'fake';
  @override
  Future<bool> isReady() async => true;
  @override
  Stream<String> generate(String prompt,
          {LlmOptions options = const LlmOptions()}) =>
      Stream.value(out);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;
  late TemplateRepository repo;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    engine = KnowledgeEngine();
    await engine.load();
    repo = TemplateRepository();
    await repo.load();
  });

  ChatController make(String llmOut, {bool enabled = true}) => ChatController(
        engine: engine,
        assistant: Assistant(engine),
        repo: repo,
        history: HistoryStore(),
        settings: AppSettings()
          ..saveHistory = false
          ..saveDraftProgress = false
          ..useLocalLlm = enabled,
        random: Random(1),
        phraseSeed: 1,
        writer: LlmWriter(FakeLlm(llmOut)),
      );

  Future<ChatMessage> say(ChatController c, String t) async {
    await c.submit(t);
    // نوبت دادن به بازنویسی پس‌زمینه.
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return c.messages.lastWhere((m) => !m.fromUser);
  }

  const safe =
      'می‌فهمم که صاحبخانه پول پیش شما را پس نمی‌دهد و این برایتان نگران‌کننده است. با هم قدم‌به‌قدم پیش می‌رویم.';
  const msg = 'صاحبخونه ودیعه منو پس نمیده';

  test('جملهٔ آغازین مدل جایگزین همدلی می‌شود و محتوای حقوقی می‌ماند', () async {
    final base = await say(make(safe, enabled: false), msg);
    final m = await say(make(safe), msg);
    expect(m.text, startsWith(safe));
    // همهٔ مواد و قدم‌های پاسخ قطعی حفظ شده است.
    final legal = base.text.substring(base.text.indexOf('\n\n'));
    expect(m.text, endsWith(legal));
  });

  test('خروجی ناامن مدل نادیده گرفته می‌شود', () async {
    final base = await say(make(safe, enabled: false), msg);
    final m = await say(make('طبق ماده ۴ قانون حق با شماست.'), msg);
    expect(m.text, base.text);
  });

  test('مدل خاموش: پاسخ دست‌نخورده', () async {
    final a = await say(make(safe, enabled: false), msg);
    expect(a.text, isNot(contains(safe)));
  });
}

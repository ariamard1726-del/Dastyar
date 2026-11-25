// ایمنی، مستقل از وکیل آزموده می‌شود.
//
// `SafetyReply` در بخشِ `safety_reply.dart` از کتابخانهٔ `advocate.dart` است؛
// پس همان کتابخانه وارد می‌شود (بخش‌ها را نمی‌شود جدا import کرد).
//
// پیش‌تر تنها راهِ آزمودنِ پاسخِ خشونت این بود که یک `Advocate` کامل با موتور
// بارشده ساخته شود و پیام فرستاده شود؛ حالا خودِ قاعده یک واحد است.
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/reply_voice.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bot = SafetyReply(
    voice: ReplyVoice(
      engine: KnowledgeEngine(),
      file: CaseFile(),
      unresolved: <String>[],
    ),
  );

  String n(String raw) => Sense.norm(raw);

  test('«الان در خطر هستم» فوری‌ترین راه را می‌دهد', () {
    final r = bot.reply(n('الان در خطر هستم'));
    expect(r, isNotNull);
    expect(r!.source, AnswerSource.safety);
    expect(r.text, contains('۱۱۰'));
    expect(bot.asksDanger(n('الان در خطر هستم')), isTrue);
  });

  test('«الان در خطر نیستم» هشدار نیست', () {
    expect(bot.asksDanger(n('الان در خطر نیستم')), isFalse);
  });

  test('خشونت خانوادگی پاسخِ ایمنی می‌گیرد', () {
    final r = bot.reply(n('شوهرم منو میزنه'));
    expect(r, isNotNull);
    expect(r!.text, contains('خشونت'));
    expect(r.chips, isNotEmpty);
  });

  test('تماس با اورژانس تأیید و ادامهٔ راهنمایی می‌گیرد', () {
    final r = bot.reply(n('به پلیس زنگ زدم'));
    expect(r, isNotNull);
    expect(r!.text, contains('زنگ زدید'));
  });

  test('پیامِ حقوقیِ معمولی ایمنی نیست', () {
    expect(bot.reply(n('چکم برگشت خورد و پولم را نمیدهند')), isNull);
    expect(bot.reply(n('قرارداد اجاره‌ام تمام شده')), isNull);
  });
}

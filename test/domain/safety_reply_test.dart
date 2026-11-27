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
import 'package:dastyar/domain/advocate/dialogue_sections.dart';
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
    expect(r.chips, contains('الان امن هستم'));
    expect(bot.asksDanger(n('الان در خطر هستم')), isTrue);
  });

  test('«الان در خطر نیستم» هشدار نیست', () {
    expect(bot.asksDanger(n('الان در خطر نیستم')), isFalse);
  });

  test('خشونت خانوادگی پاسخِ ایمنی می‌گیرد', () {
    final r = bot.reply(n('شوهرم منو میزنه'));
    expect(r, isNotNull);
    expect(r!.chips, contains('الان در خطر هستم'));
    expect(r.chips, isNotEmpty);
  });

  test('تماس با اورژانس تأیید و ادامهٔ راهنمایی می‌گیرد', () {
    final r = bot.reply(n('به پلیس زنگ زدم'));
    expect(r, isNotNull);
    expect(r!.chips, contains('الان امن است'));
  });

  test('خودآسیبی پاسخ فوری میگیرد', () {
    final r = bot.reply(n('دیگه تحمل ندارم، خودمو میکشم'));
    expect(r, isNotNull);
    expect(r!.source, AnswerSource.safety);
    expect(bot.asksSelfHarm(n('نمیخوام زنده بمونم')), isTrue);
    expect(bot.asksSelfHarm(n('قرارداد اجاره تمام شده')), isFalse);
  });

  test('پیامِ حقوقیِ معمولی ایمنی نیست', () {
    expect(bot.reply(n('چکم برگشت خورد و پولم را نمیدهند')), isNull);
    expect(bot.reply(n('قرارداد اجاره‌ام تمام شده')), isNull);
  });

  test('severityOf شدت خطر و acknowledgesSafe اعلام امنیت را تشخیص می‌دهد', () {
    expect(bot.severityOf(n('خودمو میکشم')), SafetySeverity.critical);
    expect(bot.severityOf(n('الان در خطر هستم')), SafetySeverity.critical);
    expect(bot.severityOf(n('شوهرم منو زد')), SafetySeverity.elevated);
    expect(bot.severityOf(n('به پلیس زنگ زدم')), SafetySeverity.elevated);
    expect(bot.severityOf(n('قرارداد اجاره تمام شده')), SafetySeverity.none);

    expect(bot.acknowledgesSafe(n('الان امن است')), isTrue);
    expect(bot.acknowledgesSafe(n('الان امن هستم')), isTrue);
    expect(bot.acknowledgesSafe(n('در خطر نیستم')), isTrue);
    expect(bot.acknowledgesSafe(n('شوهرم منو زد')), isFalse);

    final s = SafetyState()
      ..safetyShown = true
      ..safetySeverity = SafetySeverity.critical
      ..lastSafetyTurn = 4
      ..acknowledgedSafe = false;
    final back = SafetyState.fromJson(s.toJson());
    expect(back.safetySeverity, SafetySeverity.critical);
    expect(back.lastSafetyTurn, 4);
    expect(back.acknowledgedSafe, isFalse);
  });
}

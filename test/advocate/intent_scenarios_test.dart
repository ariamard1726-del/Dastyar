import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';

/// سناریوهای گفتگوی تعاملی برای سنجش تشخیص نیت.
///
/// هر سناریو چند پیام کاربر است؛ پاسخ کامل وکیل (با «ادامه بده»ها) بررسی
/// می‌شود. سناریوهای «سخت» رفتارهایی هستند که از پیش درست کار می‌کنند و
/// شکستشان یعنی رگرسیون. سناریوهای «نرم» هدف‌های تازه‌اند: شکستشان در
/// گزارش دیده می‌شود ولی CI را قرمز نمی‌کند.
///
/// گزارش کامل در `reports/intent_scenarios.md` نوشته می‌شود تا در artifact
/// گردش‌کار «Intent scenarios» دیده شود.
class _Case {
  final String name;
  final List<String> turns;

  /// `null`: بررسی نمی‌شود؛ `''`: باید پرونده‌ای باز نشده باشد؛ وگرنه شناسهٔ موضوع.
  final String? topic;
  final List<String> contains;
  final List<String> notContains;
  final bool hard;

  const _Case(
    this.name,
    this.turns, {
    this.topic,
    this.contains = const [],
    this.notContains = const [],
    this.hard = false,
  });
}

const List<_Case> _cases = [
  // ---- سخت: رفتارهای پایه و رگرسیون
  _Case('سلام', ['سلام'], hard: true, contains: ['سلام']),
  _Case('تشکر', ['ممنون'], hard: true, contains: ['خواهش']),
  _Case('هویت وکیل', ['تو وکیلی؟'],
      hard: true, contains: ['وکیل دادگستری نیستم']),
  _Case('خارج از حوزه', ['هوا چطوره'],
      hard: true, contains: ['حوزهٔ کار من'], notContains: ['گفتید']),
  _Case('توانایی‌های برنامه', ['چه کارهایی می‌توانی انجام بدهی؟'],
      hard: true, topic: '', contains: ['وکیل'], notContains: ['گفتید']),
  _Case('وکیل کجا؟', ['وکیل کجا پیدا کنم؟'],
      hard: true, contains: ['کانون وکلای دادگستری']),
  _Case('مهلت بدون پرونده', ['مهلت شکایت چقدره؟'],
      hard: true, topic: '', contains: ['ابلاغ']),
  _Case('طلب', ['طلب دارم'], hard: true, topic: 'debt'),
  _Case('چک برگشتی', ['چکم برگشت خورده'], hard: true, topic: 'cheque'),
  _Case('ودیعه اجاره', ['صاحبخونه پول پیشمو نمیده'],
      hard: true, topic: 'rent', contains: ['قانون روابط موجر و مستأجر']),
  _Case('هزینه وکیل وسط پرونده', ['طلب دارم', 'هزینه وکیل چقدره؟'],
      hard: true, topic: 'debt', contains: ['کانون وکلای دادگستری']),

  // ---- نرم: هدف‌های تشخیص نیت (گزارش می‌شوند)
  _Case('حقوق معوقه', ['کارفرما دو ماهه حقوقمو نداده'], topic: 'labor'),
  _Case('همسایه و دیوار', ['همسایه دیوار منو خراب کرده'], topic: 'neighbor'),
  _Case('کلاهبرداری اینترنتی', ['از من کلاهبرداری اینترنتی شده'],
      topic: 'cyber'),
  _Case('پول قرض‌داده', ['پولم رو به دوستم قرض دادم پس نمیده'],
      topic: 'debt'),
  _Case('ضامن بانک', ['ضامن شدم حالا بانک سراغم اومده'],
      topic: 'guarantee'),
  _Case('شریک و پول شرکت', ['شریکم پول شرکت را برداشته'], topic: 'partner'),
  _Case('ارث پدر', ['پدرم فوت کرد و می‌خواهم سهم الارثم را بگیرم'],
      topic: 'inherit'),
  _Case('اجارهٔ بدون قرارداد', ['اجاره‌نامه رو امضا نکرده‌ایم ولی ملک را گرفتم'],
      topic: 'rent'),
  _Case('مهریه', ['شوهرم مهریه‌ام را نمیده'], topic: 'family'),
  _Case('تصادف و خسارت', ['ماشینم رو یه نفر زد و فرار کرد'],
      topic: 'injury'),
  _Case('احضاریه', ['احضاریه برام اومده، چیکار کنم؟'],
      notContains: ['گفتید']),
  _Case('تهدید', ['یکی تهدیدم کرده که اذیتم کنه'], notContains: ['گفتید']),
  _Case('پرسش بدون موضوع', ['یه سؤال حقوقی دارم'], notContains: ['گفتید']),
  _Case('شکایت از کارفرما بعد از اخراج',
      ['بدون دلیل اخراج شدم', 'بیمه‌ام هم ندادن'], topic: 'labor'),
  _Case('تغییر موضوع وسط گفتگو',
      ['صاحبخونه پول پیشمو نمیده', 'راستی یه چک هم برگشت خورده'],
      hard: true, topic: 'cheque'),
];

/// پاسخ کامل: همهٔ «ادامه بده»ها کنار هم.
AdvocateReply _full(Advocate a, String t) {
  final r = a.respond(t);
  final sb = StringBuffer(r.text);
  var guard = 0;
  while (a.hasMore && guard < 8) {
    guard++;
    sb.write('\n${a.respond(Advocate.moreChip).text}');
  }
  return AdvocateReply(sb.toString(), chips: r.chips, laws: r.laws);
}

String _short(String s, [int n = 260]) {
  final one = s.replaceAll('\n', ' ⏎ ');
  return one.length <= n ? one : '${one.substring(0, n)}…';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  Advocate fresh() => Advocate(engine, draftTitles: const {
        'demand_money': 'دادخواست مطالبه وجه',
        'defense_brief': 'لایحه دفاعیه',
      });

  test('سناریوهای گفتگو', () {
    final rows = <String>[];
    final details = <String>[];
    final hardFails = <String>[];
    var passed = 0;

    for (final c in _cases) {
      final a = fresh();
      final transcript = <String>[];
      var last = '';
      for (final t in c.turns) {
        final r = _full(a, t);
        last = r.text;
        transcript.add('- **کاربر:** $t');
        transcript.add('- **وکیل:** ${_short(r.text)}');
      }
      final reasons = <String>[];
      if (c.topic != null && a.file.topic != c.topic) {
        reasons.add('موضوع «${a.file.topic}» به‌جای «${c.topic}»');
      }
      for (final s in c.contains) {
        if (!last.contains(s)) reasons.add('پاسخ شامل «$s» نیست');
      }
      for (final s in c.notContains) {
        if (last.contains(s)) reasons.add('پاسخ نباید «$s» داشته باشد');
      }
      final ok = reasons.isEmpty;
      if (ok) passed++;
      rows.add('| ${c.name} | ${c.hard ? 'سخت' : 'نرم'} | '
          '${ok ? 'درست' : 'نادرست'} | ${a.file.topic.isEmpty ? '—' : a.file.topic} | '
          '${reasons.isEmpty ? '' : reasons.join('؛')} |');
      details.add('### ${c.name} (${ok ? 'درست' : 'نادرست'})');
      details.addAll(transcript);
      details.add('');
      if (!ok && c.hard) {
        hardFails.add('${c.name}: ${reasons.join('؛')}');
      }
    }

    // ---- بررسی QA: هر پرسش بانک که به پاسخ QA می‌رسد باید همان پاسخ را
    // با استناد و دکمه‌های هم‌موضوع بدهد.
    final qaRouted = <String>[];
    final qaNotRouted = <String>[];
    final qaProblems = <String>[];
    for (final it in engine.qa.items) {
      final a = fresh();
      final r = a.respond(it.question);
      final head = it.answer.length > 30 ? it.answer.substring(0, 30) : it.answer;
      if (r.text.contains(head)) {
        qaRouted.add(it.id);
        if (!r.text.contains('مستند:')) {
          qaProblems.add('${it.id}: استناد «مستند» ندارد');
        }
        if (r.chips.isEmpty) {
          qaProblems.add('${it.id}: دکمه‌های هم‌موضوع ندارد');
        }
      } else {
        qaNotRouted.add('${it.id} (${a.file.topic.isEmpty ? 'بدون موضوع' : a.file.topic})');
      }
    }

    final report = StringBuffer()
      ..writeln('# گزارش سناریوهای تشخیص نیت')
      ..writeln()
      ..writeln('نتیجه: ${passed.toString()} از ${_cases.length} سناریو درست است.')
      ..writeln()
      ..writeln('| سناریو | نوع | نتیجه | موضوع | دلیل |')
      ..writeln('|---|---|---|---|---|')
      ..writeln(rows.join('\n'))
      ..writeln()
      ..writeln('## بررسی پاسخ QA')
      ..writeln()
      ..writeln('- پرسش‌های بانک: ${engine.qa.items.length}')
      ..writeln('- رسیده به پاسخ QA: ${qaRouted.length}')
      ..writeln('- رسیده به موضوع یا جای دیگر: ${qaNotRouted.length}')
      ..writeln('- مشکلات پاسخ QA: ${qaProblems.isEmpty ? 'ندارد' : qaProblems.join('؛ ')}')
      ..writeln()
      ..writeln('شناسه‌های رسیده به QA: ${qaRouted.join('، ')}')
      ..writeln()
      ..writeln('## گفتگوها')
      ..writeln()
      ..writeln(details.join('\n'));
    Directory('reports').createSync(recursive: true);
    File('reports/intent_scenarios.md').writeAsStringSync(report.toString());

    expect(hardFails, isEmpty, reason: hardFails.join('\n'));
  });

  test('پرسش بانک QA به پاسخ و استناد و دکمه‌های مرتبط می‌رسد', () {
    // گرفتن یک پرسش که واقعاً به مسیر QA می‌رسد. اگر هیچ‌کدام نرسد، یعنی
    // مسیر QA در عمل بی‌استفاده است و باید دیده شود.
    final routed = <QaItemRoute>[];
    for (final it in engine.qa.items) {
      final a = fresh();
      final r = a.respond(it.question);
      final head = it.answer.length > 30 ? it.answer.substring(0, 30) : it.answer;
      if (r.text.contains(head)) {
        routed.add(QaItemRoute(it.id, r));
      }
    }
    expect(routed, isNotEmpty,
        reason: 'هیچ پرسش بانک به مسیر QA نمی‌رسد؛ مسیر QA بی‌استفاده است.');
    for (final x in routed) {
      expect(x.reply.text, contains('مستند:'), reason: x.id);
      expect(x.reply.chips, isNotEmpty, reason: x.id);
    }
  });
}

class QaItemRoute {
  final String id;
  final AdvocateReply reply;
  QaItemRoute(this.id, this.reply);
}

"""تولید مستند و آزمون ماتریس اولویت از `dev/tools/contracts/priority.json`.

چرا: اولویتِ ۲۰ کاندید خطِ تولیدِ پاسخ دیگر نباید ضمنی و وابسته به خواندن
ترتیبِ کد باشد؛ هر جفتِ ممکنِ کاندیدها (۱۹۰ جفت) در قرارداد نام دارد،
دلیلش ثبت شده و هر جفتِ هم‌پوشان با فراخوانی واقعی `Advocate.respond`
در آزمونِ تولیدشده آزموده می‌شود.

اجرا:
  python3 dev/tools/gen_priority.py --check
  python3 dev/tools/gen_priority.py --write
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from library import read as lib_read  # noqa: E402

CONTRACT = os.path.join(ROOT, 'dev', 'tools', 'contracts', 'priority.json')
DOC_OUT = os.path.join(ROOT, 'docs', 'PRIORITY.md')
TEST_OUT = os.path.join(ROOT, 'test', 'advocate', 'priority_matrix_test.dart')

FA_DIGITS = str.maketrans('0123456789', '۰۱۲۳۴۵۶۷۸۹')

DOC_HEADER = '''<!-- تولیدشده از dev/tools/contracts/priority.json — دستی ویرایش نکنید. -->
<!-- تولید دوباره: python3 dev/tools/gen_priority.py --write -->
<!-- بررسی تازگی:  python3 dev/tools/gen_priority.py --check -->
'''

DART_HEADER = '''// تولیدشده از dev/tools/contracts/priority.json — دستی ویرایش نکنید.
// تولید دوباره: python3 dev/tools/gen_priority.py --write
// بررسی تازگی:  python3 dev/tools/gen_priority.py --check
'''


def _fa(n):
    return str(n).translate(FA_DIGITS)


def load(path=CONTRACT):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def pipeline_candidates():
    src = lib_read(ROOT, os.path.join('lib', 'domain', 'advocate', 'advocate_reply.dart'))
    return re.findall(r"AnswerCandidate\(\s*'([^']+)'", src)


def validate(c):
    errors = []
    if c.get('version') != 1:
        errors.append('نسخهٔ قرارداد باید ۱ باشد')
    cands = c.get('candidates') or []
    names = [x.get('name') for x in cands]
    live = pipeline_candidates()
    if names != live:
        errors.append('فهرست کاندیدها با advocate_reply.dart هم‌خوان نیست: %r != %r'
                      % (names, live))
    for idx, item in enumerate(cands):
        if item.get('index') != idx:
            errors.append('ردیف کاندید نادرست در خانهٔ %d' % idx)
        for k in ('name', 'stage', 'source', 'precondition'):
            if not str(item.get(k, '')).strip():
                errors.append('کاندید %d فیلدِ خالی دارد: %s' % (idx, k))

    setups = c.get('setups') or {}
    if not setups:
        errors.append('بخش setups خالی است')
    for sname, sdata in setups.items():
        turns = sdata.get('turns')
        if not isinstance(turns, list):
            errors.append('turns در %s فهرست نیست' % sname)
            continue
        for t in turns:
            if not isinstance(t, dict) or not str(t.get('raw', '')).strip():
                errors.append('نوبت نامعتبر در setup %s' % sname)

    pairs = c.get('pairs') or []
    want_pairs = [(i, j) for i in range(len(cands)) for j in range(i + 1, len(cands))]
    got_pairs = [(p.get('winner_index'), p.get('loser_index')) for p in pairs]
    if got_pairs != want_pairs:
        errors.append('جفت‌های اعلام‌شده با %s جفتِ ممکن یکی نیست (تعداد=%d)' %
                      (_fa(len(want_pairs)), len(pairs)))
        return errors

    for p in pairs:
        i = p['winner_index']
        j = p['loser_index']
        if p.get('winner') != names[i] or p.get('loser') != names[j]:
            errors.append('نام کاندید در جفت (%d, %d) با جدول کاندیدها نمی‌خواند' % (i, j))
        status = p.get('status')
        if status not in ('overlap', 'disjoint'):
            errors.append('وضعیت نامعتبر در (%d, %d): %r' % (i, j, status))
            continue
        if not str(p.get('why', '')).strip():
            errors.append('دلیل خالی در (%d, %d)' % (i, j))
        if status == 'overlap':
            if p.get('setup') not in setups:
                errors.append('setup ناشناخته در (%d, %d): %r' % (i, j, p.get('setup')))
            if p.get('loser_setup') not in setups:
                errors.append('loser_setup ناشناخته در (%d, %d): %r' % (i, j, p.get('loser_setup')))
            for k in ('loser_input', 'compound_input'):
                if not str(p.get(k, '')).strip():
                    errors.append('فیلد %s خالی است در (%d, %d)' % (k, i, j))
            if 'prime_input' in p and not str(p['prime_input']).strip():
                errors.append('prime_input خالی در (%d, %d)' % (i, j))
        else:
            if not str(p.get('reason_code', '')).strip():
                errors.append('reason_code خالی در (%d, %d)' % (i, j))
    return errors


def _md_cell(text):
    return str(text).replace('|', '\\|').replace('\n', ' ').strip()


def _dart_str(s):
    escaped = (str(s)
               .replace('\\', '\\\\')
               .replace("'", "\\'")
               .replace('$', '\\$')
               .replace('\r', '')
               .replace('\n', '\\n'))
    return "'%s'" % escaped


def render_doc(c):
    cands = c['candidates']
    pairs = c['pairs']
    overlaps = [p for p in pairs if p['status'] == 'overlap']
    disjoints = [p for p in pairs if p['status'] == 'disjoint']
    by_pair = {(p['winner_index'], p['loser_index']): p for p in pairs}

    lines = [
        DOC_HEADER,
        '# ماتریس اولویتِ کاندیدهای پاسخ',
        '',
        'این سند از `dev/tools/contracts/priority.json` تولید می‌شود و اولویتِ صریحِ همهٔ',
        '**%s کاندیدِ** خط تولیدِ پاسخ (`lib/domain/advocate/advocate_reply.dart`) را در کلِ',
        '**%s جفتِ ممکن** ثبت می‌کند: **%s جفتِ هم‌پوشان** (هر دو کاندید می‌توانند روی یک پیام و وضعیت فعال شوند و برندهٔ اعلام‌شده آزمایش می‌شود) و **%s جفتِ جداگانه** (بر اساس پیش‌شرط‌های کد هرگز هم‌زمان فعال نمی‌شوند).',
        '',
        'برای بازتولید یا بررسی تازگی:',
        '',
        '```',
        'python3 dev/tools/gen_priority.py --check',
        'python3 dev/tools/check.py priority',
        '```',
        '',
        '## ۱. فهرستِ %s کاندید به ترتیب داوری' % _fa(len(cands)),
        '',
        '| ردیف | کاندید | مرحلهٔ داوری | منبع (`AnswerSource`) | پیش‌شرط فعال‌شدن |',
        '|---|---|---|---|---|',
    ]
    lines[4] = lines[4] % _fa(len(cands))
    lines[5] = lines[5] % (_fa(len(pairs)), _fa(len(overlaps)), _fa(len(disjoints)))

    for item in cands:
        lines.append('| %s | %s | `%s` | `%s` | %s |' % (
            _fa(item['index']),
            _md_cell(item['name']),
            _md_cell(item['stage']),
            _md_cell(item['source']),
            _md_cell(item['precondition']),
        ))

    lines.extend([
        '',
        '## ۲. ماتریسِ %s×%s جفت‌به‌جفت' % (_fa(len(cands)), _fa(len(cands))),
        '',
        'نمادها: `>` ردیف بر ستون برتری دارد (هم‌پوشان، آزموده در Dart) · `<` ستون بر ردیف برتری دارد · `—` جداگانه (هم‌زمان فعال نمی‌شوند) · `·` قطر اصلی.',
        '',
    ])
    header = '| # | ' + ' | '.join(_fa(j) for j in range(len(cands))) + ' |'
    sep = '|---|' + '|'.join('---' for _ in range(len(cands))) + '|'
    lines.extend([header, sep])
    for i in range(len(cands)):
        cells = [_fa(i)]
        for j in range(len(cands)):
            if i == j:
                cells.append('·')
            elif i < j:
                cells.append('>' if by_pair[(i, j)]['status'] == 'overlap' else '—')
            else:
                cells.append('<' if by_pair[(j, i)]['status'] == 'overlap' else '—')
        lines.append('| ' + ' | '.join(cells) + ' |')

    lines.extend([
        '',
        '## ۳. جفت‌های هم‌پوشان (%s جفت)' % _fa(len(overlaps)),
        '',
        '| جفت | برنده | بازنده | حالت شروع | ورودی بازنده | ورودی مرکب | دلیلِ اولویت |',
        '|---|---|---|---|---|---|---|',
    ])
    for p in overlaps:
        pair_label = '`(%s, %s)`' % (_fa(p['winner_index']), _fa(p['loser_index']))
        lines.append('| %s | %s | %s | `%s` | `%s` | `%s` | %s |' % (
            pair_label,
            _md_cell(p['winner']),
            _md_cell(p['loser']),
            _md_cell(p['setup']),
            _md_cell(p['loser_input']),
            _md_cell(p['compound_input']),
            _md_cell(p['why']),
        ))

    lines.extend([
        '',
        '## ۴. جفت‌های جداگانه (%s جفت)' % _fa(len(disjoints)),
        '',
        '| جفت | کاندیدِ نخست | کاندیدِ دوم | کدِ اثبات | چرا هم‌زمان رخ نمی‌دهند |',
        '|---|---|---|---|---|',
    ])
    for p in disjoints:
        pair_label = '`(%s, %s)`' % (_fa(p['winner_index']), _fa(p['loser_index']))
        lines.append('| %s | %s | %s | `%s` | %s |' % (
            pair_label,
            _md_cell(p['winner']),
            _md_cell(p['loser']),
            _md_cell(p['reason_code']),
            _md_cell(p['why']),
        ))

    lines.append('')
    return '\n'.join(lines)


def render_dart(c):
    setups = c['setups']
    pairs = c['pairs']
    overlaps = [p for p in pairs if p['status'] == 'overlap']
    disjoints = [p for p in pairs if p['status'] == 'disjoint']

    out = [
        DART_HEADER,
        "import 'package:dastyar/core/engine.dart';",
        "import 'package:dastyar/domain/advocate/advocate.dart';",
        "import 'package:dastyar/domain/advocate/case_file.dart';",
        "import 'package:dastyar/domain/advocate/text_sense.dart';",
        "import 'package:dastyar/domain/advocate/topics/rent_texts_loader.dart';",
        "import 'package:dastyar/domain/advocate/understanding.dart';",
        "import 'package:dastyar/domain/draft_words.dart';",
        "import 'package:dastyar/domain/understanding/topic_guess.dart';",
        "import 'package:flutter_test/flutter_test.dart';",
        '',
        '/// آزمونِ ماتریس اولویتِ %s کاندید (%s جفت: %s هم‌پوشان + %s جداگانه).' % (
            _fa(len(c['candidates'])), _fa(len(pairs)), _fa(len(overlaps)), _fa(len(disjoints))),
        '///',
        '/// تمام نوبت‌های پیش‌شرط با فراخوانی واقعی `Advocate.respond` ساخته می‌شوند،',
        '/// نه با دست‌کاریِ وضعیت داخلی؛ هر تغییر در ترتیب یا پیش‌شرط کاندیدها',
        '/// بی‌درنگ جفتِ متناظر را قرمز می‌کند.',
        'void main() {',
        '  TestWidgetsFlutterBinding.ensureInitialized();',
        '  late KnowledgeEngine engine;',
        '',
        '  setUpAll(() async {',
        '    engine = KnowledgeEngine();',
        '    await engine.load();',
        '  });',
        '',
        '  Advocate fresh() => Advocate(engine, draftTitles: const {',
        "        'demand_money': 'دادخواست مطالبه وجه',",
        "        'defense_brief': 'لایحه دفاعیه',",
        '      });',
        '',
        '  Advocate buildSetup(String id) {',
        '    final a = fresh();',
        '    switch (id) {',
    ]

    for sname in sorted(setups):
        turns = setups[sname]['turns']
        out.append('      case %s:' % _dart_str(sname))
        for t in turns:
            raw = _dart_str(t['raw'])
            guess = t.get('guess')
            if guess:
                out.append(
                    '        a.respond(%s, guess: const TopicGuess(%s, 0.9, %s, 0, confident: true, plausible: true));'
                    % (raw, _dart_str(guess), _dart_str(''))
                )
            else:
                out.append('        a.respond(%s);' % raw)
        out.append('        return a;')

    out.extend([
        '      default:',
        "        throw ArgumentError('Unknown setup: $id');",
        '    }',
        '  }',
        '',
        "  group('پیش‌شرط وضعیت‌های گفتگوی واقعی (۱۷ حالت)', () {",
        "    test('حالت‌های پایه، پرونده، حدس، ادامه، پیشنهاد، موضوع کناری و سند آماده‌اند', () {",
        "      final idle = buildSetup('idle');",
        '      expect(idle.hasCase, isFalse);',
        '      expect(idle.dialog.loose, isEmpty);',
        '',
        "      final asked = buildSetup('asked');",
        '      expect(asked.hasCase, isFalse);',
        '      expect(asked.dialog.branchAsked, isTrue);',
        '',
        "      final choices = buildSetup('choices');",
        '      expect(choices.hasCase, isFalse);',
        '      expect(choices.dialog.choices, isNotEmpty);',
        '',
        "      final idleRest = buildSetup('idle_rest');",
        '      expect(idleRest.hasCase, isFalse);',
        '      expect(idleRest.hasMore, isTrue);',
        '',
        "      final openRent = buildSetup('open_rent');",
        "      expect(openRent.file.topic, 'rent');",
        '      expect(openRent.file.pending, isEmpty);',
        '      expect(openRent.dialog.offer, isEmpty);',
        '      expect(openRent.hasMore, isFalse);',
        '      expect(openRent.dialog.side, isNull);',
        '',
        "      final openPending = buildSetup('open_pending');",
        "      expect(openPending.file.topic, 'rent');",
        '      expect(openPending.dialog.pendingTopic, isNotNull);',
        '      expect(openPending.file.pending, isEmpty);',
        '      expect(openPending.dialog.offer, isEmpty);',
        '      expect(openPending.hasMore, isFalse);',
        '',
        "      final openGuessed = buildSetup('open_guessed');",
        "      expect(openGuessed.file.topic, 'labor');",
        '      expect(openGuessed.dialog.guessed, isTrue);',
        '      expect(openGuessed.hasMore, isFalse);',
        '',
        "      final openGuessedRepeat = buildSetup('open_guessed_repeat');",
        "      expect(openGuessedRepeat.file.topic, 'labor');",
        '      expect(openGuessedRepeat.dialog.guessed, isTrue);',
        '',
        "      final openRest = buildSetup('open_rest');",
        "      expect(openRest.file.topic, 'foreign_contract');",
        '      expect(openRest.hasMore, isTrue);',
        '      expect(openRest.dialog.offer, isEmpty);',
        '',
        "      final openOffer = buildSetup('open_offer');",
        "      expect(openOffer.file.topic, 'foreign_contract');",
        '      expect(openOffer.dialog.offer, isNotEmpty);',
        '      expect(openOffer.hasMore, isFalse);',
        '',
        "      final openRestOffer = buildSetup('open_rest_offer');",
        "      expect(openRestOffer.file.topic, 'foreign_contract');",
        '      expect(openRestOffer.hasMore, isTrue);',
        '      expect(openRestOffer.dialog.offer, isNotEmpty);',
        '',
        "      final openGuessedRestOffer = buildSetup('open_guessed_rest_offer');",
        "      expect(openGuessedRestOffer.file.topic, 'admin');",
        '      expect(openGuessedRestOffer.dialog.guessed, isTrue);',
        '      expect(openGuessedRestOffer.hasMore, isTrue);',
        '      expect(openGuessedRestOffer.dialog.offer, isNotEmpty);',
        '',
        "      final openSide = buildSetup('open_side');",
        "      expect(openSide.file.topic, 'rent');",
        '      expect(openSide.dialog.side, isNotNull);',
        '      expect(openSide.hasMore, isFalse);',
        '',
        "      final openPendRest = buildSetup('open_pend_rest');",
        "      expect(openPendRest.file.topic, 'rent');",
        '      expect(openPendRest.dialog.pendingTopic, isNotNull);',
        '      expect(openPendRest.hasMore, isTrue);',
        '',
        "      final openPendOffer = buildSetup('open_pend_offer');",
        "      expect(openPendOffer.file.topic, 'foreign_contract');",
        '      expect(openPendOffer.dialog.pendingTopic, isNotNull);',
        '      expect(openPendOffer.dialog.offer, isNotEmpty);',
        '',
        "      final openPendSide = buildSetup('open_pend_side');",
        "      expect(openPendSide.file.topic, 'rent');",
        '      expect(openPendSide.dialog.pendingTopic, isNotNull);',
        '      expect(openPendSide.dialog.side, isNotNull);',
        '',
        "      final openFiling = buildSetup('open_rent_filing14');",
        "      expect(openFiling.file.topic, 'rent');",
        '      expect(',
        '        openFiling.filings.any(',
        "          (g) => Sense.norm(g.chip) == Sense.norm('تنظیم لایحهٔ دفاع در برابر ادعای خسارت'),",
        '        ),',
        '        isTrue,',
        '      );',
        '    });',
        '  });',
        '',
        "  group('ماتریس جفت‌های هم‌پوشان (%s جفت)' , () {" % _fa(len(overlaps)),
    ])

    for p in overlaps:
        w = p['winner_index']
        l = p['loser_index']
        wname = p['winner']
        lname = p['loser']
        setup = p['setup']
        lsetup = p['loser_setup']
        lraw = p['loser_input']
        craw = p['compound_input']
        prime = p.get('prime_input')

        title = '(%s, %s) %s > %s' % (_fa(w), _fa(l), wname, lname)
        out.append('    test(%s, () {' % _dart_str(title))
        out.append('      final loser = buildSetup(%s);' % _dart_str(lsetup))
        if lname == 'تکرارِ حرفِ قبلی':
            out.append('      loser.respond(%s);' % _dart_str(lraw))
        out.append('      loser.respond(%s);' % _dart_str(lraw))
        out.append('      expect(loser.lastDecision?.candidate.name, %s,' % _dart_str(lname))
        out.append('          reason: %s);' % _dart_str('پایهٔ بازنده در (%d, %d)' % (w, l)))
        out.append('')
        out.append('      final winner = buildSetup(%s);' % _dart_str(setup))
        if prime:
            out.append('      winner.respond(%s);' % _dart_str(prime))
        out.append('      winner.respond(%s);' % _dart_str(craw))
        out.append('      expect(winner.lastDecision?.candidate.name, %s,' % _dart_str(wname))
        out.append('          reason: %s);' % _dart_str('ترکیب برنده در (%d, %d)' % (w, l)))
        out.append('    });')

    out.extend([
        '  });',
        '',
        "  group('ناهم‌پوشانی جفت‌های جداگانه (%s جفت)', () {" % _fa(len(disjoints)),
        "    test('همهٔ ۲۴ موضوع follow[next] دارند پس (۱۰, ۱۴) در عمل جداست', () {",
        '      for (final Topic t in Advocate.topics) {',
        "        expect(t.follow.containsKey('next'), isTrue, reason: t.id);",
        '      }',
        '    });',
        '',
        "    test('عنوان موضوع‌ها حداکثر ۷ واژه است پس انتخاب موضوع (۹) از تکرار (۱۸) جداست', () {",
        '      for (final Topic t in Advocate.topics) {',
        '        expect(Sense.words(Sense.norm(t.title)), lessThanOrEqualTo(7),',
        '            reason: t.title);',
        '      }',
        '    });',
        '',
        "    test('برچسب‌های تنظیم سند کوتاه‌اند و با کلیدواژهٔ مسیرهای دیگر تداخل ندارند', () {",
        '      for (var i = 0; i < 16; i++) {',
        "        final chip = rentText('filing${i}_chip');",
        "        expect(chip, isNotEmpty, reason: 'filing$i');",
        '        final n = Sense.norm(chip);',
        '        expect(Sense.words(n), lessThanOrEqualTo(7), reason: chip);',
        '        expect(DraftWords.isLeave(chip), isFalse, reason: chip);',
        '        expect(DraftWords.isComplaintNoOption(chip), isFalse, reason: chip);',
        "        expect(Sense.has(n, 'پرسش|خودکش|تاریخچه|چت قبلی|دعوام|مهلت|طلاق|غبن|قهر|برنامه|ربات'),",
        '            isFalse, reason: chip);',
        '      }',
        '    });',
        '',
        "    test('واژه‌شمار دکمه‌های شاخه و انصراف با (۱, ۴) و (۱۸) و (۱۶) هم‌خوان است', () {",
        '      for (final c in ChipTexts.branchChips) {',
        '        expect(Sense.words(Sense.norm(c)), lessThanOrEqualTo(1), reason: c);',
        '      }',
        "      expect(DraftWords.isLeave('گزینه‌ای وجود ندارد'), isFalse);",
        "      expect(Understanding.isRepeat('سلام', 'سلام'), isFalse);",
        '    });',
        '  });',
        '}',
        '',
    ])
    return '\n'.join(out)


def targets(c=None):
    if c is None:
        c = load()
    return {
        DOC_OUT: render_doc(c),
        TEST_OUT: render_dart(c),
    }


def main(argv):
    check = '--check' in argv
    write = '--write' in argv or not check
    c = load()
    errs = validate(c)
    if errs:
        for e in errs:
            print('خطا در قرارداد اولویت: %s' % e)
        return 1

    bad = []
    for path, text in targets(c).items():
        old = None
        if os.path.exists(path):
            with open(path, encoding='utf-8') as f:
                old = f.read()
        if old == text:
            if check:
                print('تازه است: %s' % os.path.relpath(path, ROOT))
            continue
        if check:
            bad.append(path)
            print('کهنه است: %s — python3 dev/tools/gen_priority.py --write' %
                  os.path.relpath(path, ROOT))
        elif write:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(text)
            print('نوشته شد: %s' % os.path.relpath(path, ROOT))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

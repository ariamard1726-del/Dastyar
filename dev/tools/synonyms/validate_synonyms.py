from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lawtext  # noqa: E402

DIACRITICS = re.compile('[\u064b-\u0652]')


def clean(s):
    return DIACRITICS.sub('', lawtext.norm(s))


def main():
    parts = []
    for p in lawtext.law_files().values():
        with open(p, encoding='utf-8') as f:
            parts.append(clean(f.read()))
    text = '\n'.join(parts)

    ok = bad = 0
    with open(sys.argv[1], encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#') or '|' not in line:
                continue
            left, right = [x.strip() for x in line.split('|', 1)]
            miss = [w for w in clean(right).split() if w not in text]
            if miss:
                bad += 1
                print('REJECT', left, '| missing:', ' '.join(miss))
            else:
                ok += 1
    print('ok', ok, 'rejected', bad)


if __name__ == '__main__':
    main()

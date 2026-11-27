import collections
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lawtext  # noqa: E402

WORD = re.compile(r'[\u0600-\u06FF]{3,}')


def main():
    files = lawtext.law_files()
    cnt = {}
    for lid, p in files.items():
        with open(p, encoding='utf-8') as f:
            cnt[lid] = collections.Counter(WORD.findall(lawtext.norm(f.read())))
    df = collections.Counter()
    for c in cnt.values():
        for w in c:
            df[w] += 1
    for lid in sys.argv[1:]:
        words = [(w, n) for w, n in cnt[lid].items() if n >= 3 and df[w] <= 3]
        words.sort(key=lambda x: -x[1])
        print(lid, ':', ' '.join(w for w, _ in words[:60]))
        print()


if __name__ == '__main__':
    main()

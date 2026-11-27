import collections
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lawtext  # noqa: E402

WORD = re.compile(r'[\u0600-\u06FF]{3,}')
ROOT = lawtext.ROOT


def main():
    meta = lawtext.load_meta()
    files = lawtext.law_files(meta)

    syn_lines = []
    with open(ROOT / 'assets' / 'synonyms.txt', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '|' in line:
                syn_lines.append(lawtext.norm(line))

    law_words = {}
    law_articles = {}
    for lid in meta:
        p = files.get(lid)
        if not p or not p.exists():
            law_words[lid] = None
            law_articles[lid] = 0
            continue
        with open(p, encoding='utf-8') as f:
            txt = f.read()
        law_articles[lid] = sum(1 for first, _, _ in lawtext.parse(txt) if lawtext.is_article(first))
        law_words[lid] = collections.Counter(WORD.findall(lawtext.norm(txt)))

    df = collections.Counter()
    for c in law_words.values():
        if c:
            for w in c:
                df[w] += 1

    lines = [
        '# Coverage report (auto-generated, read-only analysis)\n',
        '| law | title | articles(meta) | articles(found) | synonym rows touching law |',
        '|---|---|---|---|---|',
    ]
    for lid, m in meta.items():
        c = law_words[lid]
        if c is None:
            lines.append(f"| {lid} | {m['title']} | {m['articles']} | FILE MISSING | - |")
            continue
        distinct = {w for w, n in c.items() if n >= 3 and df[w] <= 2}
        touching = sum(
            1 for s in syn_lines
            if any(w in distinct for w in WORD.findall(s.split('|', 1)[1]))
        )
        flag = '' if law_articles[lid] else ' NO ARTICLES PARSED'
        lines.append(f"| {lid} | {m['title']} | {m['articles']} | {law_articles[lid]}{flag} | {touching} |")

    with open(ROOT / 'docs' / 'coverage_report.md', 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')
    print('\n'.join(lines))
    print('\nsynonym rows:', len(syn_lines))


if __name__ == '__main__':
    main()

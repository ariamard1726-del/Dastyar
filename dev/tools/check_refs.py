"""بررسی ارجاع‌های استنادی: هر `[[کلید:شماره]]` در کد یا دارایی‌های متنی
باید به ماده‌ای واقعی در فایل قانونِ همان کلید (`assets/laws/_meta.json`)
اشاره کند.

اجرا:  python dev/tools/check_refs.py          (خروجی ۰ = همه درست)
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    from . import lawtext
except ImportError:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import lawtext  # noqa: E402

ROOT = lawtext.ROOT
REF = re.compile(r"\[\[([a-z_0-9]+):([0-9]+)(m?)\]\]")

TEXT_JSON_ASSETS = (
    "assets/brain/advocate_texts.json",
    "assets/brain/topic_texts.json",
    "assets/brain/topics/rent_texts.json",
)


def law_files() -> dict[str, Path]:
    return lawtext.law_files()


def article_exists(text: str, num: str, word: str = "ماده") -> bool:
    # ماده‌ها در متن قانون به شکل «ماده 35» یا «ماده ۳۵» در ابتدای سطر می‌آیند.
    # قانون اساسی به‌جای «ماده»، «اصل» دارد.
    pat = re.compile(
        r"^\s*%s\s*(?:%s|%s)\s*$"
        % (word, re.escape(num), re.escape(lawtext.to_fa(num))),
        re.MULTILINE,
    )
    return bool(pat.search(text))


def collect_refs() -> dict[tuple[str, str], list[str]]:
    found: dict[tuple[str, str], list[str]] = {}
    paths = list((ROOT / "lib").rglob("*.dart"))
    for rel in TEXT_JSON_ASSETS:
        p = ROOT / rel
        if p.exists():
            paths.append(p)
    for path in paths:
        for m in REF.finditer(path.read_text(encoding="utf-8")):
            num = m.group(2) + (" مکرر" if m.group(3) else "")
            found.setdefault((m.group(1), num), []).append(str(path.relative_to(ROOT)))
    return found


def main() -> int:
    files = law_files()
    texts: dict[str, str] = {}
    problems: list[str] = []
    refs = collect_refs()
    for (key, num), where in sorted(refs.items()):
        if key not in files:
            problems.append(f"کلید ناشناخته «{key}» ({where[0]})")
            continue
        if key not in texts:
            texts[key] = files[key].read_text(encoding="utf-8")
        word = "اصل" if key == "constitution" else "ماده"
        if not article_exists(texts[key], num, word):
            problems.append(f"ماده {num} در «{key}» پیدا نشد ({where[0]})")
    print(f"{len(refs)} ارجاع بررسی شد؛ مشکل‌ها: {len(problems)}")
    for p in problems:
        print("  -", p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

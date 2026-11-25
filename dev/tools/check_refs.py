"""بررسی ارجاع‌های استنادی: هر `[[کلید:شماره]]` در کد باید به ماده‌ای واقعی
در فایل قانونِ همان کلید (`assets/laws/_meta.json`) اشاره کند.

اجرا:  python dev/tools/check_refs.py          (خروجی ۰ = همه درست)
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REF = re.compile(r"\[\[([a-z_]+):([0-9]+)\]\]")
PERSIAN = str.maketrans("0123456789", "۰۱۲۳۴۵۶۷۸۹")


def law_files() -> dict[str, Path]:
    meta = json.loads((ROOT / "assets/laws/_meta.json").read_text(encoding="utf-8"))
    return {k: ROOT / "assets/laws" / v["path"] for k, v in meta.items() if v.get("path")}


def article_exists(text: str, num: str, word: str = "ماده") -> bool:
    # ماده‌ها در متن قانون به شکل «ماده 35» یا «ماده ۳۵» در ابتدای سطر می‌آیند.
    # قانون اساسی به‌جای «ماده»، «اصل» دارد.
    pat = re.compile(
        r"^\s*%s\s*(?:%s|%s)\s*$" % (word, re.escape(num), re.escape(num.translate(PERSIAN))),
        re.MULTILINE,
    )
    return bool(pat.search(text))


def collect_refs() -> dict[tuple[str, str], list[str]]:
    found: dict[tuple[str, str], list[str]] = {}
    for path in (ROOT / "lib").rglob("*.dart"):
        for m in REF.finditer(path.read_text(encoding="utf-8")):
            found.setdefault((m.group(1), m.group(2)), []).append(str(path.relative_to(ROOT)))
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

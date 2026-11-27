import json
import os
import pathlib
import re
import subprocess
import sys
import time
import urllib.request

KEY = os.environ.get("GEMINI_API_KEY", "").strip()
MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
TASK = os.environ.get("AGENT_TASK", "").strip()
EXTRA = [p.strip() for p in os.environ.get("AGENT_FILES", "").split(",") if p.strip()]
MAX_ITER = 3
MAX_FILES = 3
MAX_FILE_CHARS = 150000
ALLOWED = ("lib/", "test/")


def run(cmd):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return r.stdout + r.stderr


def analyze():
    return run("flutter analyze --no-fatal-infos --no-fatal-warnings")


def count_errors(report):
    return len(re.findall(r"^\s*error\s+•", report, re.M))


def safe_path(p):
    # فقط فایل‌های dart داخل lib/ و test/ مجازند
    n = os.path.normpath(str(p)).replace("\\", "/")
    if n.startswith("/") or ".." in n.split("/"):
        return None
    if n.startswith(ALLOWED) and n.endswith(".dart"):
        return n
    return None


def files_from_report(report):
    found = re.findall(r"((?:lib|test)/[\w/.\-]+\.dart)", report)
    return list(dict.fromkeys(found))[:6]


def read_file(p):
    try:
        return pathlib.Path(p).read_text(encoding="utf-8")
    except Exception:
        return None


def ask(prompt):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
    body = json.dumps({
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.2,
            "responseMimeType": "application/json",
            "maxOutputTokens": 65000,
        },
    }).encode("utf-8")
    last = None
    for attempt in range(3):
        try:
            req = urllib.request.Request(
                url,
                data=body,
                headers={"Content-Type": "application/json", "x-goog-api-key": KEY},
            )
            with urllib.request.urlopen(req, timeout=300) as r:
                j = json.loads(r.read().decode("utf-8"))
            parts = j["candidates"][0]["content"]["parts"]
            return "".join(p.get("text", "") for p in parts)
        except Exception as e:
            last = e
            time.sleep(5 * (attempt + 1))
    raise RuntimeError(f"Gemini failed: {last}")


def parse(text):
    t = text.strip()
    t = re.sub(r"^```(?:json)?|```$", "", t, flags=re.M).strip()
    return json.loads(t)


def build_prompt(report, ctx):
    return (
        "تو یک مهندس خودمختار Flutter/Dart هستی و روی پروژه «دستیار» "
        "(دستیار حقوقی آفلاین فارسی) کار می‌کنی.\n"
        "کار: " + TASK + "\n\n"
        "قوانین:\n"
        '- فقط یک JSON معتبر برگردان با این قالب: {"summary":"خلاصه فارسی","done":true,'
        '"files":[{"path":"lib/...","content":"متن کامل فایل"}]}\n'
        "- هر فایل را کامل بنویس (نه تکه‌کد). فقط مسیرهای lib/ و test/ و فقط فایل dart. حداکثر 3 فایل.\n"
        "- وابستگی جدید اضافه نکن و pubspec.yaml را تغییر نده.\n"
        "- متن قوانین و شماره مواد را از خودت نساز.\n"
        "- کامنت‌ها فارسی باشند.\n"
        "- اگر چیزی برای تغییر نیست: files خالی و done=true.\n\n"
        "گزارش flutter analyze فعلی:\n" + report[:6000] + "\n\n"
        "فایل‌ها:\n" + ctx
    )


def main():
    if not KEY:
        sys.exit("GEMINI_API_KEY تنظیم نشده است")
    if not TASK:
        sys.exit("task خالی است")

    report = analyze()
    baseline = count_errors(report)
    print(f"خطاهای اولیه: {baseline}")
    summaries = []
    changed = []

    for i in range(1, MAX_ITER + 1):
        names = list(dict.fromkeys(EXTRA + files_from_report(report) + changed))[:8]
        ctx_parts = []
        for n in names:
            if not safe_path(n):
                continue
            c = read_file(n)
            if c is None:
                ctx_parts.append(f"=== {n} ===\n(فایل وجود ندارد)")
            elif len(c) > MAX_FILE_CHARS:
                ctx_parts.append(f"=== {n} ===\n(بیش از حد بزرگ است؛ تغییرش نده)")
            else:
                ctx_parts.append(f"=== {n} ===\n{c}")
        try:
            data = parse(ask(build_prompt(report, "\n\n".join(ctx_parts))))
        except Exception as e:
            summaries.append(f"مرحله {i}: خطا در پاسخ Gemini: {e}")
            break

        applied = []
        for f in (data.get("files") or [])[:MAX_FILES]:
            p = safe_path(f.get("path", ""))
            c = f.get("content")
            if not p or not isinstance(c, str) or not c.strip():
                continue
            old = read_file(p)
            if old is not None:
                if len(old) > MAX_FILE_CHARS:
                    continue
                # جلوگیری از فایل ناقص: کوتاه‌شدن شدید یعنی احتمالاً خروجی بریده شده
                if len(c) < len(old) * 0.5:
                    summaries.append(f"مرحله {i}: {p} رد شد (احتمالاً ناقص)")
                    continue
            pathlib.Path(p).parent.mkdir(parents=True, exist_ok=True)
            pathlib.Path(p).write_text(c, encoding="utf-8")
            applied.append(p)
            if p not in changed:
                changed.append(p)

        report = analyze()
        errs = count_errors(report)
        summaries.append(f"مرحله {i}: {data.get('summary', '')} | فایل‌ها: {applied} | خطاها: {errs}")
        print(summaries[-1])
        if not applied or (data.get("done") and errs == 0):
            break

    final = count_errors(report)
    if final > baseline:
        # بدتر شد: همه‌چیز را برگردان
        run("git checkout -- lib test")
        run("git clean -fdq lib test")
        summaries.append(f"نتیجه: خطاها از {baseline} به {final} رسید؛ تغییرات برگردانده شد.")
    else:
        summaries.append(f"نتیجه: خطاها از {baseline} به {final}.")

    pathlib.Path("/tmp/agent_summary.md").write_text(
        "## گزارش ایجنت خودکار\n\nکار: " + TASK + "\n\n" + "\n".join("- " + s for s in summaries),
        encoding="utf-8",
    )


main()
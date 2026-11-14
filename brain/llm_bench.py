"""سنجش مدل‌های زبانی کوچک روی «فهم جملهٔ کاربر».

پرسش این آزمایش فقط یک چیز است: اگر به‌جای الگوهای متنی، یک مدل زبانی کوچک
(که روی گوشی هم اجرا می‌شود) جملهٔ کاربر را بخواند، موضوع را درست می‌فهمد؟
مدل اینجا هیچ حرف حقوقی‌ای نمی‌زند؛ فقط جمله را به یک JSON کوچک تبدیل می‌کند.

اجرا (در GitHub Actions، چون مدل‌ها باید از اینترنت گرفته شوند):
    python brain/llm_bench.py
خروجی: brain/reports/llm_bench.md
"""

import json
import os
import re
import sys
import time
import traceback

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, 'eval', 'understanding_probe.tsv')
OUT = os.path.join(ROOT, 'brain', 'reports', 'llm_bench.md')

# (مخزن، الگوی نام فایل). فایل دقیق هنگام اجرا از فهرست مخزن پیدا می‌شود.
MODELS = [
    ('unsloth/gemma-3-1b-it-GGUF', r'q4_k_m\.gguf$'),
    ('Qwen/Qwen2.5-1.5B-Instruct-GGUF', r'q4_k_m\.gguf$'),
    ('unsloth/gemma-3n-E2B-it-GGUF', r'q4_k_m\.gguf$'),
    ('Qwen/Qwen2.5-3B-Instruct-GGUF', r'q4_k_m\.gguf$'),
    ('unsloth/gemma-3-4b-it-GGUF', r'q4_k_m\.gguf$'),
]

TOPICS = [
    ('rent', 'اجاره، موجر و مستأجر، ودیعه و رهن خانه'),
    ('cheque', 'چک و چک برگشتی'),
    ('debt', 'طلب، قرض، پولی که پس نمی‌دهند'),
    ('labor', 'کار و کارفرما: اخراج، حقوق، بیمهٔ کارگر'),
    ('family', 'خانواده: طلاق، مهریه، نفقه، حضانت، همسر'),
    ('accused', 'از خودِ کاربر شکایت شده یا احضاریه گرفته'),
    ('crime', 'کاربر قربانی جرم است: توهین، تهدید، سرقت، کلاهبرداری، آزار'),
    ('injury', 'تصادف، آسیب بدنی، دیه'),
    ('neighbor', 'همسایه و آپارتمان'),
    ('consumer', 'خرید کالا یا خدمت: جنس خراب، تحویل‌ندادن'),
    ('cyber', 'فضای مجازی: برداشت از حساب، انتشار عکس، هک'),
    ('inherit', 'ارث، وصیت، بدهی متوفی'),
    ('property', 'ملک و مال: سند، خرید و فروش، مدعیِ مالکیت'),
    ('company', 'شرکت، سهام، ثبت شرکت'),
    ('guarantee', 'ضمانت و ضامن‌شدن'),
    ('admin', 'اداره‌ها، بانک، خدمات دولتی'),
    ('general', 'پرسش کلی دربارهٔ معنی یا تفاوت مفهوم‌های حقوقی'),
    ('chat', 'سلام و احوال‌پرسی یا حرف غیرحقوقی'),
    ('other', 'هیچ‌کدام'),
]

INSTRUCTION = (
    'تو دستیار یک وکیل هستی. کارت فقط فهمیدنِ جملهٔ کاربر است، نه جواب‌دادن.\n'
    'فقط یک شیء JSON بده با دو کلید:\n'
    '"topic": دقیقاً یکی از این شناسه‌ها:\n'
    + '\n'.join(f'- {k}: {v}' for k, v in TOPICS)
    + '\n"summary": یک جملهٔ کوتاه فارسی: کاربر چه می‌گوید و چه می‌خواهد.\n'
    'هیچ متن دیگری ننویس.\n\n'
)


def load():
    rows = []
    with open(DATA, encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            if not line.strip() or line.startswith('#'):
                continue
            gold, rules, text = line.split('\t', 2)
            rows.append((gold.split('|'), rules.strip() == '1', text.strip()))
    return rows


def parse(text):
    m = re.search(r'\{.*\}', text, re.S)
    if not m:
        return None
    try:
        obj = json.loads(m.group(0))
    except Exception:
        return None
    return obj if isinstance(obj, dict) else None


def fetch(repo, pattern):
    from huggingface_hub import hf_hub_download, list_repo_files

    files = [f for f in list_repo_files(repo) if re.search(pattern, f, re.I)]
    if not files:
        raise RuntimeError(f'no file matching {pattern} in {repo}')
    files.sort(key=len)
    return hf_hub_download(repo, files[0]), files[0]


def run_model(repo, pattern, rows):
    from llama_cpp import Llama

    path, fname = fetch(repo, pattern)
    size_gb = os.path.getsize(path) / 1e9
    llm = Llama(model_path=path, n_ctx=2048, n_threads=os.cpu_count() or 4,
                verbose=False)
    res = []
    t_all = time.time()
    out_tokens = 0
    for gold, _, text in rows:
        t0 = time.time()
        r = llm.create_chat_completion(
            messages=[{
                'role': 'user',
                'content': INSTRUCTION + f'جملهٔ کاربر: «{text}»',
            }],
            temperature=0,
            max_tokens=120,
        )
        raw = r['choices'][0]['message']['content'] or ''
        out_tokens += r.get('usage', {}).get('completion_tokens', 0)
        obj = parse(raw)
        topic = str(obj.get('topic', '')).strip().lower() if obj else ''
        summary = str(obj.get('summary', '')).strip() if obj else raw.strip()[:120]
        res.append({
            'ok': topic in gold,
            'valid': obj is not None,
            'topic': topic,
            'summary': summary.replace('\n', ' ')[:160],
            'sec': time.time() - t0,
        })
        print(f'  [{"✓" if topic in gold else "✗"}] {text[:50]} -> {topic}',
              flush=True)
    total = time.time() - t_all
    del llm
    try:
        os.remove(path)  # جا برای مدل بعدی
    except OSError:
        pass
    return {
        'repo': repo, 'file': fname, 'size_gb': size_gb, 'res': res,
        'sec_per_msg': total / max(1, len(rows)),
        'tok_per_sec': out_tokens / total if total > 0 else 0,
    }


def main():
    rows = load()
    only = os.environ.get('MODELS')
    models = MODELS
    if only:
        models = [m for m in MODELS if any(x in m[0] for x in only.split(','))]
    n = len(rows)
    rules_ok = sum(1 for _, r, _ in rows if r)
    lines = [
        '# سنجش فهم جمله: الگوهای متنی در برابر مدل زبانی کوچک',
        '',
        f'جمله‌ها: {n} (`eval/understanding_probe.tsv`). معیار: موضوعِ درست.',
        'سرعت روی پردازندهٔ GitHub Actions اندازه گرفته شده و فقط برای مقایسهٔ مدل‌ها با هم معتبر است، نه برای گوشی.',
        '',
        '| روش | حجم | موضوع درست | JSON سالم | ثانیه برای هر پیام | توکن بر ثانیه |',
        '|---|---|---|---|---|---|',
        f'| وکیل قاعده‌ای فعلی (داوری دستی) | — | {rules_ok}/{n} ({rules_ok / n:.0%}) | — | — | — |',
    ]
    details = []
    for repo, pattern in models:
        print(f'== {repo}', flush=True)
        try:
            m = run_model(repo, pattern, rows)
        except Exception as e:  # مدل ناموجود یا ناسازگار: بقیه ادامه می‌یابند
            traceback.print_exc()
            lines.append(f'| {repo} | — | خطا: {str(e)[:80]} | — | — | — |')
            continue
        ok = sum(1 for r in m['res'] if r['ok'])
        valid = sum(1 for r in m['res'] if r['valid'])
        lines.append(
            f"| {repo} ({m['file']}) | {m['size_gb']:.1f} GB | {ok}/{n} ({ok / n:.0%}) "
            f"| {valid}/{n} | {m['sec_per_msg']:.1f} | {m['tok_per_sec']:.1f} |")
        details.append(m)
        # گزارش میانی، تا اگر کار نیمه‌تمام ماند نتیجهٔ مدل‌های قبلی بماند.
        write(lines, details, rows)
    write(lines, details, rows)
    return 0


def write(lines, details, rows):
    out = list(lines)
    for m in details:
        out += ['', f"## {m['repo']}", '',
                '| | جمله | موضوع درست | مدل گفت | برداشت مدل |',
                '|---|---|---|---|---|']
        for (gold, _, text), r in zip(rows, m['res']):
            out.append(
                f"| {'✓' if r['ok'] else '✗'} | {text} | {'/'.join(gold)} "
                f"| {r['topic'] or '—'} | {r['summary'].replace('|', '/')} |")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write('\n'.join(out) + '\n')


if __name__ == '__main__':
    sys.exit(main())

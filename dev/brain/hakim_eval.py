"""آزمایشِ غیرمخربِ `Hakim-small` در برابر مدلِ حدسِ موضوع.

این اسکریپت فقط در GitHub Actions اجرا میشود و یک گزارش مینویسد. هیچ وزنی
وارد مخزن یا بستهٔ اپ نمیشود و کدِ مسیرِ اصلی تغییر نمیکند: حتی اگر مدلِ
دسترس، کوانتیزهشده و برنده شود، تعویضِ مدل یک تصمیمِ جداگانه است.

وزنهای `MCINext/Hakim-small` همگانی نیستند. تا وقتی که آدرسِ معتبری از طریق
`HAKIM_MODEL_REPO` (و optionally `HAKIM_REV`) داده نشود، اسکریپت وضعیتِ
`CLOSED` مینویسد و بدونِ خطا تمام میشود.

روشِ سنجش همان روشِ `alt_bench.py` است: همان نمونهها، همان سرِ رگرسیون
لجستیک، همان محک (probe) و مجموعهٔ ب (set_b). کوانتیزهسازیِ پویای int8 روی لایههای Linears
انجام میشود و نسخهٔ fp32 و int8 هر دو سنجیده میشوند تا معلوم شود کوانتیزه
چقدر از دقت کم میکند.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)

OUT = os.path.join(ROOT, 'reports', 'hakim_eval.md')
BASELINE = 'shekar-ai/Noql'


def write(lines):
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines).rstrip() + '\n')


def closed(reason):
    write([
        '# Hakim-small: آزمایشِ کوانتیزه و جانشینی',
        '',
        'وضعیت: CLOSED — کوانتیزه و تعویضی انجام نشد.',
        '',
        'دلیل: %s' % reason,
        '',
        'برای اجرای واقعی، مخزنِ دارای وزنها را در ورودیِ `workflow_dispatch` '
        'یا متغیرِ `HAKIM_MODEL_REPO` بدهید (و در صورت لزوم `HAKIM_REV`). '
        'توکنِ دسترسی باید بهصورت Secret در GitHub تعریف شود، نه در کد یا در متنِ '
        'گزارش. وزنها فقط در حافظهٔ موقتیِ Actions دانلود میشوند.',
        '',
        'تنها خروجیِ این جریان همین فایل است. مدلِ موردِ استفادهٔ برنامه '
        'و داراییهایش دستنخوردهاند.',
    ])


def encode(tokenizer, model, texts):
    import torch
    from embed_bench import unit

    vectors = []
    width = 32
    for i in range(0, len(texts), width):
        batch = texts[i:i + width]
        enc = tokenizer(batch, return_tensors='pt', padding=True,
                        truncation=True, max_length=96)
        with torch.no_grad():
            out = model(**enc)
        hidden = out.last_hidden_state
        mask = enc['attention_mask'].unsqueeze(-1).to(hidden.dtype)
        pooled = (hidden * mask).sum(dim=1) / mask.sum(dim=1).clamp(min=1)
        vectors.append(unit(pooled.float().numpy()))
    return unit(__import__('numpy').vstack(vectors))


def measure(repo, rev, data):
    import torch
    from transformers import AutoModel, AutoTokenizer
    from torch.ao.quantization import quantize_dynamic

    from alt_bench import head_scores
    from embed_bench import fix

    kwargs = {'revision': rev} if rev else {}
    tokenizer = AutoTokenizer.from_pretrained(repo, trust_remote_code=False, **kwargs)
    model = AutoModel.from_pretrained(repo, trust_remote_code=False, **kwargs)
    model.eval()
    texts = [fix(t) for t in data.texts]

    fp32 = encode(tokenizer, model, texts)
    quantized = quantize_dynamic(model, {torch.nn.Linear}, dtype=torch.qint8)
    q8 = encode(tokenizer, quantized, texts)
    return head_scores(data, fp32), head_scores(data, q8), model.config.model_type


def table(rows):
    head = ['مدل', 'اعتبارسنجی', 'محک', 'مجموعهٔ ب', 'جمع ۱۰۱', 'نزدیکترین نمونه']
    keys = ['name', 'cv', 'probe', 'b', 'total', 'knn']
    out = ['| ' + ' | '.join(head) + ' |',
           '|' + '---|' * len(head)]
    for row in rows:
        out.append('| ' + ' | '.join(str(row[k]) for k in keys) + ' |')
    return out


def main():
    repo = os.environ.get('HAKIM_MODEL_REPO', '')
    rev = os.environ.get('HAKIM_REV', '')
    if not repo:
        closed('وزنهای عمومیای برای `MCINext/Hakim-small` موجود نیست '
               '(کارت مدل: Proprietary / Closed-weight).')
        return 0

    try:
        from alt_bench import run as bench_repo
        from embed_bench import Data

        data = Data()
        baseline = bench_repo(BASELINE, '', data)
        fp32, q8, kind = measure(repo, rev, data)
    except Exception as exc:
        write([
            '# Hakim-small: آزمایشِ کوانتیزه و جانشینی',
            '',
            'وضعیت: ERROR — مدلِ %s قابلِ خواندن نبود.' % repo,
            '',
            '`%r`' % (exc,),
            '',
            'هیچ دارایی یا کدی عوض نشد؛ مدلِ برنامه همان است.',
        ])
        return 1

    def row(name, s):
        return {
            'name': name,
            'cv': '%d/%d' % (s['cv'], s['n']),
            'probe': s['probe'],
            'b': s['b'],
            'total': s['probe'] + s['b'],
            'knn': s['knn'] + s['knn_b'],
        }

    best = max(fp32['probe'] + fp32['b'], q8['probe'] + q8['b'])
    verdict = ('کاندیدای کوانتیزهشده در این محک از مدلِ فعلی جلوتر رفت؛ '
               'ولی تعویض نیاز به آزمونِ جداگانه و تأیید دارد.'
               if best > baseline['probe'] + baseline['b'] else
               'کاندیدای کوانتیزهشده در این محک جلوتر نرفت؛ مدلِ فعلی باقی میماند.')
    write([
        '# Hakim-small: آزمایشِ کوانتیزه و جانشینی',
        '',
        'وضعیت: MEASURED — فقط REPORT نوشته شد، هیچ تعویضی انجام نشد.',
        '',
        '- مدل: `%s`، نسخهٔ `%s`' % (repo, rev or 'پیشفرض'),
        '- ساختار: `%s`؛ کوانتیزه: dynamic int8 روی لایههای Linears' % kind,
        '- ورودی: `HAKIM_MODEL_REPO` / `HAKIM_REV`',
        '- سنجش: همان نمونهها و سرِ `alt_bench.py` (محک ۳۹ + مجموعهٔ ب ۶۲).',
        '',
        table([
            row('مدلِ فعلی (`%s`)' % BASELINE, baseline),
            row('کاندیدای fp32', fp32),
            row('کاندیدای int8', q8),
        ]),
        '',
        verdict,
        '',
        'وزنها وارد مخزن یا بستهٔ اپ نشدند؛ مسیرِ حدسِ موضوع دستنخورده است.',
    ])
    return 0


if __name__ == '__main__':
    sys.exit(main())

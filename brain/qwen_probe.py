"""آیا Qwen3-0.6B-fas-16384 (Qwen3-0.6B با واژگانِ بریده‌شده برای فارسی) به کار ما می‌آید؟

این آزمایش است، نه بخشی از برنامه. دو مرحله دارد که جدا اجرا می‌شوند:

STAGE=gguf   مدلِ اصلیِ Qwen3-0.6B با دو فشرده‌سازیِ Q4_K_M و Q8_0 (llama.cpp).
             بدنهٔ مدلِ بریده‌شده همین است؛ فقط جدولِ توکن‌هایش کوچک‌تر است.
             پس اثرِ Q4 در برابر Q8 را همین‌جا می‌شود دید.
STAGE=hf     خودِ مدلِ بریده‌شده (وزن اصلی، بدون فشرده‌سازی):
             ۱) بدون آموزش: موضوعِ جمله و پرسش‌های بله/خیر (نفی)
             ۲) مدل فقط بردار بدهد و همان سرِ طبقه‌بندِ برنامه رویش بنشیند
             ۳) آموزشِ LoRA روی ۲۵۰ نمونهٔ eval/topic_examples.tsv

STAGE=extra  سه وارسیِ تکمیلی تا نتیجه به یک تنظیمِ خاص وابسته نباشد:
             پرسش بله/خیر با هر دو ترتیبِ گزینه‌ها، بردارِ استانداردشدهٔ مدل + سرِ
             طبقه‌بند، و یک آموزشِ LoRA آرام‌تر با سنجش در میانهٔ راه.

سنجه همان است که برای Noql به کار رفت: محک (۳۹) + مجموعهٔ ب (۶۲).
خروجی: reports/qwen_gguf.md، qwen_tuned.md و qwen_extra.md
    DRY=1 STAGE=gguf python brain/qwen_probe.py     # بدون مدل؛ فقط قالب گزارش
"""

import copy
import os
import re
import sys
import time
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from embed_bench import Data, fix, unit  # noqa: E402
from llm_bench import INSTRUCTION, fetch  # noqa: E402

TRIMMED = 'alphaedge-ai/Qwen3-0.6B-fas-16384'
GGUF_REPO = 'unsloth/Qwen3-0.6B-GGUF'
GGUF_FILES = [('Q4_K_M', r'-Q4_K_M\.gguf$'), ('Q8_0', r'-Q8_0\.gguf$')]
OUT_GGUF = os.path.join(HERE, 'reports', 'qwen_gguf.md')
OUT_HF = os.path.join(HERE, 'reports', 'qwen_tuned.md')
OUT_EXTRA = os.path.join(HERE, 'reports', 'qwen_extra.md')
DRY = bool(os.environ.get('DRY'))
TRAIN_BUDGET_S = float(os.environ.get('TRAIN_BUDGET_S', 24 * 60))
EPOCHS = int(os.environ.get('EPOCHS', 4))

# اندازه‌ها (پارامتر): بدنه در هر دو مدل یکی است، فقط جدول توکن فرق دارد.
BODY_M = 440.47
TABLE_FULL_M = 151936 * 1024 / 1e6
TABLE_TRIM_M = 16384 * 1024 / 1e6

REFERENCE = ('مرجع: Noql (۱۲٫۷ میلیون پارامتر، ۱۳ مگابایت در برنامه) با سرِ طبقه‌بند '
             '۹۰ از ۱۰۱ (محک ۳۵، ب ۵۵)؛ قاعده‌های دستی روی محک ۲۴ از ۳۹.')

# نام فارسیِ برچسب‌ها برای آموزش؛ واژگانِ مدل برای فارسی بریده شده است.
FA = {
    'rent': 'اجاره', 'cheque': 'چک', 'debt': 'طلب', 'labor': 'کار',
    'family': 'خانواده', 'accused': 'متهم', 'crime': 'جرم', 'injury': 'دیه',
    'neighbor': 'همسایه', 'consumer': 'خرید', 'cyber': 'اینترنت',
    'inherit': 'ارث', 'property': 'ملک', 'company': 'شرکت',
    'guarantee': 'ضمانت', 'admin': 'اداره', 'general': 'کلی',
    'chat': 'گفتگو', 'other': 'دیگر',
}

# جمله‌هایی که جوابِ یک پرسشِ بله/خیر را برعکس می‌کنند. این همان کاری است که
# مدلِ برداری (Noql) از پسش برنمی‌آید. هر جفت: (جمله، جوابِ درست) دو بار.
NEG = [
    ('آیا کارفرما این شخص را بیمه کرده است؟',
     'کارفرما مرا بیمه می‌کند', 'کارفرما مرا بیمه نمی‌کند'),
    ('آیا این شخص قرارداد کتبی دارد؟',
     'قرارداد کتبی دارم', 'قرارداد کتبی ندارم'),
    ('آیا حقوق این شخص پرداخت شده است؟',
     'حقوقم را داده‌اند', 'حقوقم را نداده‌اند'),
    ('آیا این شخص خانه را تخلیه کرده است؟',
     'خانه را تخلیه کرده‌ام', 'خانه را تخلیه نکرده‌ام'),
    ('آیا بیمهٔ این شخص پرداخت شده است؟',
     'سه ماهه اونجا کار می‌کنم و بیمه‌م از روز اول رد شده',
     'سه ماهه اونجا کار می‌کنم و هنوز بیمه‌م رد نشده'),
    ('آیا پول پیش به این شخص پس داده شده است؟',
     'صاحبخونه پول پیش رو پس داد', 'صاحبخونه پول پیش رو پس نمی‌ده'),
    ('آیا چک برگشت خورده است؟',
     'چک رو بردم بانک و برگشت خورد', 'چک رو بردم بانک و پاس شد'),
    ('آیا این شخص برگهٔ تسویه‌حساب را امضا کرده است؟',
     'با کارفرما تسویه کرده‌ام و برگه را هم امضا کرده‌ام',
     'هنوز با کارفرما تسویه نکرده‌ام و چیزی هم امضا نکرده‌ام'),
    ('آیا مدت اجاره تمام شده است؟',
     'اجاره‌نامه‌مان تمام شده', 'اجاره‌نامه‌مان هنوز تمام نشده'),
    ('آیا این شخص شاهد دارد؟',
     'شاهد دارم که پول را به او دادم', 'هیچ شاهدی ندارم که پول را به او دادم'),
    ('آیا این شخص دادخواست داده است؟',
     'برای مهریه‌ام دادخواست داده‌ام', 'هنوز برای مهریه‌ام دادخواست نداده‌ام'),
    ('آیا اخراج به‌صورت کتبی بوده است؟',
     'کارفرما کتبی اخراجم کرد', 'کارفرما نامه‌ای نداد فقط گفت دیگه نیا'),
]


def parse_topic(raw):
    raw = raw.split('</think>')[-1]
    m = re.search(r'"topic"\s*:\s*"?\s*([a-z_]+)', raw)
    return m.group(1) if m else ''


def parse_yn(raw):
    s = raw.split('</think>')[-1].strip()[:24]
    m = re.search('بله|آری|خیر|نه', s)
    if not m:
        return ''
    return 'y' if m.group(0) in ('بله', 'آری') else 'n'


def topic_eval(ask, rows, **kw):
    res = []
    for gold, text in rows:
        t0 = time.time()
        raw = ask(INSTRUCTION + f'جملهٔ کاربر: «{fix(text)}»', **kw)
        k = parse_topic(raw)
        res.append({'text': text, 'gold': gold, 'pred': k, 'ok': k in gold,
                    'sec': time.time() - t0, 'raw': raw})
        print(f"  [{'✓' if k in gold else '✗'}] {text[:50]} -> {k}", flush=True)
    return res


def neg_eval(ask):
    res = []
    for q, yes, no in NEG:
        pair = []
        for s, gold in ((yes, 'y'), (no, 'n')):
            raw = ask(f'جمله: «{s}»\nپرسش: {q}\nفقط با یک کلمه جواب بده: بله یا خیر.')
            got = parse_yn(raw)
            pair.append({'s': s, 'gold': gold, 'got': got, 'ok': got == gold})
        res.append({'q': q, 'pair': pair, 'ok': all(p['ok'] for p in pair)})
        print(f"  neg [{'✓' if res[-1]['ok'] else '✗'}] {q}", flush=True)
    return res


def count(res):
    return sum(1 for r in res if r['ok'])


def neg_counts(res):
    return sum(p['ok'] for r in res for p in r['pair']), count(res)


def neg_lines(res):
    L = ['| پرسش | جمله | باید | مدل گفت | |', '|---|---|---|---|---|']
    name = {'y': 'بله', 'n': 'خیر', '': '—'}
    for r in res:
        for p in r['pair']:
            L.append(f"| {r['q']} | {p['s']} | {name[p['gold']]} | {name[p['got']]} "
                     f"| {'✓' if p['ok'] else '✗'} |")
    return L


def miss_lines(res):
    return [f"  - «{r['text'][:70]}» [{'/'.join(r['gold'])}] → {r['pred'] or '—'}"
            for r in res if not r['ok']]


def est_mb(bits_body, bits_table, table_m):
    return (BODY_M * bits_body + table_m * bits_table) / 8


# ---------------------------------------------------------------- مرحلهٔ gguf
def open_gguf(pattern):
    from llama_cpp import Llama

    path, fname = fetch(GGUF_REPO, pattern)
    llm = Llama(model_path=path, n_ctx=2048, seed=0,
                n_threads=os.cpu_count() or 4, verbose=False)
    stat = {'tokens': 0, 'sec': 0.0}

    def ask(content, think=False, max_tokens=40):
        prompt = f'<|im_start|>user\n{content}<|im_end|>\n<|im_start|>assistant\n'
        if not think:
            prompt += '<think>\n\n</think>\n\n'
        # کارت مدل برای حالتِ فکرکردن نمونه‌گیری می‌خواهد، نه انتخابِ حریصانه.
        sample = dict(temperature=0.6, top_p=0.95, top_k=20) if think \
            else dict(temperature=0)
        t0 = time.time()
        r = llm.create_completion(prompt=prompt, max_tokens=max_tokens,
                                  stop=['<|im_end|>'], **sample)
        stat['sec'] += time.time() - t0
        stat['tokens'] += r.get('usage', {}).get('completion_tokens', 0)
        return r['choices'][0]['text'] or ''

    return ask, stat, fname, os.path.getsize(path) / 1e6


def gguf_stage(data):
    rows = []
    for tag, pattern in GGUF_FILES:
        print('==', tag, flush=True)
        row = {'tag': tag}
        try:
            if DRY:
                ask = lambda c, **kw: 'بله' if 'پرسش:' in c else '{"topic": "labor"'  # noqa: E731
                row.update(file='dry.gguf', mb=0.0)
            else:
                ask, stat, fname, mb = open_gguf(pattern)
                row.update(file=fname, mb=mb)
                row['stat'] = stat
            row['probe'] = topic_eval(ask, data.probe)
            row['b'] = topic_eval(ask, data.set_b)
            row['neg'] = neg_eval(ask)
            if not DRY:
                row['tps'] = stat['tokens'] / max(stat['sec'], 1e-9)
            if tag == 'Q8_0':
                # حالتِ «فکرکردن» خودِ مدل، فقط روی محک (کند است).
                if not DRY:
                    stat.update(tokens=0, sec=0.0)
                row['think'] = topic_eval(ask, data.probe, think=True, max_tokens=700)
                if not DRY:
                    row['think_tokens'] = stat['tokens'] / len(data.probe)
        except Exception:  # noqa: BLE001
            traceback.print_exc()
            row['error'] = traceback.format_exc()[-1500:]
        rows.append(row)
        write_gguf(data, rows)


def write_gguf(data, rows):
    n_p, n_b = len(data.probe), len(data.set_b)
    L = ['# Qwen3-0.6B: فشرده‌سازی Q4 در برابر Q8، بدون آموزش', '',
         f'مدل: `{GGUF_REPO}` (همان بدنهٔ `{TRIMMED}`؛ برای مدلِ بریده‌شده فایل GGUF '
         'آماده‌ای منتشر نشده است). دستور همان دستورِ سنجشِ قبلیِ مدل‌های زبانی است '
         '(`brain/llm_bench.py`)، حالتِ فکرکردن خاموش مگر جایی که گفته شده.', '',
         REFERENCE, '',
         f'| فشرده‌سازی | حجم فایل (MB) | محک ({n_p}) | ب ({n_b}) | **جمع** | بله/خیر: جمله‌ها (۲۴) | '
         'بله/خیر: جفتِ کامل (۱۲) | توکن بر ثانیه (CI) |',
         '|---|---|---|---|---|---|---|---|']
    for r in rows:
        if 'probe' not in r or 'b' not in r or 'neg' not in r:
            L.append(f"| {r['tag']} | — | خطا | | | | | |")
            continue
        items, pairs = neg_counts(r['neg'])
        L.append(f"| {r['tag']} | {r.get('mb', 0):.0f} | {count(r['probe'])} | {count(r['b'])} | "
                 f"**{count(r['probe']) + count(r['b'])}** | {items} | {pairs} | "
                 f"{r.get('tps', 0):.0f} |")
    for r in rows:
        if 'think' in r:
            L += ['', f"با حالتِ فکرکردنِ خودِ مدل ({r['tag']}، فقط محک، سقف ۷۰۰ توکن): "
                  f"**{count(r['think'])} از {n_p}**، میانگین "
                  f"{r.get('think_tokens', 0):.0f} توکن برای هر پیام."]
    L += ['', '## برآورد حجمِ مدلِ بریده‌شده پس از تبدیل', '',
          f'بدنه {BODY_M:.1f} میلیون پارامتر؛ جدول توکن از {TABLE_FULL_M:.1f} به '
          f'{TABLE_TRIM_M:.1f} میلیون می‌رسد. با همان بیت‌های llama.cpp:', '',
          '| | مدل اصلی (اندازه‌گیری‌شده) | مدل بریده‌شده (برآورد) |', '|---|---|---|',
          f'| Q4_K_M | 397 MB | حدود {est_mb(4.82, 6.56, TABLE_TRIM_M):.0f} MB |',
          f'| Q8_0 | 639 MB | حدود {est_mb(8.5, 8.5, TABLE_TRIM_M):.0f} MB |', '']
    for r in rows:
        L += [f"## {r['tag']}", '']
        if 'error' in r:
            L += ['```', r['error'], '```', '']
        if 'probe' in r:
            L += [f"خطاهای محک ({len(data.probe) - count(r['probe'])}):"] + miss_lines(r['probe']) + ['']
        if 'think' in r:
            L += [f"خطاهای محک با فکرکردن ({len(data.probe) - count(r['think'])}):"]
            L += miss_lines(r['think']) + ['']
        if 'neg' in r:
            L += neg_lines(r['neg']) + ['']
    save(OUT_GGUF, L)


# ------------------------------------------------------------------ مرحلهٔ hf
class Hf:
    def __init__(self):
        import torch
        from transformers import AutoModelForCausalLM, AutoTokenizer

        torch.set_num_threads(os.cpu_count() or 4)
        torch.manual_seed(0)
        self.torch = torch
        self.tok = AutoTokenizer.from_pretrained(TRIMMED)
        self.model = AutoModelForCausalLM.from_pretrained(TRIMMED).float().eval()
        self.pad = self.tok.pad_token_id
        self.eos = self.tok.convert_tokens_to_ids('<|im_end|>')
        self.head = None  # (متنِ سر، شناسه‌ها، حافظهٔ میانیِ مدل)
        self.params = sum(p.numel() for p in self.model.parameters()) / 1e6

    def ids(self, text):
        t = self.tok(text, add_special_tokens=False)['input_ids']
        return self.torch.tensor([t], dtype=self.torch.long)

    def chat(self, content):
        return self.tok.apply_chat_template(
            [{'role': 'user', 'content': content}], tokenize=False,
            add_generation_prompt=True, enable_thinking=False)

    def _gen(self, ids, max_new, cache=None):
        torch = self.torch
        kw = dict(input_ids=ids, attention_mask=torch.ones_like(ids),
                  max_new_tokens=max_new, do_sample=False, pad_token_id=self.pad)
        with torch.no_grad():
            if cache is not None:
                out = self.model.generate(past_key_values=copy.deepcopy(cache), **kw)
            else:
                out = self.model.generate(**kw)
        return self.tok.decode(out[0, ids.shape[1]:], skip_special_tokens=True)

    def ask(self, content, max_new=40):
        """دستورِ ثابتِ اول پیام یک بار حساب و برای جمله‌های بعد نگه داشته می‌شود."""
        torch = self.torch
        full = self.chat(content)
        if INSTRUCTION in full:
            cut = full.index(INSTRUCTION) + len(INSTRUCTION)
            head, tail = full[:cut], full[cut:]
            if self.head is None or self.head[0] != head:
                hid = self.ids(head)
                cache = None
                try:
                    with torch.no_grad():
                        cache = self.model(hid, use_cache=True).past_key_values
                except Exception:  # noqa: BLE001
                    traceback.print_exc()
                self.head = [head, hid, cache]
            ids = torch.cat([self.head[1], self.ids(tail)], 1)
            if self.head[2] is not None:
                try:
                    return self._gen(ids, max_new, self.head[2])
                except Exception:  # noqa: BLE001
                    traceback.print_exc()
                    self.head[2] = None
            return self._gen(ids, max_new)
        return self._gen(self.ids(full), max_new)

    def features_raw(self, texts, layers):
        """بردارِ خام از چند لایه، با دو شیوه: میانگینِ توکن‌ها و آخرین توکن."""
        import numpy as np

        torch = self.torch
        self.tok.padding_side = 'right'
        outs = {(p, k): [] for p in ('mean', 'last') for k in layers}
        for i in range(0, len(texts), 16):
            b = self.tok(texts[i:i + 16], return_tensors='pt', padding=True,
                         add_special_tokens=False)
            with torch.no_grad():
                hs = self.model(**b, output_hidden_states=True).hidden_states
            mask = b['attention_mask']
            m = mask.unsqueeze(-1).float()
            last = mask.sum(1) - 1
            rows = torch.arange(mask.shape[0])
            for k in layers:
                outs[('mean', k)].append(((hs[k] * m).sum(1) / m.sum(1)).numpy())
                outs[('last', k)].append(hs[k][rows, last].numpy())
        return {key: np.concatenate(v) for key, v in outs.items()}

    # -- آموزش LoRA: «جمله: … ⏎ موضوع: <نام فارسی>»
    def prompt_ids(self, text):
        return self.tok(f'جمله: {fix(text)}\nموضوع:', add_special_tokens=False)['input_ids']

    def train(self, examples, log, r=16, alpha=32, lr=2e-4, dropout=0.05,
              epochs=EPOCHS, on_epoch=None):
        import random

        from peft import LoraConfig, get_peft_model

        torch = self.torch
        cfg = LoraConfig(r=r, lora_alpha=alpha, lora_dropout=dropout, task_type='CAUSAL_LM',
                         target_modules=['q_proj', 'k_proj', 'v_proj', 'o_proj',
                                         'gate_proj', 'up_proj', 'down_proj'])
        self.model = get_peft_model(self.model, cfg)
        train_p = [p for p in self.model.parameters() if p.requires_grad]
        log['lora_params'] = sum(p.numel() for p in train_p) / 1e6
        rows = []
        for label, text in examples:
            p = self.prompt_ids(text)
            t = self.tok(' ' + FA[label], add_special_tokens=False)['input_ids'] + [self.eos]
            rows.append((p, t))
        log['tokens_mean'] = sum(len(p) + len(t) for p, t in rows) / len(rows)
        bs = 8
        steps_total = epochs * ((len(rows) + bs - 1) // bs)
        opt = torch.optim.AdamW(train_p, lr=lr, weight_decay=0.0)
        warm = max(1, steps_total // 10)
        sched = torch.optim.lr_scheduler.LambdaLR(
            opt, lambda s: min(1.0, (s + 1) / warm) * max(0.05, 1 - s / steps_total))
        rnd = random.Random(0)
        self.model.train()
        t0 = time.time()
        step = 0
        log['loss'] = []
        for ep in range(epochs):
            order = list(range(len(rows)))
            rnd.shuffle(order)
            tot = n = 0
            for i in range(0, len(order), bs):
                batch = [rows[j] for j in order[i:i + bs]]
                width = max(len(p) + len(t) for p, t in batch)
                x = torch.full((len(batch), width), self.pad, dtype=torch.long)
                y = torch.full((len(batch), width), -100, dtype=torch.long)
                a = torch.zeros((len(batch), width), dtype=torch.long)
                for r, (p, t) in enumerate(batch):
                    x[r, :len(p) + len(t)] = torch.tensor(p + t)
                    y[r, len(p):len(p) + len(t)] = torch.tensor(t)
                    a[r, :len(p) + len(t)] = 1
                loss = self.model(input_ids=x, attention_mask=a, labels=y).loss
                loss.backward()
                torch.nn.utils.clip_grad_norm_(train_p, 1.0)
                opt.step()
                sched.step()
                opt.zero_grad()
                step += 1
                tot += float(loss)
                n += 1
                if step % 5 == 0:
                    print(f'  step {step}/{steps_total} loss {float(loss):.3f} '
                          f'{time.time() - t0:.0f}s', flush=True)
                if time.time() - t0 > TRAIN_BUDGET_S:
                    break
            log['loss'].append(tot / max(n, 1))
            if time.time() - t0 > TRAIN_BUDGET_S:
                log['cut'] = True
                break
            if on_epoch is not None:
                self.model.eval()
                on_epoch(ep + 1)
                self.model.train()
        log.update(steps=step, steps_total=steps_total, train_sec=time.time() - t0)
        self.model.eval()

    def classify(self, text):
        torch = self.torch
        ids = torch.tensor([self.prompt_ids(text)], dtype=torch.long)
        with torch.no_grad():
            out = self.model.generate(input_ids=ids, attention_mask=torch.ones_like(ids),
                                      max_new_tokens=8, do_sample=False,
                                      pad_token_id=self.pad, eos_token_id=self.eos)
        return self.tok.decode(out[0, ids.shape[1]:], skip_special_tokens=True)


def fa_to_id(raw):
    s = raw.strip().split('\n')[0].strip()
    for k, name in sorted(FA.items(), key=lambda kv: -len(kv[1])):
        if s.startswith(name):
            return k
    return ''


def tuned_eval(classify, rows):
    res = []
    for gold, text in rows:
        t0 = time.time()
        raw = classify(text)
        k = fa_to_id(raw)
        res.append({'text': text, 'gold': gold, 'pred': k or raw.strip()[:12],
                    'ok': k in gold, 'sec': time.time() - t0})
    return res


def hf_stage(data):
    R = {'errors': []}
    write_hf(data, R)

    def guard(name, fn):
        print('==', name, flush=True)
        try:
            fn()
        except Exception:  # noqa: BLE001
            traceback.print_exc()
            R['errors'].append((name, traceback.format_exc()[-1500:]))
        write_hf(data, R)

    if DRY:
        fake = lambda c, **kw: 'خیر' if 'پرسش:' in c else '{"topic": "rent"'  # noqa: E731
        R.update(params=474.0, roundtrip=('{"topic": "labor"}', '{"topic": "labor"}', 9),
                 zero_probe=topic_eval(fake, data.probe), zero_b=topic_eval(fake, data.set_b),
                 neg=neg_eval(fake),
                 lora={'loss': [1.0], 'steps': 1, 'steps_total': 1, 'train_sec': 1.0,
                       'lora_params': 1.0, 'tokens_mean': 30.0},
                 tuned_probe=tuned_eval(lambda t: ' کار', data.probe),
                 tuned_b=tuned_eval(lambda t: ' کار', data.set_b))
        write_hf(data, R)
        return

    hf = Hf()
    R['params'] = hf.params

    def roundtrip():
        s = '{"topic": "labor"}'
        t = hf.tok(s, add_special_tokens=False)['input_ids']
        R['roundtrip'] = (s, hf.tok.decode(t), len(t))
        R['probe_tokens'] = sum(len(hf.tok(fix(t), add_special_tokens=False)['input_ids'])
                                for _, t in data.probe) / len(data.probe)

    def zero():
        R['zero_probe'] = topic_eval(hf.ask, data.probe)
        R['zero_b'] = topic_eval(hf.ask, data.set_b)

    def neg():
        R['neg'] = neg_eval(hf.ask)

    def lora():
        log = {}
        R['lora'] = log
        hf.train(data.examples, log)
        R['tuned_probe'] = tuned_eval(hf.classify, data.probe)
        write_hf(data, R)
        R['tuned_b'] = tuned_eval(hf.classify, data.set_b)

    guard('roundtrip', roundtrip)
    guard('zero-shot', zero)
    guard('negation', neg)
    guard('lora', lora)


def write_hf(data, R):
    n_p, n_b = len(data.probe), len(data.set_b)
    L = [f'# `{TRIMMED}`: بدون آموزش، به‌عنوان بردارساز، و با آموزش LoRA', '',
         'وزن اصلی مدل (بدون فشرده‌سازی)، اجرا روی پردازندهٔ GitHub Actions. '
         f'نمونهٔ آموزشی {len(data.examples)}، محک {n_p}، مجموعهٔ ب {n_b}؛ '
         'هیچ جملهٔ محک یا ب در آموزش نیست.', '', REFERENCE, '']
    if 'params' in R:
        L += [f"پارامتر (شمارشِ کتابخانه): {R['params']:.1f} میلیون."]
    if 'roundtrip' in R:
        s, back, n = R['roundtrip']
        L += [f'واژگانِ بریده‌شده و حروف لاتین: `{s}` → {n} توکن → `{back}` '
              f"({'سالم' if s == back else 'خراب'})."]
    if 'probe_tokens' in R:
        L += [f"میانگین توکنِ یک جملهٔ محک: {R['probe_tokens']:.1f} (Noql: 10.9)."]
    L += ['', '| روش | محک | ب | **جمع ۱۰۱** | توضیح |', '|---|---|---|---|---|']
    if 'zero_probe' in R and 'zero_b' in R:
        sec = sum(r['sec'] for r in R['zero_probe']) / n_p
        L.append(f"| بدون آموزش (دستور + JSON) | {count(R['zero_probe'])} | {count(R['zero_b'])} | "
                 f"**{count(R['zero_probe']) + count(R['zero_b'])}** | {sec:.1f} ثانیه برای هر پیام |")
    if 'tuned_probe' in R and 'tuned_b' in R:
        lg = R['lora']
        sec = sum(r['sec'] for r in R['tuned_probe']) / n_p
        L.append(f"| آموزش LoRA روی {len(data.examples)} نمونه | {count(R['tuned_probe'])} | "
                 f"{count(R['tuned_b'])} | **{count(R['tuned_probe']) + count(R['tuned_b'])}** | "
                 f"{lg.get('steps', 0)}/{lg.get('steps_total', 0)} گام در "
                 f"{lg.get('train_sec', 0) / 60:.0f} دقیقه؛ {sec:.1f} ثانیه برای هر پیام |")
    if 'lora' in R and R['lora'].get('loss'):
        lg = R['lora']
        L += ['', f"LoRA: {lg.get('lora_params', 0):.1f} میلیون پارامترِ آموزشی، "
              f"میانگین {lg.get('tokens_mean', 0):.0f} توکن در هر نمونه، خطای آموزش در هر دور: "
              + '، '.join(f'{v:.3f}' for v in lg['loss'])
              + ('؛ آموزش به سقف زمان خورد.' if lg.get('cut') else '.')]
    if 'neg' in R:
        items, pairs = neg_counts(R['neg'])
        L += ['', f'پرسش بله/خیر بدون آموزش: {items} از ۲۴ جمله درست؛ '
              f'**{pairs} از ۱۲ جفت** هر دو سویش درست.']
    L.append('')
    for title, key in (('بدون آموزش', 'zero_probe'), ('پس از LoRA', 'tuned_probe')):
        if key in R:
            L += [f'## خطاهای محک، {title} ({n_p - count(R[key])})', ''] + miss_lines(R[key]) + ['']
    if 'neg' in R:
        L += ['## پرسش‌های بله/خیر', ''] + neg_lines(R['neg']) + ['']
    for name, err in R['errors']:
        L += [f'## خطا در مرحلهٔ {name}', '', '```', err, '```', '']
    save(OUT_HF, L)


# --------------------------------------------------------------- مرحلهٔ extra
ORDERS = (('a', 'بله یا خیر'), ('b', 'خیر یا بله'))


def yn_orders(ask):
    """همان پرسش‌ها با هر دو ترتیبِ گزینه‌ها، با متنِ خامِ جواب."""
    rows = []
    for q, yes, no in NEG:
        for sent, gold in ((yes, 'y'), (no, 'n')):
            row = {'q': q, 's': sent, 'gold': gold}
            for key, tail in ORDERS:
                raw = ask(f'جمله: «{sent}»\nپرسش: {q}\nفقط با یک کلمه جواب بده: {tail}.')
                row[key] = (parse_yn(raw), raw.strip().replace('\n', ' ').replace('|', '/')[:30])
            rows.append(row)
            print('  yn', sent[:40], row['a'], row['b'], flush=True)
    return rows


def yn_counts(rows, key):
    ok = [r[key][0] == r['gold'] for r in rows]
    return sum(ok), sum(1 for i in range(0, len(ok), 2) if ok[i] and ok[i + 1])


def extra_stage(data):
    R = {'errors': []}

    def guard(name, fn):
        print('==', name, flush=True)
        try:
            fn()
        except Exception:  # noqa: BLE001
            traceback.print_exc()
            R['errors'].append((name, traceback.format_exc()[-1500:]))
        write_extra(data, R)

    if DRY:
        R['yn'] = yn_orders(lambda c, **kw: 'بله')
        R['feat'] = {}
        R['lora'] = {'loss': [1.0], 'steps': 1, 'steps_total': 1, 'train_sec': 60.0,
                     'curve': [(2, 5, 7)], 'lora_params': 5.0}
        write_extra(data, R)
        return

    def yn():
        ask, _, fname, _ = open_gguf(GGUF_FILES[1][1])
        R['yn_file'] = fname
        R['yn'] = yn_orders(lambda c: ask(c, max_tokens=12))

    guard('yes/no', yn)
    hf = Hf()

    def yn_hf():
        R['yn_hf'] = yn_orders(lambda c: hf.ask(c, max_new=12))

    def feats():
        from alt_bench import head_scores

        a = data.cut[0]
        R['feat'] = {}
        for key, m in hf.features_raw(data.texts, [14, 21, 28]).items():
            mu, sd = m[:a].mean(0), m[:a].std(0) + 1e-6
            R['feat'][key] = head_scores(data, unit((m - mu) / sd))

    def lora():
        log = {'curve': []}
        R['lora'] = log

        def on_epoch(ep):
            if ep % 2 == 0:
                p = count(tuned_eval(hf.classify, data.probe))
                b = count(tuned_eval(hf.classify, data.set_b))
                log['curve'].append((ep, p, b))
                print(f'  epoch {ep}: probe {p} b {b}', flush=True)
                write_extra(data, R)

        hf.train(data.examples, log, r=8, alpha=16, lr=1e-4, dropout=0.1, epochs=6,
                 on_epoch=on_epoch)

    guard('yes/no (trimmed)', yn_hf)
    guard('features', feats)
    guard('lora-b', lora)


def write_extra(data, R):
    n_p, n_b = len(data.probe), len(data.set_b)
    name = {'y': 'بله', 'n': 'خیر', '': '—'}
    L = ['# Qwen3-0.6B: وارسی‌های تکمیلی', '',
         'برای این‌که نتیجه‌های `qwen_gguf.md` و `qwen_tuned.md` به یک جمله‌بندی یا یک '
         'تنظیمِ آموزش وابسته نباشد.', '', REFERENCE, '']
    for key, title in (('yn', f"مدل اصلی، {R.get('yn_file', 'Q8_0')}"),
                       ('yn_hf', f'`{TRIMMED}`، وزن اصلی')):
        if key not in R:
            continue
        L += [f'## پرسش بله/خیر با هر دو ترتیبِ گزینه‌ها: {title}', '',
              '| ترتیب در دستور | جمله‌های درست (۲۴) | جفتِ کامل (۱۲) |', '|---|---|---|']
        for k, tail in ORDERS:
            items, pairs = yn_counts(R[key], k)
            L.append(f'| «{tail}» | {items} | **{pairs}** |')
        L += ['', '| جمله | باید | «بله یا خیر» | متن خام | «خیر یا بله» | متن خام |',
              '|---|---|---|---|---|---|']
        for r in R[key]:
            L.append(f"| {r['s']} | {name[r['gold']]} | {name[r['a'][0]]} | {r['a'][1]} "
                     f"| {name[r['b'][0]]} | {r['b'][1]} |")
        L.append('')
    if R.get('feat'):
        L += [f'## `{TRIMMED}` فقط به‌عنوان بردارساز', '',
              'بردارِ هر جمله از درونِ مدل (بدون آموزشِ مدل)، استانداردشده با میانگین و '
              'پراکندگیِ نمونه‌های آموزشی، سپس همان سرِ طبقه‌بندِ برنامه.', '',
              '| بردار | لایه | اعتبارسنجی (۲۵۰) | محک | ب | **جمع ۱۰۱** |', '|---|---|---|---|---|---|']
        pool = {'mean': 'میانگین توکن‌ها', 'last': 'آخرین توکن'}
        for (p, k), f in sorted(R['feat'].items()):
            L.append(f"| {pool[p]} | {k} | {f['cv']} | {f['probe']} | {f['b']} | "
                     f"**{f['probe'] + f['b']}** |")
        L.append('')
    if 'lora' in R:
        lg = R['lora']
        L += ['## آموزش LoRA، تنظیم دوم (آرام‌تر)', '',
              'r=8، نرخ یادگیری 1e-4، dropout 0.1، شش دور. تنظیم اول (r=16، 2e-4، چهار دور) '
              'در `qwen_tuned.md` به ۵۲ از ۱۰۱ رسید.', '',
              f'| پس از دور | محک ({n_p}) | ب ({n_b}) | **جمع** |', '|---|---|---|---|']
        for ep, p, b in lg.get('curve', []):
            L.append(f'| {ep} | {p} | {b} | **{p + b}** |')
        if lg.get('loss'):
            L += ['', 'خطای آموزش در هر دور: ' + '، '.join(f'{v:.3f}' for v in lg['loss'])
                  + f"؛ {lg.get('steps', 0)}/{lg.get('steps_total', 0)} گام در "
                  f"{lg.get('train_sec', 0) / 60:.0f} دقیقه (با زمانِ سنجش‌های میانی)"
                  + ('؛ به سقف زمان خورد.' if lg.get('cut') else '.')]
        L.append('')
    for nm, err in R['errors']:
        L += [f'## خطا در مرحلهٔ {nm}', '', '```', err, '```', '']
    save(OUT_EXTRA, L)


def save(path, lines):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')


def main():
    data = Data()
    stage = os.environ.get('STAGE', 'gguf')
    if stage == 'gguf':
        gguf_stage(data)
    elif stage == 'extra':
        extra_stage(data)
    else:
        hf_stage(data)


if __name__ == '__main__':
    main()

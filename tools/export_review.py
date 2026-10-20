import glob
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'docs', 'review_templates.txt')

TYPE_NAMES = {
    'text': 'متن کوتاه',
    'multiline': 'متن بلند',
    'number': 'عدد',
    'choice': 'انتخابی',
    'check': 'بله/خیر',
}

lines = []
count = 0
for p in sorted(glob.glob(os.path.join(ROOT, 'assets', 'templates', '*.json'))):
    with open(p, encoding='utf-8') as f:
        t = json.load(f)
    labels = {f['id']: f.get('label', f['id']) for f in t.get('fields', [])}
    count += 1
    lines.append('=' * 40)
    lines.append('قالب: %s' % t['title'])
    lines.append('فایل: %s' % os.path.basename(p))
    lines.append('وضعیت: %s' % ('بازبینی‌شده' if t.get('reviewed') else 'بازبینی‌نشده'))
    lines.append('کاربرد: %s' % t.get('description', ''))
    lines.append('')
    lines.append('نکته‌هایی که به کاربر نشان داده می‌شود:')
    for tip in t.get('tips', []):
        lines.append('- %s' % tip)
    lines.append('')
    lines.append('سؤال‌ها (به ترتیب):')
    for i, fl in enumerate(t.get('fields', []), 1):
        req = 'اجباری' if fl.get('required') else 'اختیاری'
        extra = ''
        if fl.get('options'):
            extra = ' | گزینه‌ها: ' + '، '.join(fl['options'])
        hint = (' | راهنما: ' + fl['hint']) if fl.get('hint') else ''
        lines.append('%d. %s [%s، %s]%s%s' % (
            i, fl.get('label', fl['id']), TYPE_NAMES.get(fl.get('type', 'text'), fl.get('type')), req, extra, hint))
    lines.append('')
    body = t['body']
    if isinstance(body, list):
        body = '\n'.join(str(x) for x in body)
    body = re.sub(r'\{\{\s*#if\s+(\w+)\s*\}\}',
                  lambda m: '[اگر «%s» پر شد: ' % labels.get(m.group(1), m.group(1)), body)
    body = re.sub(r'\{\{\s*else\s*\}\}', ' | در غیر این صورت: ', body)
    body = re.sub(r'\{\{\s*/if\s*\}\}', ']', body)
    body = re.sub(r'\{\{\s*(\w+)(?:\|\w+)?\s*\}\}',
                  lambda m: '«%s»' % labels.get(m.group(1), m.group(1)), body)
    lines.append('متن قالب (هر «...» جای پاسخ کاربر است):')
    lines.append(body)
    lines.append('')
    refs = t.get('lawRefs', [])
    lines.append('مواد قانونی مرتبط ثبت‌شده:')
    if not refs:
        lines.append('- هنوز ثبت نشده (کارشناس باید تعیین کند)')
    for r in refs:
        lines.append('- %s، ماده %s %s' % (r.get('law', ''), r.get('article', ''), r.get('note', '')))
    lines.append('')

with open(OUT, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines) + '\n')
print('%d قالب در %s نوشته شد' % (count, os.path.relpath(OUT, ROOT)))

import sys

if len(sys.argv) < 2:
    print('استفاده: python tools/paste_append.py FILE [--trim-last]')
    sys.exit(1)

path = sys.argv[1]
trim = '--trim-last' in sys.argv

try:
    text = open(path, encoding='utf-8', errors='replace').read()
except FileNotFoundError:
    text = ''

lines = text.rstrip().split('\n') if text.strip() else []
if trim and lines:
    removed = lines.pop()
    print('خط آخر حذف شد (ناقص بود): ' + removed[:60])

print('متن را بچسبانید. در پایان، در یک خط جدا بنویسید END و Enter بزنید.')
new = []
while True:
    try:
        line = input()
    except EOFError:
        break
    if line.strip() == 'END':
        break
    new.append(line)

long_lines = [l for l in new if len(l.encode('utf-8')) >= 3900]
if long_lines:
    print('هشدار: %d خط خیلی بلند بود و ممکن است ترمینال آن را بریده باشد.' % len(long_lines))

out = '\n'.join(lines)
if out:
    out += '\n\n'
out += '\n'.join(new).strip() + '\n'
with open(path, 'w', encoding='utf-8') as f:
    f.write(out)

print('اضافه شد: %d خط' % len(new))
tail = out.rstrip()[-80:]
print('پایان فایل: ...' + tail)
if tail and tail[-1] not in '.؛:)»!؟?':
    print('هشدار: آخر متن به علامت پایان نرسیده؛ احتمالاً هنوز ناقص است.')

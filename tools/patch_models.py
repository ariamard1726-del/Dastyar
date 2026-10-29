# tools/patch_models.py
# کلاس‌های داده (Chunk, Hit, RankResult, CatalogLaw) را از engine.dart
# به lib/models.dart می‌برد. رفتار برنامه تغییر نمی‌کند و importهای دیگر فایل‌ها
# هم سالم می‌مانند چون engine.dart همان‌ها را export می‌کند.
# اگر ریپو با انتظار نخواند، هیچ فایلی نوشته نمی‌شود.
import os
import re
import sys

P = 'lib/engine.dart'
M = 'lib/models.dart'
s = open(P, encoding='utf-8').read()

if os.path.exists(M) or "export 'models.dart';" in s:
    print('قبلاً اعمال شده است.')
    sys.exit(0)

START = 'class Chunk {\n'
END = 'class KnowledgeEngine {\n'
IMP = "import 'templates.dart' show TemplateRenderer;\n"
for m in (START, END, IMP):
    if s.count(m) != 1:
        print('خطا: بخش مورد انتظار پیدا نشد یا تکراری است:\n' + m)
        sys.exit(1)

a = s.index(START)
b = s.index(END)
if a >= b:
    print('خطا: ترتیب بخش‌ها با انتظار نمی‌خواند.')
    sys.exit(1)

block = s[a:b]
names = re.findall(r'^class (\w+)', block, re.M)
if names != ['Chunk', 'Hit', 'RankResult', 'CatalogLaw']:
    print('خطا: کلاس‌های پیدا شده با انتظار نمی‌خواند: %s' % names)
    sys.exit(1)

models = "import 'engine.dart' show KnowledgeEngine;\n\n" + block.rstrip() + '\n'
new = s[:a] + s[b:]
new = new.replace(IMP, IMP + "import 'models.dart';\n\nexport 'models.dart';\n", 1)

open(M, 'w', encoding='utf-8').write(models)
open(P, 'w', encoding='utf-8').write(new)
print('انجام شد: lib/models.dart ساخته شد.')

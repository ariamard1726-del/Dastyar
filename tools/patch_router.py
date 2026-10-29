# tools/patch_router.py
# تشخیص دو قصد ثابت («دستیار چه می‌کند؟» و «پیش‌بینی حکم») و متن پاسخ‌هایشان را
# از engine.dart به lib/router.dart می‌برد. رفتار برنامه تغییر نمی‌کند.
# اگر ریپو با انتظار نخواند، هیچ فایلی نوشته نمی‌شود.
import os
import sys

P = 'lib/engine.dart'
R = 'lib/router.dart'
s = open(P, encoding='utf-8').read()

if os.path.exists(R) or 'QueryRouter.' in s:
    print('قبلاً اعمال شده است.')
    sys.exit(0)

START = '  bool _asksAssistantCapabilities(String n) {\n'
END = '  String answer(String question) {\n'
IMP = "import 'models.dart';\n"
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
RENAMES = [
    ('  bool _asksAssistantCapabilities(String n) {', '  static bool asksCapabilities(String n) {'),
    ('  bool _asksOutcomePrediction(String n) {', '  static bool asksOutcomePrediction(String n) {'),
    ('  String _assistantCapabilitiesText() {', '  static String capabilitiesText() {'),
    ('  String _outcomePredictionText() {', '  static String outcomeText() {'),
]
for old, _ in RENAMES:
    if block.count(old) != 1:
        print('خطا: متد مورد انتظار پیدا نشد:\n' + old)
        sys.exit(1)
if block.count('\n  String ') + block.count('\n  bool ') != 3:
    print('خطا: تعداد متدهای داخل بخش با انتظار نمی‌خواند.')
    sys.exit(1)

CALLS = [
    ('_asksAssistantCapabilities(n)', 'QueryRouter.asksCapabilities(n)'),
    ('_asksOutcomePrediction(n)', 'QueryRouter.asksOutcomePrediction(n)'),
    ('_assistantCapabilitiesText()', 'QueryRouter.capabilitiesText()'),
    ('_outcomePredictionText()', 'QueryRouter.outcomeText()'),
]
rest = s[:a] + s[b:]
for old, _ in CALLS:
    if rest.count(old) != 1:
        print('خطا: محل فراخوانی مورد انتظار پیدا نشد:\n' + old)
        sys.exit(1)

body = block
for old, new in RENAMES:
    body = body.replace(old, new)
router = (
    '/// تشخیص قصدهای ثابت پرسش و متن پاسخ آن‌ها.\n'
    '/// (فعلاً فقط دو قصد؛ قصدهای دیگر در قدم‌های بعد به اینجا می‌آیند.)\n'
    'class QueryRouter {\n'
    '  QueryRouter._();\n\n'
    + body.rstrip() + '\n}\n'
)

new = rest
for old, nw in CALLS:
    new = new.replace(old, nw)
new = new.replace(IMP, IMP + "import 'router.dart';\n", 1)

open(R, 'w', encoding='utf-8').write(router)
open(P, 'w', encoding='utf-8').write(new)
print('انجام شد: lib/router.dart ساخته شد.')

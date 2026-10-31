# tools/patch_feedback.py
# دکمه‌های 👍/👎 را زیر پاسخ‌های عادی دستیار در chat_page.dart می‌گذارد.
# فقط پیام‌های غیرحساس (نه پرونده و پیش‌نویس) نظر می‌گیرند.
# اگر ریپو با انتظار نخواند، هیچ چیز نوشته نمی‌شود.
import sys

P = 'lib/chat_page.dart'
s = open(P, encoding='utf-8').read()

if 'FeedbackBar(' in s:
    print('قبلاً اعمال شده است.')
    sys.exit(0)

EDITS = [
    ("import 'engine.dart';\n",
     "import 'engine.dart';\nimport 'feedback.dart';\n"),
    ("  Widget _botText(_Msg m) {\n    final canAct = !m.sensitive && m.text != '...';\n",
     "  Widget _botText(_Msg m) {\n    final canAct = !m.sensitive && m.text != '...';\n"
     "    final qi = _msgs.indexOf(m);\n"
     "    final question =\n"
     "        (qi > 0 && _msgs[qi - 1].fromUser) ? _msgs[qi - 1].text : '';\n"),
    ("                  onPressed: () => _share(m.text),\n                ),\n              ],\n",
     "                  onPressed: () => _share(m.text),\n                ),\n"
     "                FeedbackBar(question: question, answer: m.text),\n              ],\n"),
]
for old, _ in EDITS:
    if s.count(old) != 1:
        print('خطا: بخش مورد انتظار پیدا نشد یا تکراری است:\n' + old)
        sys.exit(1)
for old, new in EDITS:
    s = s.replace(old, new, 1)
open(P, 'w', encoding='utf-8').write(s)
print('انجام شد: دکمه‌های نظر به chat_page.dart اضافه شد.')

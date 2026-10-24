import re, sys
p = sys.argv[1] if len(sys.argv) > 1 else 'assets/laws/civil.txt'
t = open(p, encoding='utf-8').read()
tr = str.maketrans('۰۱۲۳۴۵۶۷۸۹', '0123456789')
pat = re.compile(r'^ماده\s*([\d۰-۹]+)\s*\(\s*مکرر\s*\)\s*[-–—ـ]\s*(.+)$', re.M)
def fix(m):
    return 'ماده %s مکرر\n%s' % (m.group(1).translate(tr), m.group(2).strip())
new, n = pat.subn(fix, t)
open(p, 'w', encoding='utf-8').write(new)
print('اصلاح شد: %d ماده' % n)

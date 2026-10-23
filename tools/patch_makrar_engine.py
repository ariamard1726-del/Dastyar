p = 'lib/engine.dart'
s = open(p, encoding='utf-8').read()

old_re = "RegExp(r'ماده\\s*(\\d+)')"
new_re = "RegExp(r'ماده\\s*(\\d+)(\\s*مکرر)?')"
assert s.count(old_re) == 2, 'regex count: %d' % s.count(old_re)
s = s.replace(old_re, new_re)

old_w = "final want = 'ماده ${art.group(1)}';"
new_w = "final want =\n          'ماده ${art.group(1)}${art.group(2) != null ? ' مکرر' : ''}';"
assert s.count(old_w) == 1, 'want count'
s = s.replace(old_w, new_w)

old_n = "final num = TemplateRenderer.toFa(art.group(1)!);"
new_n = ("final num = TemplateRenderer.toFa(art.group(1)!) +\n"
         "          (art.group(2) != null ? ' مکرر' : '');")
assert s.count(old_n) == 1, 'num count'
s = s.replace(old_n, new_n)

open(p, 'w', encoding='utf-8').write(s)
print('انجام شد: ۴ تغییر در lib/engine.dart')

import os, re, sys
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(R, 'pubspec.yaml')
L = open(P, encoding='utf-8').read().split('\n')
ents = [m.group(1) for l in L for m in [re.match(r'^    - (\S+)\s*$', l)] if m]
files = {e for e in ents if not e.endswith('/')}
need = []
for d, _, fs in os.walk(os.path.join(R, 'assets')):
    rel = os.path.relpath(d, R).replace(os.sep, '/')
    if fs and not all(rel + '/' + x in files for x in fs):
        need.append(rel + '/')
need.sort()
miss = [d for d in need if d not in ents]
if not miss:
    print('assets OK:', len(need), 'folders')
    sys.exit(0)
print('NOT bundled:', *miss, sep='\n  ')
if '--fix' not in sys.argv:
    sys.exit(1)
out, skip = [], False
for l in L:
    if skip and re.match(r'^    - ', l):
        continue
    skip = False
    out.append(l)
    if re.match(r'^  assets:\s*$', l):
        out += ['    - ' + e for e in sorted(files)] + ['    - ' + d for d in need]
        skip = True
open(P, 'w', encoding='utf-8').write('\n'.join(out))
print('fixed')

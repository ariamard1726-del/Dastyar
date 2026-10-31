import json, subprocess, sys, time, urllib.request

REPO = 'ariamard1726-del/Dastyar'


def sh(cmd, check=True):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and r.returncode != 0:
        print(r.stdout + r.stderr)
        sys.exit(1)
    return r.stdout.strip()


def api(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'dastyar-go'})
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)


def show_report(sha):
    for _ in range(8):
        sh('git pull --rebase -q', check=False)
        try:
            txt = open('reports/last_test.txt', encoding='utf-8').read()
        except OSError:
            txt = ''
        if txt.startswith('commit: ' + sha[:7]):
            print(txt)
            return
        time.sleep(10)
    print('گزارش این کامیت هنوز نیامده؛ بعداً: python tools/go.py report')


def main():
    args = sys.argv[1:]
    if args and args[0] == 'report':
        sh('git pull --rebase -q', check=False)
        print(open('reports/last_test.txt', encoding='utf-8').read())
        return
    msg = args[0] if args else 'update'
    if sh('git status --porcelain'):
        sh('git add -A')
        print(sh('git diff --cached --stat'))
        subprocess.run(['git', 'commit', '-q', '-m', msg], check=True)
    sh('git pull --rebase -q')
    sha = sh('git rev-parse HEAD')
    sh('git push -q')
    print('push شد:', sha[:7], '- منتظر نتیجهٔ Test ...')
    url = ('https://api.github.com/repos/%s/actions/runs?head_sha=%s'
           '&per_page=10' % (REPO, sha))
    end = time.time() + 900
    run = None
    while time.time() < end:
        try:
            runs = [r for r in api(url)['workflow_runs']
                    if r['name'] == 'Test']
        except Exception:
            runs = []
        if runs and runs[0]['status'] == 'completed':
            run = runs[0]
            break
        time.sleep(20)
    print('نتیجه:', run['conclusion'] if run else 'هنوز تمام نشده')
    show_report(sha)


main()

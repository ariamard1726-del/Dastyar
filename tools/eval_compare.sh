#!/data/data/com.termux/files/usr/bin/bash
cd ~/Dastyar || exit 1
git pull -q --rebase
AFTER=$(git rev-parse "${2:-HEAD}")
if [ -n "$1" ]; then
  BEFORE=$(git rev-parse "$1")
else
  H=$(git log --format=%H --grep="restore text layer" -n 1)
  BEFORE=$(git rev-parse "$H~1")
fi
echo "before: ${BEFORE:0:7}  after: ${AFTER:0:7}"
[ "$BEFORE" = "$AFTER" ] && echo "هشدار: قبل و بعد یکی‌اند؛ مثلاً HEAD~1 بدهید."

run_eval() {
  gh workflow run eval.yml -f ref="$1" >/dev/null || return 1
  sleep 15
  ID=$(gh run list --workflow=eval.yml --limit 1 --json databaseId -q '.[0].databaseId')
  gh run watch "$ID" >/dev/null 2>&1
  D=~/dastyar_eval/$2
  rm -rf "$D"; mkdir -p "$D"
  for i in 1 2 3; do
    gh run download "$ID" -n eval-report -D "$D" >/dev/null 2>&1 && break
    sleep 5
  done
}

run_eval "$BEFORE" before
run_eval "$AFTER" after

pick() { grep -E '^(EVAL|EXTRA)' "$1" | grep -v 'scores:' | sort; }
echo "=== خلاصه (قبل) ==="
grep -E 'recall@1|accuracy' ~/dastyar_eval/before/eval.txt | cut -c1-120
echo "=== خلاصه (بعد) ==="
grep -E 'recall@1|accuracy' ~/dastyar_eval/after/eval.txt | cut -c1-120
echo "=== تفاوت (فقط خط‌های تغییرکرده) ==="
diff <(pick ~/dastyar_eval/before/eval.txt) <(pick ~/dastyar_eval/after/eval.txt) | cut -c1-150
echo "=== analyze (بعد) ==="
tail -n 2 ~/dastyar_eval/after/analyze.txt

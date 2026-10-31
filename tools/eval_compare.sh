#!/data/data/com.termux/files/usr/bin/bash
cd ~/Dastyar || exit 1
git pull -q --rebase
AFTER=${2:-$(git rev-parse HEAD)}
if [ -n "$1" ]; then
  BEFORE="$1"
else
  H=$(git log --format=%H --grep="restore text layer" -n 1)
  BEFORE=$(git rev-parse "$H~1")
fi
echo "before: ${BEFORE:0:7}  after: ${AFTER:0:7}"

run_eval() {
  gh workflow run eval.yml -f ref="$1" || return 1
  sleep 15
  ID=$(gh run list --workflow=eval.yml --limit 1 --json databaseId -q '.[0].databaseId')
  gh run watch "$ID" >/dev/null 2>&1
  D=~/dastyar_eval/$2
  rm -rf "$D"; mkdir -p "$D"
  for i in 1 2 3; do
    gh run download "$ID" -n eval-report -D "$D" && break
    sleep 5
  done
}

run_eval "$BEFORE" before
run_eval "$AFTER" after
echo "=== بعد: خطوط EVAL ==="; cut -c1-160 ~/dastyar_eval/after/eval.txt
echo "=== تفاوت قبل ← بعد ==="; diff ~/dastyar_eval/before/eval.txt ~/dastyar_eval/after/eval.txt | cut -c1-160
echo "=== analyze (بعد) ==="; cat ~/dastyar_eval/after/analyze.txt

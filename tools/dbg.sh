#!/data/data/com.termux/files/usr/bin/bash
cd ~/Dastyar || exit 1
git pull -q --rebase
echo "=== مادهٔ مورد انتظار (از brain/eval.txt) ==="
grep -E "چک برگشتی چه مجازاتی|چک بی.*محل چه مجازاتی" brain/eval.txt | cut -c1-150
gh workflow run eval.yml -f ref="$(git rev-parse HEAD)" >/dev/null || exit 1
sleep 15
ID=$(gh run list --workflow=eval.yml --limit 1 --json databaseId -q '.[0].databaseId')
gh run watch "$ID" >/dev/null 2>&1
D=~/dastyar_eval/dbg
rm -rf "$D"; mkdir -p "$D"
for i in 1 2 3; do
  gh run download "$ID" -n eval-report -D "$D" >/dev/null 2>&1 && break
  sleep 5
done
echo "=== نتایج اول ==="
grep DBG "$D/eval.txt" | cut -c1-160

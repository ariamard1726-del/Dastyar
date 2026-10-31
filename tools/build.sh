#!/data/data/com.termux/files/usr/bin/bash
cd ~/Dastyar || exit 1
git pull -q --rebase
gh workflow run build.yml || exit 1
echo "منتظر شروع ساخت ..."
sleep 10
ID=$(gh run list --workflow=build.yml --limit 1 --json databaseId -q '.[0].databaseId')
echo "run: $ID (چند دقیقه طول می‌کشد)"
gh run watch "$ID" >/dev/null 2>&1
CONC=$(gh run view "$ID" --json conclusion -q .conclusion)
echo "نتیجه: $CONC"
if [ "$CONC" != "success" ]; then
  gh run view "$ID" --log-failed | tr -d '\r' | cut -f3- | cut -c1-200 | tail -n 40
else
  echo "--- هشدارهای analyze (حداکثر ۳۰) ---"
  gh run view "$ID" --log | tr -d '\r' | cut -f3- | grep -E " (info|warning|error) • " | cut -c1-200 | head -n 30
  if [ -d ~/storage/downloads ]; then
    gh run download "$ID" -n dastyar-apk -D ~/storage/downloads/dastyar && echo "APK در Downloads/dastyar است"
  else
    echo "برای دانلود خودکار APK یک بار termux-setup-storage بزنید."
  fi
fi

#!/data/data/com.termux/files/usr/bin/bash
cd ~/Dastyar || exit 1

if [ "$1" = "last" ]; then
  ID=$(gh run list --workflow=build.yml --limit 1 --json databaseId -q '.[0].databaseId')
  echo "آخرین ساخت: $ID"
else
  git pull -q --rebase
  gh workflow run build.yml || exit 1
  echo "منتظر شروع ساخت ..."
  sleep 10
  ID=$(gh run list --workflow=build.yml --limit 1 --json databaseId -q '.[0].databaseId')
  echo "run: $ID (چند دقیقه طول می‌کشد)"
  gh run watch "$ID" >/dev/null 2>&1
fi

CONC=$(gh run view "$ID" --json conclusion -q .conclusion)
echo "نتیجه: $CONC"

LOG=~/dastyar_run_log.txt
rm -f "$LOG"
for i in 1 2 3 4; do
  if [ "$CONC" = "success" ]; then
    gh run view "$ID" --log > "$LOG" 2>/dev/null
  else
    gh run view "$ID" --log-failed > "$LOG" 2>/dev/null
  fi
  [ -s "$LOG" ] && break
  echo "لاگ نیامد، تلاش مجدد ($i) ..."
  sleep 5
done

if [ "$CONC" != "success" ]; then
  [ -s "$LOG" ] && tr -d '\r' < "$LOG" | cut -f3- | cut -c1-200 | tail -n 40
else
  echo "--- هشدارهای analyze (حداکثر ۳۰) ---"
  if [ -s "$LOG" ]; then
    tr -d '\r' < "$LOG" | cut -f3- | grep -E " (info|warning|error) • " | cut -c1-200 | head -n 30
  else
    echo "لاگ در دسترس نبود؛ چند دقیقه بعد: bash tools/build.sh last"
  fi
  if [ -d ~/storage/downloads ]; then
    DEST=~/storage/downloads/dastyar
  else
    DEST=~/dastyar_apk
  fi
  mkdir -p "$DEST"
  rm -f "$DEST/app-release.apk"
  gh run download "$ID" -n dastyar-apk -D "$DEST" && echo "APK: $DEST/app-release.apk"
fi

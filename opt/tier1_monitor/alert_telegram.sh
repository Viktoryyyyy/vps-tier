#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${LOG_FILE:-/var/log/tier1_health.log}"
STATE_DIR="${STATE_DIR:-/var/lib/tier1_monitor}"
STATE_FILE="$STATE_DIR/last_alert.key"

: "${TG_BOT_TOKEN:?TG_BOT_TOKEN is required}"
: "${TG_CHAT_ID:?TG_CHAT_ID is required}"

mkdir -p "$STATE_DIR"

line="$(tail -n 1 "$LOG_FILE" 2>/dev/null || true)"
if [ -z "$line" ]; then
  exit 0
fi

status="$(printf '%s\n' "$line" | sed -n 's/.* status=\([^ ]*\).*/\1/p')"
if [ "$status" != "CRIT" ]; then
  exit 0
fi

key="$(printf '%s' "$line" | sha256sum | awk '{print $1}')"
last_key=""
if [ -f "$STATE_FILE" ]; then
  last_key="$(cat "$STATE_FILE" 2>/dev/null || true)"
fi
if [ "$key" = "$last_key" ]; then
  exit 0
fi

msg="Tier-1 CRIT
$(hostname)
$line"

curl -fsS -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
  -d "chat_id=${TG_CHAT_ID}" \
  --data-urlencode "text=${msg}" \
  -d "disable_web_page_preview=true" \
  -d "parse_mode=HTML" >/dev/null

printf '%s\n' "$key" > "$STATE_FILE"

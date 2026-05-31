# shellcheck shell=sh
# Common utilities + Telegram send helpers

getprop_safe() { getprop "$1" 2>/dev/null || echo ""; }

BOT_API="https://api.telegram.org/bot${TELEGRAM_TOKEN}"

send_msg() {
  text="$1"
  [ -z "$TELEGRAM_TOKEN" ] && { echo "TELEGRAM_TOKEN is not configured"; return; }
  [ -z "$TELEGRAM_CHAT_ID" ] && { echo "TELEGRAM_CHAT_ID is not configured"; return; }

  curl -s "${BOT_API}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "parse_mode=HTML" \
    --data-urlencode "text=${text}" >/dev/null 2>&1
}

send_code() {
  raw="$1"
  text="$(printf '%b' "$raw")"
  send_msg "$text"
}

send_photo() {
  path="$1"
  caption="${2:-}"
  [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ] && return 1
  [ -f "$path" ] || return 1
  if [ -n "$caption" ]; then
    curl -s --max-time 60 -X POST "${BOT_API}/sendPhoto" \
      -F "chat_id=${TELEGRAM_CHAT_ID}" \
      -F "photo=@${path}" \
      -F "caption=${caption}" >/dev/null 2>&1
  else
    curl -s --max-time 60 -X POST "${BOT_API}/sendPhoto" \
      -F "chat_id=${TELEGRAM_CHAT_ID}" \
      -F "photo=@${path}" >/dev/null 2>&1
  fi
}

escape_html() {
  echo "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

has_network() {
  curl -s --max-time 5 "${BOT_API}/getMe" | grep -q '"ok":true'
}

TG_BOOT_GRACE_SEC="${TG_BOOT_GRACE_SEC:-180}"

tg_uptime_sec() {
  awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0
}

tg_boot_grace_ok() {
  up="$(tg_uptime_sec)"
  [ -n "$up" ] && [ "$up" -ge "$TG_BOOT_GRACE_SEC" ] 2>/dev/null
}

tg_chat_allowed() {
  cid="$1"
  [ -z "$TELEGRAM_CHAT_ID" ] && return 0
  [ -z "$cid" ] && return 0
  [ "$cid" = "$TELEGRAM_CHAT_ID" ]
}

tg_drain_pending_updates() {
  offset="${1:-0}"
  offset_file="${2:-/data/local/tmp/tg_device_bot_offset}"
  [ -z "$TELEGRAM_TOKEN" ] && return 0

  while true; do
    resp="$(curl -s --max-time 30 "${BOT_API}/getUpdates?timeout=0&offset=${offset}&limit=100")"
    last="$(echo "$resp" | grep -o '"update_id":[0-9]*' | awk -F: '{print $2}' | sort -n | tail -n1)"
    [ -z "$last" ] && break
    offset=$((last + 1))
    echo "$offset" > "$offset_file"
  done
}

tg_wait_for_boot() {
  i=0
  while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
    sleep 3
    i=$((i + 1))
    [ "$i" -ge 120 ] && break
  done
  sleep 5
}


#!/system/bin/sh
# Telegram bot to control device
#
# Magisk late_start runs during boot animation. Exit immediately and run all work in a
# background process — otherwise blocking on boot_completed/curl can trigger boot watchdog reboots.

TG_SERVICE_LOG="/data/local/tmp/tg_device_bot.log"
TG_SERVICE_PID_FILE="/data/local/tmp/tg_device_bot_service.pid"

if [ -z "$TG_SERVICE_DAEMON" ]; then
  export TG_SERVICE_DAEMON=1
  nohup sh "$0" >>"$TG_SERVICE_LOG" 2>&1 &
  exit 0
fi

if [ -f "$TG_SERVICE_PID_FILE" ]; then
  _tg_old_pid="$(cat "$TG_SERVICE_PID_FILE" 2>/dev/null)"
  if [ -n "$_tg_old_pid" ] && kill -0 "$_tg_old_pid" 2>/dev/null; then
    exit 0
  fi
fi
echo $$ >"$TG_SERVICE_PID_FILE"

TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID=""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck disable=SC1091
[ -f "${SCRIPT_DIR}/config.sh" ] && . "${SCRIPT_DIR}/config.sh"

# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/bot_commands.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/battery.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/telephony.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/usb_wifi.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/wifi_bt.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/netstats.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/sms.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/check_sms_watch.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/status.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/dev_cmds.sh"
# shellcheck source=/dev/null
[ -f "${SCRIPT_DIR}/lib/dev_help.sh" ] && . "${SCRIPT_DIR}/lib/dev_help.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/handlers.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/loop.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/monitor.sh"
# shellcheck source=/dev/null
[ -f "${SCRIPT_DIR}/lib/anydesk.sh" ] && . "${SCRIPT_DIR}/lib/anydesk.sh"

BOT_OFFSET_FILE="/data/local/tmp/tg_device_bot_offset"
LOOP_PID_FILE="/data/local/tmp/tg_device_bot_loop_pids"

tg_wait_for_boot

start_anydesk_auto_media_loop || true

# /loop_on processes do not survive service reboot; clear old PID list to avoid killing wrong processes.
rm -f "$LOOP_PID_FILE" 2>/dev/null || true

if [ -f "$BOT_OFFSET_FILE" ]; then
  OFFSET="$(cat "$BOT_OFFSET_FILE" 2>/dev/null || echo 0)"
else
  OFFSET=0
fi

tg_drain_pending_updates "$OFFSET" "$BOT_OFFSET_FILE"
OFFSET="$(cat "$BOT_OFFSET_FILE" 2>/dev/null || echo "$OFFSET")"

if [ -n "$TELEGRAM_CHAT_ID" ] && [ -n "$TELEGRAM_TOKEN" ]; then
  send_code "🤖 Telegram Device Bot started. Type /help to see commands."
fi

(handle_monitor_changes >/dev/null 2>&1 &)

(
  for i in $(seq 1 120); do
    if has_network; then
      tg_sync_my_commands
      handle_status_on_boot
      start_sms_inbox_watch_auto
      exit 0
    fi
    sleep 5
  done
) &

(
  tg_wait_for_boot
  sleep 20
  start_sms_inbox_watch_auto
) >/dev/null 2>&1 &

while true; do
  [ -z "$TELEGRAM_TOKEN" ] && { echo "⚠️ Missing TELEGRAM_TOKEN, exiting."; exit 1; }

  RESP="$(curl -s "${BOT_API}/getUpdates?timeout=25&offset=${OFFSET}")"
  LAST_UPDATE_ID="$(echo "$RESP" | grep -o '"update_id":[0-9]*' | awk -F: '{print $2}' | sort -n | tail -n1)"

  if [ -n "$LAST_UPDATE_ID" ]; then
    OFFSET=$((LAST_UPDATE_ID + 1))
    echo "$OFFSET" > "$BOT_OFFSET_FILE"

    TEXT="$(echo "$RESP" | grep -o '"text":"[^"]*"' | sed 's/^"text":"//;s/"$//' | tail -n1)"
    CID="$(echo "$RESP" | grep -o '"chat":{"id":[-0-9]*' | sed 's/.*"id"://' | tail -n1)"

    dispatch_command "$TEXT" "$CID"
  fi

  [ -z "$RESP" ] && sleep 5
done

#!/system/bin/sh
# Bot Telegram điều khiển thiết bị — bản gốc (tính năng + thông báo như old/)
#
# Magisk late_start chạy service.sh trong lúc còn boot logo. Phải thoát ngay và chạy
# toàn bộ logic trong tiến trình nền — nếu không, chờ boot_completed/curl có thể kích
# watchdog và reboot 2–3 lần trước khi vào OS.

TG_SERVICE_LOG="/data/local/tmp/tg_device_bot.log"
TG_SERVICE_PID_FILE="/data/local/tmp/tg_device_bot_service.pid"

if [ -z "$TG_SERVICE_DAEMON" ]; then
  export TG_SERVICE_DAEMON=1
  nohup sh "$0" >>"$TG_SERVICE_LOG" 2>&1 &
  exit 0
fi

# Tránh hai instance khi Magisk gọi lại service.sh
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
. "${SCRIPT_DIR}/lib/handlers.sh"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/lib/status.sh"
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

# Tiến trình /loop_on không sống sót qua khởi động lại service; xóa PID cũ tránh kill nhầm.
rm -f "$LOOP_PID_FILE" 2>/dev/null || true
rm -f "$CHECK_SMS_WATCH_PID_FILE" 2>/dev/null || true

if [ -f "$BOT_OFFSET_FILE" ]; then
  OFFSET="$(cat "$BOT_OFFSET_FILE" 2>/dev/null || echo 0)"
else
  OFFSET=0
fi

# Bỏ hàng đợi cũ (vd. /restart spam) — không thực thi lệnh trong backlog.
tg_drain_pending_updates "$OFFSET" "$BOT_OFFSET_FILE"
OFFSET="$(cat "$BOT_OFFSET_FILE" 2>/dev/null || echo "$OFFSET")"

if [ -n "$TELEGRAM_CHAT_ID" ] && [ -n "$TELEGRAM_TOKEN" ]; then
  send_code "🤖 Telegram Device Bot đã khởi động. Gõ /help để xem lệnh."
fi

(handle_monitor_changes >/dev/null 2>&1 &)

(
  for i in $(seq 1 120); do
    if has_network; then
      tg_sync_my_commands
      handle_status_on_boot
      exit 0
    fi
    sleep 5
  done
) &

while true; do
  [ -z "$TELEGRAM_TOKEN" ] && { echo "⚠️ Thiếu TELEGRAM_TOKEN, thoát."; exit 1; }

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

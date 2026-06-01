# shellcheck shell=sh
# Đồng bộ menu lệnh Telegram (setMyCommands) khi có internet.
# TELEGRAM_TOKEN từ config.sh (service.sh nạp config trước khi . lib này).
# Menu chính — lệnh /dev gõ tay hoặc xem qua /dev (không liệt kê hết trong menu).

TG_BOT_COMMANDS_CACHE="/data/local/tmp/tg_bot_commands.cache"

tg_bot_commands_cache_key() {
  json="$(tg_bot_commands_json | tr -d '\n')"
  printf '%s\n%s' "$TELEGRAM_TOKEN" "$json"
}

tg_bot_commands_json() {
  cat <<'EOF'
[{"command":"start","description":"Khởi động bot · danh sách lệnh"},{"command":"help","description":"Hiển thị danh sách lệnh"},{"command":"dev","description":"Lệnh nâng cao: mạng, màn hình, SMS watch…"},{"command":"status","description":"Thông tin cơ bản thiết bị"},{"command":"signal","description":"Báo cáo mạng: RAT, băng tần, RSRP"},{"command":"ip","description":"IPv4/IPv6 cục bộ và IP WAN"},{"command":"ping","description":"Ping (mặc định 1.1.1.1)"},{"command":"battery","description":"Thông tin pin hiện tại"},{"command":"datausage","description":"Dung lượng data đã dùng"},{"command":"sms","description":"SMS gần nhất trong inbox"},{"command":"sentsms","description":"Gửi SMS: sentsms SĐT nội_dung"},{"command":"shutdown","description":"Tắt máy"},{"command":"restart","description":"Khởi động lại"}]
EOF
}

tg_sync_my_commands() {
  [ -z "$TELEGRAM_TOKEN" ] && return 0

  json="$(tg_bot_commands_json | tr -d '\n')"
  [ -z "$json" ] && return 0

  cache_key="$(tg_bot_commands_cache_key)"
  if [ -f "$TG_BOT_COMMANDS_CACHE" ]; then
    cached="$(cat "$TG_BOT_COMMANDS_CACHE" 2>/dev/null)"
    [ "$cached" = "$cache_key" ] && return 0
  fi

  has_network || return 0

  api="https://api.telegram.org/bot${TELEGRAM_TOKEN}"
  resp="$(curl -s --max-time 15 "${api}/setMyCommands" \
    --data-urlencode "commands=${json}")"

  if echo "$resp" | grep -q '"ok":true'; then
    printf '%s' "$cache_key" >"$TG_BOT_COMMANDS_CACHE"
  fi
}

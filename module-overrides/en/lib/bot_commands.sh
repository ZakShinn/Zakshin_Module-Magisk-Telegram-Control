# shellcheck shell=sh
# Sync Telegram command menu (setMyCommands) when online.

TG_BOT_COMMANDS_CACHE="/data/local/tmp/tg_bot_commands.cache"

tg_bot_commands_cache_key() {
  json="$(tg_bot_commands_json | tr -d '\n')"
  printf '%s\n%s' "$TELEGRAM_TOKEN" "$json"
}

tg_bot_commands_json() {
  cat <<'EOF'
[{"command":"start","description":"Start bot · command list"},{"command":"help","description":"Show command list"},{"command":"dev","description":"Advanced: network, display, apps, USB…"},{"command":"status","description":"Basic device status"},{"command":"signal","description":"Cellular: RAT, band, RSRP"},{"command":"ip","description":"Local IPv4/IPv6 and WAN IP"},{"command":"ping","description":"Ping (default 1.1.1.1)"},{"command":"battery","description":"Current battery info"},{"command":"datausage","description":"Realtime data usage"},{"command":"sms","description":"Latest inbox SMS"},{"command":"shutdown","description":"Power off"},{"command":"restart","description":"Reboot device"}]
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

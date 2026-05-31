# shellcheck shell=sh
# Sync Telegram command menu (setMyCommands) when online.
# TELEGRAM_TOKEN comes from config.sh (loaded by service.sh before this lib).

TG_BOT_COMMANDS_CACHE="/data/local/tmp/tg_bot_commands.cache"

tg_bot_commands_cache_key() {
  json="$(tg_bot_commands_json | tr -d '\n')"
  printf '%s\n%s' "$TELEGRAM_TOKEN" "$json"
}

tg_bot_commands_json() {
  cat <<'EOF'
[{"command":"start","description":"Start bot · command list"},{"command":"help","description":"Show command list"},{"command":"dev","description":"Experimental: wifi, bt, loop, sms_watch"},{"command":"status","description":"Basic device status"},{"command":"signal","description":"Cellular: RAT, band, RSRP"},{"command":"ip","description":"Local IPv4/IPv6 and WAN IP"},{"command":"ping","description":"Ping (default 1.1.1.1)"},{"command":"battery","description":"Current battery info"},{"command":"datausage","description":"Realtime data usage"},{"command":"sms","description":"Latest inbox SMS"},{"command":"rndis_on","description":"Enable USB tether (RNDIS)"},{"command":"rndis_off","description":"Disable USB tether (RNDIS)"},{"command":"hotspot_on","description":"Enable Wi‑Fi hotspot"},{"command":"hotspot_off","description":"Disable hotspot"},{"command":"shutdown","description":"Power off"},{"command":"restart","description":"Reboot device"},{"command":"wifi_on","description":"Enable Wi‑Fi (experimental)"},{"command":"wifi_off","description":"Disable Wi‑Fi (experimental)"},{"command":"bt_on","description":"Enable Bluetooth (experimental)"},{"command":"bt_off","description":"Disable Bluetooth (experimental)"},{"command":"loop_on","description":"Repeat command every N minutes"},{"command":"loop_off","description":"Stop background loops"}]
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

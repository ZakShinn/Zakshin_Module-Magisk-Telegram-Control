# shellcheck shell=sh
# Telegram command handlers

handle_help() {
  msg="$(cat <<'EOF'
<b>Commands:</b>

/help                 - Show command list
/dev                  - Experimental commands (wifi/bt/loop)
/status               - Basic device status
/signal               - Cellular report: RAT, band, RSRP/RSRQ/SINR, roaming
/ip                   - Local IPv4/IPv6 + public WAN IP
/ping [target]        - Ping (default 1.1.1.1) · e.g. <code>/ping 8.8.8.8</code>
/battery              - Current battery info
/datausage            - Realtime interface traffic totals
/sms [count]          - Latest inbox SMS (default 1; e.g. <code>/sms 5</code>)

/rndis_on             - Enable RNDIS (USB tether)
/rndis_off            - Disable RNDIS (USB tether)
/hotspot_on [SSID PASS] - Enable hotspot (defaults from config)
/hotspot_off          - Disable hotspot

/shutdown             - Power off
/restart              - Reboot
<i>Do not spam /shutdown or /restart — queued requests can cause repeated power cycles.</i>
EOF
)"
  send_code "$msg"
}

handle_dev() {
  msg="$(cat <<'EOF'
<b>Experimental (/dev):</b>
<i>Experimental features may change or not work depending on ROM/permissions.</i>

/wifi_on       - Enable Wi‑Fi
/wifi_off      - Disable Wi‑Fi
/bt_on         - Enable Bluetooth
/bt_off        - Disable Bluetooth

/loop_on &lt;minutes&gt; &lt;command&gt;  - Repeat command every N minutes
/loop_off                      - Stop all background loops

EOF
)"
  send_code "$msg"
}

handle_status() {
  (handle_status_send >/dev/null 2>&1 &)
}

handle_status_on_boot() {
  (handle_status_send >/dev/null 2>&1 &)
  send_code "✅ System boot completed. Collecting system information..."
}

handle_signal() {
  dump="$(dumpsys telephony 2>/dev/null; dumpsys telephony.registry 2>/dev/null)"
  dbm="$(get_dbm)"
  bandinfo="$(get_band_info_from_dump "$dump")"
  nettypedesc="$(get_nettype_with_desc)"
  quality="$(map_sig_quality "$dbm")"
  operator="$(get_operator_name)"
  bars="$(get_signal_bars "$dbm")"
  rsrq="$(get_rsrq_db_from_dump "$dump")"
  sinr="$(get_sinr_db_from_dump "$dump")"
  roaming="$(get_roaming_status_vi_from_dump "$dump")"
  meter="$(format_dbm_strength_meter "$dbm")"

  op_esc="$(escape_html "$operator")"
  net_esc="$(escape_html "$nettypedesc")"
  qual_esc="$(escape_html "$quality")"
  bars_esc="$(escape_html "$bars")"
  dbm_esc="$(escape_html "$dbm")"
  rsrq_esc="$(escape_html "$rsrq")"
  sinr_esc="$(escape_html "$sinr")"
  roam_esc="$(escape_html "$roaming")"
  meter_esc="$(escape_html "$meter")"
  ts="$(date '+%H:%M:%S · %d/%m/%Y' 2>/dev/null || echo '—')"
  ts_esc="$(escape_html "$ts")"

  if [ -n "$bandinfo" ]; then
    band_block="<code>$(escape_html "$bandinfo")</code>"
  else
    band_block="<i>Cannot read band info from modem (ROM/NSA or not camped yet).</i>"
  fi

  meter_block=""
  if [ -n "$meter" ]; then
    meter_block="<b>Meter (estimate)</b>
<code>${meter_esc}</code>

"
  fi

  extra_physics=""
  if [ -n "$rsrq" ]; then
    extra_physics="${extra_physics}<b>RSRQ</b> (channel quality): <code>${rsrq_esc} dB</code>
"
  fi
  if [ -n "$sinr" ]; then
    extra_physics="${extra_physics}<b>SINR / RSSNR</b> (signal-to-noise): <code>${sinr_esc} dB</code>
"
  fi

  msg="<b>📡 Cellular report</b>
<i>${ts_esc}</i>
━━━━━━━━━━━━━━━━

<b>Operator</b>
<code>${op_esc}</code>

<b>Access technology</b>
${net_esc}

<b>Band</b>
${band_block}

<b>Signal · RSRP</b>
<code>${dbm_esc} dBm</code>
<b>Rating</b>: ${qual_esc} · ${bars_esc}

${meter_block}${extra_physics}<b>Roaming</b>
${roam_esc}"

  send_code "$msg"
}

handle_ip() {
  ts="$(date '+%H:%M:%S · %d/%m/%Y' 2>/dev/null || echo '—')"
  ts_esc="$(escape_html "$ts")"
  pub="$(get_public_ip)"
  pub_esc="$(escape_html "$pub")"

  if command -v ip >/dev/null 2>&1; then
    ipv4="$(
      ip -o -4 addr show 2>/dev/null \
        | awk '!/127\.0\.0\.1/ {print $2 "|" $4}'
    )"
    ipv6="$(
      ip -o -6 addr show 2>/dev/null \
        | awk '!/ ::1\/128/ && !/ scope host / {print $2 "|" $4}'
    )"

    if [ -z "$ipv4" ] && [ -z "$ipv6" ]; then
      local_block="<i>No address on non-loopback interfaces, or <code>ip addr</code> returned nothing.</i>"
    else
      v4_lines=""
      if [ -n "$ipv4" ]; then
        v4_lines="$(echo "$ipv4" | while IFS= read -r row || [ -n "$row" ]; do
          [ -z "$row" ] && continue
          iface="${row%%|*}"
          cidr="${row#*|}"
          printf '%s\n' "• <b>$(escape_html "$iface")</b> <code>$(escape_html "$cidr")</code>"
        done)"
      fi
      v6_lines=""
      if [ -n "$ipv6" ]; then
        v6_lines="$(echo "$ipv6" | while IFS= read -r row || [ -n "$row" ]; do
          [ -z "$row" ] && continue
          iface="${row%%|*}"
          cidr="${row#*|}"
          printf '%s\n' "• <b>$(escape_html "$iface")</b> <code>$(escape_html "$cidr")</code>"
        done)"
      fi

      if [ -n "$v4_lines" ]; then
        v4_sec="<b>IPv4</b> <i>(LAN)</i>
${v4_lines}"
      else
        v4_sec="<b>IPv4</b> <i>(LAN)</i>
<i>—</i>"
      fi
      if [ -n "$v6_lines" ]; then
        v6_sec="<b>IPv6</b>
${v6_lines}"
      else
        v6_sec="<b>IPv6</b>
<i>—</i>"
      fi
      local_block="${v4_sec}

${v6_sec}"
    fi
  else
    out="$(ifconfig 2>/dev/null)"
    if [ -z "$out" ]; then
      local_block="<i>Cannot read interfaces (<code>ip</code> missing and <code>ifconfig</code> returned nothing).</i>"
    else
      out_esc="$(escape_html "$out")"
      local_block="<b>ifconfig output</b> <i>(fallback)</i>
<pre>${out_esc}</pre>"
    fi
  fi

  if [ -n "$pub" ]; then
    wan_block="<code>${pub_esc}</code>"
  else
    wan_block="<i>Cannot query public WAN IP (blocked HTTP/DNS or lookup service failed).</i>"
  fi

  msg="<b>🌐 IP addresses</b>
<i>${ts_esc}</i>
━━━━━━━━━━━━━━━━

<b>Local</b>
${local_block}

<b>WAN · Public</b>
${wan_block}"

  send_code "$msg"
}

handle_battery() {
  info="$(get_batt_info_text)"
  send_code "$info"
}

_ping_target_valid() {
  t="$1"
  [ -z "$t" ] && return 1
  [ "${#t}" -gt 253 ] && return 1
  case "$t" in
    *[!-0-9A-Za-z.:]*) return 1 ;;
  esac
  return 0
}

handle_ping() {
  rest="$1"
  rest="$(echo "$rest" | sed 's/^[[:space:]]*//')"
  if [ -n "$rest" ]; then
    target="${rest%% *}"
  else
    target="1.1.1.1"
  fi

  if ! _ping_target_valid "$target"; then
    send_code "❌ Invalid ping target. Use IPv4/IPv6 or hostname (letters, digits, <code>.</code> <code>:</code> <code>-</code>)."
    return 1
  fi
  if ! command -v ping >/dev/null 2>&1; then
    send_code "❌ <code>ping</code> is not available on this device."
    return 1
  fi

  out="$(ping -c 4 -W 5 "$target" 2>&1)" || true
  out="$(printf '%s' "$out" | head -c 3500)"
  out_esc="$(printf '%s' "$out" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"

  send_code "<b>ping</b> → <code>$(escape_html "$target")</code>
<pre>${out_esc}</pre>"
}

notify_command_received() {
  send_code "✅ Received:\n<code>$(escape_html "$1")</code>\nWorking..."
}

dispatch_command() {
  TEXT="$1"
  CID="$2"

  if ! tg_chat_allowed "$CID"; then
    return 0
  fi

  case "$TEXT" in
    "/help")
      notify_command_received "$TEXT"
      handle_help
      ;;
    "/dev")
      notify_command_received "$TEXT"
      handle_dev
      ;;
    "/start")
      notify_command_received "$TEXT"
      handle_help
      ;;
    "/shutdown")
      if ! tg_boot_grace_ok; then
        send_code "⏳ Skipped <code>/shutdown</code> — device just booted (wait ~${TG_BOOT_GRACE_SEC}s uptime). Send again later."
        return 0
      fi
      notify_command_received "$TEXT"
      handle_shutdown
      ;;
    "/restart")
      if ! tg_boot_grace_ok; then
        send_code "⏳ Skipped <code>/restart</code> — device just booted (wait ~${TG_BOOT_GRACE_SEC}s uptime). Send again later."
        return 0
      fi
      notify_command_received "$TEXT"
      handle_restart
      ;;
    "/status")
      notify_command_received "$TEXT"
      handle_status
      ;;
    "/signal")
      notify_command_received "$TEXT"
      handle_signal
      ;;
    "/ip")
      notify_command_received "$TEXT"
      handle_ip
      ;;
    /ping*)
      notify_command_received "$TEXT"
      rest="${TEXT#/ping}"
      rest="$(echo "$rest" | sed 's/^[[:space:]]*//')"
      handle_ping "$rest"
      ;;
    "/battery")
      notify_command_received "$TEXT"
      handle_battery
      ;;
    "/datausage")
      notify_command_received "$TEXT"
      handle_datausage
      ;;
    /sms*)
      notify_command_received "$TEXT"
      rest="${TEXT#/sms}"
      rest="$(echo "$rest" | sed 's/^[[:space:]]*//')"
      handle_sms "$rest"
      ;;
    "/rndis_on")
      notify_command_received "$TEXT"
      handle_rndis_on
      ;;
    "/rndis_off")
      notify_command_received "$TEXT"
      handle_rndis_off
      ;;
    "/hotspot_on")
      notify_command_received "$TEXT"
      handle_hotspot_on ""
      ;;
    /hotspot_on*)
      notify_command_received "$TEXT"
      rest="${TEXT#/hotspot_on}"
      rest="$(echo "$rest" | sed 's/^[[:space:]]*//')"
      handle_hotspot_on "$rest"
      ;;
    "/hotspot_off")
      notify_command_received "$TEXT"
      handle_hotspot_off
      ;;
    "/wifi_on")
      notify_command_received "$TEXT"
      handle_wifi_on
      ;;
    "/wifi_off")
      notify_command_received "$TEXT"
      handle_wifi_off
      ;;
    "/bt_on")
      notify_command_received "$TEXT"
      handle_bt_on
      ;;
    "/bt_off")
      notify_command_received "$TEXT"
      handle_bt_off
      ;;
    "/loop_off")
      notify_command_received "$TEXT"
      handle_loop_off
      ;;
    /loop_on*)
      notify_command_received "$TEXT"
      rest="${TEXT#/loop_on}"
      rest="$(echo "$rest" | sed 's/^[[:space:]]*//')"
      handle_loop_on "$rest" "$CID"
      ;;
    ""|*[![:print:]]*) ;;
    *)
      send_code "✅ Received:\n<code>$(escape_html "$TEXT")</code>\n❌ Unknown command. Type /help to see the list."
      ;;
  esac
}


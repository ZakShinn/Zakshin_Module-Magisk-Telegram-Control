# shellcheck shell=sh
# Xử lý lệnh Telegram (giống bản gốc trong old/service.sh)

handle_help() {
  msg="$(cat <<'EOF'
<b>Lệnh hỗ trợ:</b>

/help                 - Hiển thị danh sách lệnh
/dev                   - Lệnh nâng cao (mạng, màn hình, app, USB, …)
/status             - Hiển thị thông tin cơ bản của thiết bị
/signal              - Báo cáo mạng: RAT, băng tần, RSRP/RSRQ/SINR, roaming
/ip                      - IPv4 / IPv6 cục bộ + WAN public
/ping [đích]     - Ping (mặc định 1.1.1.1) · vd: <code>/ping 8.8.8.8</code>
/battery           - Thông tin pin hiện tại
/datausage     - Dung lượng data đã dùng
/sms [số]          - SMS gần nhất trong inbox (mặc định 1; ví dụ <code>/sms 5</code>)

/shutdown     - Tắt máy
/restart            - Khởi động lại
<i>Không được spam /shutdown và /restart vì sẽ gây tình trạng tắt và khởi động liên tục do tồn tại yêu cầu chưa được thực hiện.</i>
EOF
)"
  send_code "$msg"
}

handle_dev() {
  dev_commands_send_help
}

handle_status() {
  (handle_status_send >/dev/null 2>&1 &)
}

handle_status_on_boot() {
  (handle_status_send >/dev/null 2>&1 &)
  send_code "✅ Hệ thống khởi động thành công. Đang thu thập thông tin hệ thống"
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
    band_block="<i>Không đọc được băng tần từ modem (ROM/NSA hoặc chưa camp đủ)</i>"
  fi

  meter_block=""
  if [ -n "$meter" ]; then
    meter_block="<b>Thanh mức (ước lượng)</b>
<code>${meter_esc}</code>

"
  fi

  extra_physics=""
  if [ -n "$rsrq" ]; then
    extra_physics="${extra_physics}<b>RSRQ</b> (chất lượng kênh): <code>${rsrq_esc} dB</code>
"
  fi
  if [ -n "$sinr" ]; then
    extra_physics="${extra_physics}<b>SINR / RSSNR</b> (tỷ số nhiễu): <code>${sinr_esc} dB</code>
"
  fi

  msg="<b>📡 Báo cáo mạng di động</b>
<i>${ts_esc}</i>
━━━━━━━━━━━━━━━━

<b>Nhà mạng</b>
<code>${op_esc}</code>

<b>Công nghệ truy cập</b>
${net_esc}

<b>Băng tần</b>
${band_block}

<b>Tín hiệu · RSRP</b>
<code>${dbm_esc} dBm</code>
<b>Đánh giá</b>: ${qual_esc} · ${bars_esc}

${meter_block}${extra_physics}<b>Chuyển vùng</b>
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
      local_block="<i>Không có địa chỉ trên giao diện (ngoài loopback) hoặc <code>ip addr</code> không trả dữ liệu.</i>"
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
        v4_sec="<b>IPv4</b> <i>(LAN / nội bộ)</i>
${v4_lines}"
      else
        v4_sec="<b>IPv4</b> <i>(LAN / nội bộ)</i>
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
      local_block="<i>Không đọc được giao diện (không có <code>ip</code> và <code>ifconfig</code> trống).</i>"
    else
      out_esc="$(escape_html "$out")"
      local_block="<b>Nội dung ifconfig</b> <i>(dự phòng)</i>
<pre>${out_esc}</pre>"
    fi
  fi

  if [ -n "$pub" ]; then
    wan_block="<code>${pub_esc}</code>"
  else
    wan_block="<i>Không tra được WAN công khai (HTTP/DNS bị chặn hoặc dịch vụ tra cứu lỗi).</i>"
  fi

  msg="<b>🌐 Địa chỉ IP</b>
<i>${ts_esc}</i>
━━━━━━━━━━━━━━━━

<b>Cục bộ</b>
${local_block}

<b>WAN · Public</b>
${wan_block}"

  send_code "$msg"
}

handle_battery() {
  info="$(get_batt_info_text)"
  send_code "$info"
}

# Chỉ cho phép ký tự an toàn cho đích ping (tránh chèn lệnh).
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
    send_code "❌ Đích ping không hợp lệ. Chỉ dùng IPv4/IPv6 hoặc tên host (chữ, số, <code>.</code> <code>:</code> <code>-</code>)."
    return 1
  fi
  if ! command -v ping >/dev/null 2>&1; then
    send_code "❌ Không tìm thấy lệnh <code>ping</code> trên thiết bị."
    return 1
  fi

  out="$(ping -c 4 -W 5 "$target" 2>&1)" || true
  out="$(printf '%s' "$out" | head -c 3500)"
  out_esc="$(printf '%s' "$out" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"

  send_code "<b>ping</b> → <code>$(escape_html "$target")</code>
<pre>${out_esc}</pre>"
}

# Xác nhận Telegram đã tới bot (trước khi xử lý lệnh).
notify_command_received() {
  send_code "✅ Đã nhận lệnh:\n<code>$(escape_html "$1")</code>\nĐang thực hiện…"
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
        send_code "⏳ Bỏ qua <code>/shutdown</code> — thiết bị vừa khởi động (chờ ~${TG_BOOT_GRACE_SEC}s uptime). Gửi lại lệnh sau."
        return 0
      fi
      notify_command_received "$TEXT"
      handle_shutdown
      ;;
    "/restart")
      if ! tg_boot_grace_ok; then
        send_code "⏳ Bỏ qua <code>/restart</code> — thiết bị vừa khởi động (chờ ~${TG_BOOT_GRACE_SEC}s uptime). Gửi lại lệnh sau."
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
    "/sms_watch_off")
      notify_command_received "$TEXT"
      handle_sms_watch_off
      ;;
    /sms_watch_on*)
      notify_command_received "$TEXT"
      rest="${TEXT#/sms_watch_on}"
      rest="$(echo "$rest" | sed 's/^[[:space:]]*//')"
      handle_sms_watch_on "$rest" "$CID"
      ;;
    /sent_sms*)
      notify_command_received "$TEXT"
      rest="${TEXT#/sent_sms}"
      rest="$(echo "$rest" | sed 's/^[[:space:]]*//')"
      handle_sent_sms "$rest"
      ;;
    /sms*)
      notify_command_received "$TEXT"
      rest="${TEXT#/sms}"
      rest="$(echo "$rest" | sed 's/^[[:space:]]*//')"
      handle_sms "$rest"
      ;;
    "/usb_lan_on")
      notify_command_received "$TEXT"
      handle_usb_lan_on
      ;;
    "/usb_lan_off")
      notify_command_received "$TEXT"
      handle_usb_lan_off
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
    "/airplane_on")
      notify_command_received "$TEXT"
      handle_airplane_on
      ;;
    "/airplane_off")
      notify_command_received "$TEXT"
      handle_airplane_off
      ;;
    "/data_on")
      notify_command_received "$TEXT"
      handle_data_on
      ;;
    "/data_off")
      notify_command_received "$TEXT"
      handle_data_off
      ;;
    "/nfc_on")
      notify_command_received "$TEXT"
      handle_nfc_on
      ;;
    "/nfc_off")
      notify_command_received "$TEXT"
      handle_nfc_off
      ;;
    "/wifi_info")
      notify_command_received "$TEXT"
      handle_wifi_info
      ;;
    "/torch_on")
      notify_command_received "$TEXT"
      handle_torch_on
      ;;
    "/torch_off")
      notify_command_received "$TEXT"
      handle_torch_off
      ;;
    "/screen_on")
      notify_command_received "$TEXT"
      handle_screen_on
      ;;
    "/screen_off")
      notify_command_received "$TEXT"
      handle_screen_off
      ;;
    /brightness*)
      notify_command_received "$TEXT"
      rest="${TEXT#/brightness}"
      rest="$(echo "$rest" | sed 's/^[[:space:]]*//')"
      handle_brightness "$rest"
      ;;
    /volume*)
      notify_command_received "$TEXT"
      rest="${TEXT#/volume}"
      rest="$(echo "$rest" | sed 's/^[[:space:]]*//')"
      handle_volume "$rest"
      ;;
    "/storage")
      notify_command_received "$TEXT"
      handle_storage
      ;;
    "/mem")
      notify_command_received "$TEXT"
      handle_mem
      ;;
    "/uptime")
      notify_command_received "$TEXT"
      handle_uptime
      ;;
    "/reboot_recovery")
      notify_command_received "$TEXT"
      handle_reboot_recovery
      ;;
    "/reboot_bootloader")
      notify_command_received "$TEXT"
      handle_reboot_bootloader
      ;;
    /prop*)
      notify_command_received "$TEXT"
      rest="${TEXT#/prop}"
      rest="$(echo "$rest" | sed 's/^[[:space:]]*//')"
      handle_prop "$rest"
      ;;
    /kill*)
      notify_command_received "$TEXT"
      rest="${TEXT#/kill}"
      rest="$(echo "$rest" | sed 's/^[[:space:]]*//')"
      handle_kill "$rest"
      ;;
    /open*)
      notify_command_received "$TEXT"
      rest="${TEXT#/open}"
      rest="$(echo "$rest" | sed 's/^[[:space:]]*//')"
      handle_open "$rest"
      ;;
    "/sync_on")
      notify_command_received "$TEXT"
      handle_sync_on
      ;;
    "/sync_off")
      notify_command_received "$TEXT"
      handle_sync_off
      ;;
    "/location_on")
      notify_command_received "$TEXT"
      handle_location_on
      ;;
    "/location_off")
      notify_command_received "$TEXT"
      handle_location_off
      ;;
    "/dnd_on")
      notify_command_received "$TEXT"
      handle_dnd_on
      ;;
    "/dnd_off")
      notify_command_received "$TEXT"
      handle_dnd_off
      ;;
    "/stayon_on")
      notify_command_received "$TEXT"
      handle_stayon_on
      ;;
    "/stayon_off")
      notify_command_received "$TEXT"
      handle_stayon_off
      ;;
    "/lock")
      notify_command_received "$TEXT"
      handle_lock
      ;;
    "/rotate_on")
      notify_command_received "$TEXT"
      handle_rotate_on
      ;;
    "/rotate_off")
      notify_command_received "$TEXT"
      handle_rotate_off
      ;;
    "/ringer_normal")
      notify_command_received "$TEXT"
      handle_ringer_normal
      ;;
    "/ringer_silent")
      notify_command_received "$TEXT"
      handle_ringer_silent
      ;;
    "/ringer_vibrate")
      notify_command_received "$TEXT"
      handle_ringer_vibrate
      ;;
    "/vol_up")
      notify_command_received "$TEXT"
      handle_vol_up
      ;;
    "/vol_down")
      notify_command_received "$TEXT"
      handle_vol_down
      ;;
    "/media_play")
      notify_command_received "$TEXT"
      handle_media_play
      ;;
    "/brightness_auto")
      notify_command_received "$TEXT"
      handle_brightness_auto
      ;;
    "/brightness_manual")
      notify_command_received "$TEXT"
      handle_brightness_manual
      ;;
    "/anim_off")
      notify_command_received "$TEXT"
      handle_anim_off
      ;;
    "/anim_on")
      notify_command_received "$TEXT"
      handle_anim_on
      ;;
    "/screenshot")
      notify_command_received "$TEXT"
      handle_screenshot
      ;;
    "/wifi_scan")
      notify_command_received "$TEXT"
      handle_wifi_scan
      ;;
    "/bt_info")
      notify_command_received "$TEXT"
      handle_bt_info
      ;;
    "/tether_status")
      notify_command_received "$TEXT"
      handle_tether_status
      ;;
    "/usb_status")
      notify_command_received "$TEXT"
      handle_usb_status
      ;;
    "/dns")
      notify_command_received "$TEXT"
      handle_dns
      ;;
    "/net_if")
      notify_command_received "$TEXT"
      handle_net_if
      ;;
    "/hotspot_status")
      notify_command_received "$TEXT"
      handle_hotspot_status
      ;;
    "/device")
      notify_command_received "$TEXT"
      handle_device
      ;;
    "/cpu")
      notify_command_received "$TEXT"
      handle_cpu
      ;;
    "/temp")
      notify_command_received "$TEXT"
      handle_temp
      ;;
    "/datetime")
      notify_command_received "$TEXT"
      handle_datetime
      ;;
    "/rootid")
      notify_command_received "$TEXT"
      handle_rootid
      ;;
    "/logcat_clear")
      notify_command_received "$TEXT"
      handle_logcat_clear
      ;;
    /logcat*)
      notify_command_received "$TEXT"
      rest="${TEXT#/logcat}"
      rest="$(echo "$rest" | sed 's/^[[:space:]]*//')"
      handle_logcat "$rest"
      ;;
    "/dmesg")
      notify_command_received "$TEXT"
      handle_dmesg
      ;;
    /packages*)
      notify_command_received "$TEXT"
      rest="${TEXT#/packages}"
      rest="$(echo "$rest" | sed 's/^[[:space:]]*//')"
      handle_packages "$rest"
      ;;
    /pkg*)
      notify_command_received "$TEXT"
      rest="${TEXT#/pkg}"
      rest="$(echo "$rest" | sed 's/^[[:space:]]*//')"
      handle_pkg "$rest"
      ;;
    /clear*)
      notify_command_received "$TEXT"
      rest="${TEXT#/clear}"
      rest="$(echo "$rest" | sed 's/^[[:space:]]*//')"
      handle_clear "$rest"
      ;;
    /input*)
      notify_command_received "$TEXT"
      rest="${TEXT#/input}"
      rest="$(echo "$rest" | sed 's/^[[:space:]]*//')"
      handle_input_text "$rest"
      ;;
    "/unknown_sources_on")
      notify_command_received "$TEXT"
      handle_unknown_sources_on
      ;;
    "/unknown_sources_off")
      notify_command_received "$TEXT"
      handle_unknown_sources_off
      ;;
    ""|*[![:print:]]*) ;;
    *)
      send_code "✅ Đã nhận:\n<code>$(escape_html "$TEXT")</code>\n❌ Lệnh không hợp lệ. Gõ /help hoặc /dev."
      ;;
  esac
}

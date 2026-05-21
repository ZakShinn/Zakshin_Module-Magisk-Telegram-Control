# shellcheck shell=sh
# Xử lý lệnh Telegram (giống bản gốc trong old/service.sh)

handle_help() {
  msg="$(cat <<'EOF'
<b>Lệnh hỗ trợ:</b>

/help                 - Hiển thị danh sách lệnh
/dev                   - Lệnh thử nghiệm (wifi/bt/loop)
/status             - Hiển thị thông tin cơ bản của thiết bị
/signal              - Báo cáo mạng: RAT, băng tần, RSRP/RSRQ/SINR, roaming
/ip                      - IPv4 / IPv6 cục bộ + WAN public
/ping [đích]     - Ping (mặc định 1.1.1.1) · vd: <code>/ping 8.8.8.8</code>
/battery           - Thông tin pin hiện tại
/datausage     - Dung lượng data đã dùng
/sms [số]          - SMS gần nhất trong inbox (mặc định 1; ví dụ <code>/sms 5</code>)

/rndis_on        - Bật RNDIS (USB tether)
/rndis_off        - Tắt RNDIS (USB tether)
/hotspot_on [SSID MậtKhẩu]  - Bật hotspot (mặc định từ config)
/hotspot_off  - Tắt Hotspot (Phát wifi)

/shutdown     - Tắt máy
/restart            - Khởi động lại
<i>Không được spam /shutdown và /restart vì sẽ gây tình trạng tắt và khởi động liên tục do tồn tại yêu cầu chưa được thực hiện.</i>
EOF
)"
  send_code "$msg"
}

handle_dev() {
  msg="$(cat <<'EOF'
<b>Lệnh thử nghiệm (/dev):</b>
<i>Các tính năng đang thử nghiệm, có thể đổi hành vi hoặc không hoạt động tùy ROM/quyền.</i>

/wifi_on       - Bật Wi‑Fi
/wifi_off      - Tắt Wi‑Fi
/bt_on         - Bật Bluetooth
/bt_off        - Tắt Bluetooth

/loop_on &lt;phút&gt; &lt;lệnh&gt;  - Lặp: mỗi N phút chạy lệnh một lần
/loop_off       - Dừng mọi vòng lặp nền (/loop_on)

EOF
)"
  send_code "$msg"
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
${roam_esc}

<i>Tham khảo: modem, antenna và ROM quyết định độ chính xác.</i>"

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
${wan_block}

<i>Public qua HTTP (ipify / ifconfig.me / ipinfo). Bản ghi IPv6 global có thể trùng hoặc khác địa chỉ WAN tùy nhà mạng.</i>"

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
      send_code "✅ Đã nhận:\n<code>$(escape_html "$TEXT")</code>\n❌ Lệnh không hợp lệ. Gõ /help để xem danh sách lệnh."
      ;;
  esac
}

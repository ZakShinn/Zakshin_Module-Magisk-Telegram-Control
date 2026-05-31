# shellcheck shell=sh
# RNDIS, hotspot (giống bản gốc)

get_rndis_state_simple() {
  usb_state="$(getprop_safe sys.usb.state)"
  usb_cfg="$(getprop_safe sys.usb.config)"
  echo "$usb_state $usb_cfg" | grep -qi 'rndis' && echo "on" || echo "off"
}

# USB‑C → LAN / dock: NCM hoặc RNDIS (chia sẻ Internet từ máy ra cổng LAN).
get_usb_lan_state_simple() {
  usb_state="$(getprop_safe sys.usb.state)"
  usb_cfg="$(getprop_safe sys.usb.config)"
  if echo "$usb_state $usb_cfg" | grep -qiE 'rndis|ncm'; then
    echo "on"
    return
  fi
  if dumpsys connectivity 2>/dev/null | grep -qiE 'USB.*tether|tethering.*usb|Tethered.*(rndis|ncm)'; then
    echo "on"
    return
  fi
  echo "off"
}

_usb_lan_tether_service() {
  enable="$1"
  ok=0
  for code in 34 33 30 31; do
    if service call connectivity "$code" i32 "$enable" >/dev/null 2>&1; then
      ok=1
      break
    fi
  done
  [ "$ok" = "1" ]
}

_usb_lan_connectivity_cmd() {
  action="$1"
  command -v cmd >/dev/null 2>&1 || return 1
  case "$action" in
    on)
      cmd connectivity tether usb enable 2>/dev/null \
        || cmd connectivity tethering enable usb 2>/dev/null \
        || cmd connectivity start-tethering usb 2>/dev/null \
        || true
      ;;
    off)
      cmd connectivity tether usb disable 2>/dev/null \
        || cmd connectivity tethering disable usb 2>/dev/null \
        || cmd connectivity stop-tethering usb 2>/dev/null \
        || true
      ;;
  esac
}

usb_lan_on_apply() {
  _usb_lan_tether_service 1 || true
  _usb_lan_connectivity_cmd on || true

  if command -v svc >/dev/null 2>&1; then
    svc usb setFunctions ncm,adb 2>/dev/null || svc usb setFunctions ncm 2>/dev/null || true
  fi
  setprop sys.usb.config ncm,adb 2>/dev/null || setprop sys.usb.config ncm 2>/dev/null || true
  setprop sys.usb.configfs 1 2>/dev/null || true

  sleep 2
  if [ "$(get_usb_lan_state_simple)" != "on" ]; then
    rndis_on_apply
    sleep 1
  fi

  echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true
}

usb_lan_off_apply() {
  _usb_lan_tether_service 0 || true
  _usb_lan_connectivity_cmd off || true

  if command -v svc >/dev/null 2>&1; then
    svc usb setFunctions mtp,adb 2>/dev/null || svc usb setFunctions mtp 2>/dev/null || true
  fi
  setprop sys.usb.config mtp,adb 2>/dev/null || setprop sys.usb.config mtp 2>/dev/null || true
  setprop sys.usb.configfs 1 2>/dev/null || true
}

handle_usb_lan_on() {
  usb_lan_on_apply
  sleep 1
  mode="$(getprop_safe sys.usb.config)"
  if [ "$(get_usb_lan_state_simple)" = "on" ]; then
    send_code "✅ Chia sẻ Internet <b>USB‑C → LAN</b>: <b>ĐANG BẬT</b>
Chế độ USB: <code>$(escape_html "$mode")</code>
<i>Cắm dock/adapter Type‑C sang LAN trước hoặc sau khi bật, tùy thiết bị.</i>"
  else
    send_code "❌ Không bật được chia sẻ USB‑C → LAN.
Thử: cắm adapter, bật <b>USB tethering</b> trong Cài đặt, hoặc ROM hỗ trợ NCM/RNDIS."
  fi
}

handle_usb_lan_off() {
  usb_lan_off_apply
  sleep 1
  if [ "$(get_usb_lan_state_simple)" = "off" ]; then
    send_code "✅ Đã tắt chia sẻ Internet USB‑C → LAN."
  else
    mode="$(getprop_safe sys.usb.config)"
    send_code "⚠️ Đã gửi lệnh tắt; USB vẫn: <code>$(escape_html "$mode")</code>. Rút cáp hoặc tắt tether trong Cài đặt nếu cần."
  fi
}

get_hotspot_state_simple() {
  iface="$(dumpsys wifi 2>/dev/null | sed -n 's/.*SoftApManager{id=[^}]* iface=\([^ ]*\) .*/\1/p' | head -n1)"
  if [ -n "$iface" ] && ip link show "$iface" 2>/dev/null | grep -q "state UP"; then
    echo "on"
  else
    echo "off"
  fi
}

rndis_on_apply() {
  if command -v svc >/dev/null 2>&1; then
    svc usb setFunctions rndis,adb 2>/dev/null || svc usb setFunctions rndis 2>/dev/null || true
  fi
  setprop sys.usb.config rndis,adb 2>/dev/null || true
  setprop sys.usb.configfs 1 2>/dev/null || true
}

handle_rndis_on() {
  rndis_on_apply
  sleep 1
  if [ "$(get_rndis_state_simple)" = "on" ]; then
    send_code "🔌 RNDIS: <b>ĐÃ BẬT</b>"
  fi
}

handle_rndis_off() {
  if command -v svc >/dev/null 2>&1; then
    svc usb setFunctions mtp,adb 2>/dev/null || svc usb setFunctions mtp 2>/dev/null || true
  fi
  setprop sys.usb.config mtp,adb 2>/dev/null || true
  setprop sys.usb.configfs 1 2>/dev/null || true
}

# arg_line: phần sau "/hotspot_on" (đã tách), có thể rỗng — chỉ bật softap + ifconfig, không gửi Telegram.
# Trả 0 nếu bật được, 1 nếu không.
hotspot_on_apply() {
  arg_line="$1"
  arg_line="$(echo "$arg_line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

  if [ -z "$arg_line" ]; then
    ssid="${HOTSPOT_SSID:-Hotspot}"
    pass="${HOTSPOT_PASS:-12345678}"
  else
    ssid="${arg_line%% *}"
    if [ "$ssid" = "$arg_line" ]; then
      pass="${HOTSPOT_PASS:-}"
    else
      pass="${arg_line#"$ssid"}"
      pass="$(echo "$pass" | sed 's/^[[:space:]]*//')"
    fi
  fi

  hs_ok=0
  if [ -n "$pass" ]; then
    if cmd wifi start-softap "$ssid" wpa2 "$pass" >/dev/null 2>&1; then
      hs_ok=1
    fi
  else
    if cmd wifi start-softap "$ssid" open >/dev/null 2>&1; then
      hs_ok=1
    fi
  fi

  if [ "$hs_ok" = "1" ]; then
    /system/bin/ifconfig swlan0 192.168.173.1/24 up 2>/dev/null || true
    return 0
  fi
  return 1
}

# arg_line: phần sau "/hotspot_on" (đã tách), có thể rỗng.
# /hotspot_on                    → dùng HOTSPOT_SSID / HOTSPOT_PASS hoặc mặc định gọn.
# /hotspot_on TênWiFi MậtKhẩu  → SSID = từ đầu, mật khẩu = phần còn lại (cho phép nhiều từ).
# /hotspot_on TênWiFi            → một từ: mật khẩu lấy HOTSPOT_PASS (nếu có), không thì mạng mở (open).
handle_hotspot_on() {
  arg_line="$1"
  arg_line="$(echo "$arg_line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

  if [ -z "$arg_line" ]; then
    ssid="${HOTSPOT_SSID:-Hotspot}"
    pass="${HOTSPOT_PASS:-12345678}"
  else
    ssid="${arg_line%% *}"
    if [ "$ssid" = "$arg_line" ]; then
      pass="${HOTSPOT_PASS:-}"
    else
      pass="${arg_line#"$ssid"}"
      pass="$(echo "$pass" | sed 's/^[[:space:]]*//')"
    fi
  fi

  ssid_esc="$(escape_html "$ssid")"
  if hotspot_on_apply "$arg_line"; then
    if [ -n "$pass" ]; then
      send_code "✅ Hotspot bật · SSID <code>${ssid_esc}</code> · WPA2"
    else
      send_code "✅ Hotspot bật · SSID <code>${ssid_esc}</code> · mở (open)"
    fi
  else
    if [ -n "$pass" ]; then
      send_code "❌ Hotspot không bật được · SSID <code>${ssid_esc}</code> · WPA2: thử mật khẩu ≥8 ký tự; kiểm tra quyền/ROM."
    else
      send_code "❌ Hotspot không bật được · SSID <code>${ssid_esc}</code> · mạng mở (open); kiểm tra quyền/ROM."
    fi
  fi
}

# Monitor bỏ qua một lần "Hotspot đã tắt" trùng khi tắt bằng /hotspot_off (đã có tin từ handler).
HOTSPOT_OFF_CMD_MARKER="/data/local/tmp/tg_hotspot_off_by_cmd"

handle_hotspot_off() {
  was="$(get_hotspot_state_simple)"
  if [ "$was" = "on" ]; then
    : > "$HOTSPOT_OFF_CMD_MARKER"
  fi
  cmd wifi stop-softap >/dev/null 2>&1 || svc wifi stop-softap >/dev/null 2>&1 || true

  i=0
  while [ "$(get_hotspot_state_simple)" != "off" ] && [ "$i" -lt 25 ]; do
    sleep 1
    i=$((i + 1))
  done

  if [ "$(get_hotspot_state_simple)" = "off" ]; then
    send_code "✅ Hotspot đã tắt."
  else
    rm -f "$HOTSPOT_OFF_CMD_MARKER" 2>/dev/null || true
    send_code "❌ Không tắt được hotspot (ROM hoặc quyền)."
  fi
}

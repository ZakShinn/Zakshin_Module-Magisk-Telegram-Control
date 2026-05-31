# shellcheck shell=sh
# RNDIS, hotspot

get_rndis_state_simple() {
  usb_state="$(getprop_safe sys.usb.state)"
  usb_cfg="$(getprop_safe sys.usb.config)"
  echo "$usb_state $usb_cfg" | grep -qi 'rndis' && echo "on" || echo "off"
}

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
    send_code "✅ <b>USB‑C → LAN</b> internet sharing: <b>ON</b>
USB mode: <code>$(escape_html "$mode")</code>
<i>Plug the Type‑C to LAN adapter before or after enabling, depending on your device.</i>"
  else
    send_code "❌ Failed to enable USB‑C → LAN sharing.
Try: plug in the adapter, enable <b>USB tethering</b> in Settings, or a ROM with NCM/RNDIS support."
  fi
}

handle_usb_lan_off() {
  usb_lan_off_apply
  sleep 1
  if [ "$(get_usb_lan_state_simple)" = "off" ]; then
    send_code "✅ USB‑C → LAN internet sharing is OFF."
  else
    mode="$(getprop_safe sys.usb.config)"
    send_code "⚠️ Stop command sent; USB still: <code>$(escape_html "$mode")</code>. Unplug or disable tethering in Settings if needed."
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
    send_code "🔌 RNDIS: <b>ON</b>"
  fi
}

handle_rndis_off() {
  if command -v svc >/dev/null 2>&1; then
    svc usb setFunctions mtp,adb 2>/dev/null || svc usb setFunctions mtp 2>/dev/null || true
  fi
  setprop sys.usb.config mtp,adb 2>/dev/null || true
  setprop sys.usb.configfs 1 2>/dev/null || true
}

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
      send_code "✅ Hotspot ON · SSID <code>${ssid_esc}</code> · WPA2"
    else
      send_code "✅ Hotspot ON · SSID <code>${ssid_esc}</code> · open"
    fi
  else
    if [ -n "$pass" ]; then
      send_code "❌ Failed to start hotspot · SSID <code>${ssid_esc}</code> · WPA2: try password ≥ 8 chars; check ROM/permissions."
    else
      send_code "❌ Failed to start hotspot · SSID <code>${ssid_esc}</code> · open; check ROM/permissions."
    fi
  fi
}

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
    send_code "✅ Hotspot is OFF."
  else
    rm -f "$HOTSPOT_OFF_CMD_MARKER" 2>/dev/null || true
    send_code "❌ Failed to stop hotspot (ROM or permission)."
  fi
}


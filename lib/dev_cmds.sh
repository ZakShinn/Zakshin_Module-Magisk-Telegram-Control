# shellcheck shell=sh
# Lệnh /dev bổ sung — điều khiển qua svc / cmd / settings / am / input

_dev_settings_put() {
  if command -v settings >/dev/null 2>&1; then
    settings put "$@" 2>/dev/null && return 0
  fi
  return 1
}

_dev_settings_get() {
  command -v settings >/dev/null 2>&1 || return 1
  settings get "$@" 2>/dev/null
}

# --- Mạng / radio ---
handle_airplane_on() {
  ok=0
  if command -v cmd >/dev/null 2>&1; then
    cmd connectivity airplane-mode enable 2>/dev/null && ok=1
  fi
  if [ "$ok" != "1" ]; then
    _dev_settings_put global airplane_mode_on 1 && ok=1
    am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true >/dev/null 2>&1 || true
  fi
  if [ "$ok" = "1" ]; then
    send_code "✅ Chế độ máy bay: <b>ĐANG BẬT</b>"
  else
    send_code "❌ Không bật được máy bay (ROM chặn <code>cmd connectivity</code> / settings)."
  fi
}

handle_airplane_off() {
  ok=0
  if command -v cmd >/dev/null 2>&1; then
    cmd connectivity airplane-mode disable 2>/dev/null && ok=1
  fi
  if [ "$ok" != "1" ]; then
    _dev_settings_put global airplane_mode_on 0 && ok=1
    am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false >/dev/null 2>&1 || true
  fi
  if [ "$ok" = "1" ]; then
    send_code "✅ Chế độ máy bay: <b>ĐÃ TẮT</b>"
  else
    send_code "❌ Không tắt được máy bay."
  fi
}

handle_data_on() {
  if svc data enable 2>/dev/null; then
    send_code "✅ Dữ liệu di động: <b>ĐANG BẬT</b> (<code>svc data enable</code>)"
    return
  fi
  if _dev_settings_put global mobile_data 1; then
    send_code "✅ Dữ liệu di động: <b>ĐANG BẬT</b> (settings)"
    return
  fi
  send_code "❌ Không bật được mobile data."
}

handle_data_off() {
  if svc data disable 2>/dev/null; then
    send_code "✅ Dữ liệu di động: <b>ĐÃ TẮT</b>"
    return
  fi
  if _dev_settings_put global mobile_data 0; then
    send_code "✅ Dữ liệu di động: <b>ĐÃ TẮT</b> (settings)"
    return
  fi
  send_code "❌ Không tắt được mobile data."
}

handle_nfc_on() {
  if svc nfc enable 2>/dev/null; then
    send_code "✅ NFC: <b>ĐANG BẬT</b>"
  else
    send_code "❌ Không bật NFC (<code>svc nfc</code> không khả dụng)."
  fi
}

handle_nfc_off() {
  if svc nfc disable 2>/dev/null; then
    send_code "✅ NFC: <b>ĐÃ TẮT</b>"
  else
    send_code "❌ Không tắt NFC."
  fi
}

handle_wifi_info() {
  dump="$(dumpsys wifi 2>/dev/null)"
  ssid="$(printf '%s' "$dump" | sed -n 's/.*SSID: \(.*\),.*/\1/p' | head -n1)"
  [ -z "$ssid" ] && ssid="$(printf '%s' "$dump" | sed -n 's/.*mWifiInfo SSID: \(.*\),.*/\1/p' | head -n1)"
  rssi="$(printf '%s' "$dump" | sed -n 's/.*RSSI: \(-[0-9]*\).*/\1/p' | head -n1)"
  [ -z "$rssi" ] && rssi="$(printf '%s' "$dump" | sed -n 's/.*rssi=\(-[0-9]*\).*/\1/p' | head -n1)"
  freq="$(printf '%s' "$dump" | sed -n 's/.*frequency: \([0-9]*\).*/\1/p' | head -n1)"
  state="$(printf '%s' "$dump" | sed -n 's/.*Wi-Fi is \(enabled\|disabled\).*/\1/p' | head -n1)"
  [ -z "$state" ] && state="$(getprop wifi.supplicant 2>/dev/null)"

  if [ -z "$ssid" ] && [ -z "$rssi" ]; then
    send_code "ℹ️ Không đọc được Wi‑Fi từ <code>dumpsys wifi</code> (có thể đang tắt hoặc ROM khác định dạng)."
    return
  fi

  ssid_esc="$(escape_html "${ssid:-—}")"
  rssi_esc="$(escape_html "${rssi:-—}")"
  freq_esc="$(escape_html "${freq:-—}")"
  state_esc="$(escape_html "${state:-—}")"

  send_code "<b>📶 Wi‑Fi</b>
Trạng thái: <code>${state_esc}</code>
SSID: <code>${ssid_esc}</code>
RSSI: <code>${rssi_esc} dBm</code>
Tần số: <code>${freq_esc} MHz</code>"
}

# --- Màn hình / âm thanh ---
handle_torch_on() {
  if command -v cmd >/dev/null 2>&1 && cmd flashlight enable 2>/dev/null; then
    send_code "✅ Đèn pin: <b>BẬT</b>"
    return
  fi
  for f in /sys/class/leds/*/brightness /sys/class/leds/torch-light0/brightness; do
    if [ -w "$f" ]; then
      echo 255 >"$f" 2>/dev/null && {
        send_code "✅ Đèn pin: <b>BẬT</b> (sysfs)"
        return
      }
    fi
  done
  send_code "❌ Không bật đèn pin (<code>cmd flashlight</code> / sysfs)."
}

handle_torch_off() {
  if command -v cmd >/dev/null 2>&1 && cmd flashlight disable 2>/dev/null; then
    send_code "✅ Đèn pin: <b>TẮT</b>"
    return
  fi
  for f in /sys/class/leds/*/brightness /sys/class/leds/torch-light0/brightness; do
    if [ -w "$f" ]; then
      echo 0 >"$f" 2>/dev/null && {
        send_code "✅ Đèn pin: <b>TẮT</b>"
        return
      }
    fi
  done
  send_code "❌ Không tắt đèn pin."
}

handle_screen_on() {
  input keyevent 224 2>/dev/null || input keyevent KEYCODE_WAKEUP 2>/dev/null || svc power stayon true 2>/dev/null || true
  send_code "✅ Đã gửi lệnh <b>bật màn hình</b> (<code>KEYCODE_WAKEUP</code>)."
}

handle_screen_off() {
  input keyevent 223 2>/dev/null || input keyevent KEYCODE_SLEEP 2>/dev/null || true
  send_code "✅ Đã gửi lệnh <b>tắt màn hình</b> (<code>KEYCODE_SLEEP</code> — có thể khóa máy)."
}

handle_brightness() {
  rest="$1"
  rest="$(echo "$rest" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  cur="$(_dev_settings_get system screen_brightness 2>/dev/null)"
  if [ -z "$rest" ]; then
    send_code "💡 Độ sáng hiện tại: <code>$(escape_html "${cur:-?}")</code> (0–255)
Đặt: <code>/brightness 128</code>"
    return
  fi
  case "$rest" in
    *[!0-9]*)
      send_code "❌ Dùng số 0–255, ví dụ <code>/brightness 200</code>."
      return
      ;;
  esac
  if [ "$rest" -gt 255 ] 2>/dev/null; then
    send_code "❌ Độ sáng tối đa 255."
    return
  fi
  if _dev_settings_put system screen_brightness "$rest"; then
    send_code "✅ Độ sáng → <code>${rest}</code>"
  else
    send_code "❌ Không đặt được độ sáng (settings)."
  fi
}

handle_volume() {
  rest="$1"
  rest="$(echo "$rest" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  stream=3
  if command -v cmd >/dev/null 2>&1; then
    cur="$(cmd media_session volume --stream "$stream" --get 2>/dev/null | tail -n1)"
  fi
  [ -z "$cur" ] && cur="$(_dev_settings_get system volume_music_speaker 2>/dev/null)"
  if [ -z "$rest" ]; then
    send_code "🔊 Âm lượng media: <code>$(escape_html "${cur:-?}")</code>
Đặt: <code>/volume 10</code> (thang 0–15 tùy ROM)"
    return
  fi
  case "$rest" in
    *[!0-9]*)
      send_code "❌ Dùng số nguyên, ví dụ <code>/volume 8</code>."
      return
      ;;
  esac
  if command -v cmd >/dev/null 2>&1 && cmd media_session volume --stream "$stream" --set "$rest" 2>/dev/null; then
    send_code "✅ Âm lượng media → <code>${rest}</code>"
    return
  fi
  if _dev_settings_put system volume_music_speaker "$rest"; then
    send_code "✅ Âm lượng (settings) → <code>${rest}</code>"
  else
    send_code "❌ Không đặt được âm lượng."
  fi
}

# --- Hệ thống / thông tin ---
handle_storage() {
  line="$(_status_get_storage_line 2>/dev/null)"
  df_out="$(df -h /data 2>/dev/null | tail -n1)"
  if [ -n "$df_out" ]; then
  used="$(echo "$df_out" | awk '{print $3}')"
  avail="$(echo "$df_out" | awk '{print $4}')"
  total="$(echo "$df_out" | awk '{print $2}')"
  pct="$(echo "$df_out" | awk '{print $5}')"
  send_code "<b>💾 Bộ nhớ /data</b>
Đã dùng: <code>$(escape_html "$used")</code> / <code>$(escape_html "$total")</code> (<code>$(escape_html "$pct")</code>)
Còn trống: <code>$(escape_html "$avail")</code>"
  else
    send_code "💾 Lưu trữ: <code>$(escape_html "$line")</code>"
  fi
}

handle_mem() {
  line="$(_status_get_ram_line 2>/dev/null)"
  send_code "<b>🧠 RAM</b>
<code>$(escape_html "$line")</code>"
}

handle_uptime() {
  up="$(_status_get_uptime_long_vi 2>/dev/null)"
  load="$(awk '{print $1" "$2" "$3}' /proc/loadavg 2>/dev/null || echo '—')"
  send_code "<b>⏱ Uptime</b>
<code>$(escape_html "$up")</code>
Load: <code>$(escape_html "$load")</code>"
}

handle_reboot_recovery() {
  if ! tg_boot_grace_ok; then
    send_code "⏳ Bỏ qua — thiết bị vừa khởi động (chờ ~${TG_BOOT_GRACE_SEC}s uptime)."
    return
  fi
  send_code "🔄 Đang khởi động lại vào <b>recovery</b>…"
  reboot recovery 2>/dev/null || su -c "reboot recovery" 2>/dev/null || true
}

handle_reboot_bootloader() {
  if ! tg_boot_grace_ok; then
    send_code "⏳ Bỏ qua — thiết bị vừa khởi động (chờ ~${TG_BOOT_GRACE_SEC}s uptime)."
    return
  fi
  send_code "🔄 Đang khởi động lại vào <b>bootloader</b>…"
  reboot bootloader 2>/dev/null || su -c "reboot bootloader" 2>/dev/null || true
}

handle_prop() {
  name="$1"
  name="$(echo "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [ -z "$name" ]; then
    send_code "❌ Cú pháp: <code>/prop tên.thuộc.tính</code>
Ví dụ: <code>/prop ro.build.version.release</code>"
    return
  fi
  case "$name" in
    *[!a-zA-Z0-9._-]*)
      send_code "❌ Tên prop không hợp lệ."
      return
      ;;
  esac
  val="$(getprop "$name" 2>/dev/null)"
  [ -z "$val" ] && val="(trống hoặc không tồn tại)"
  send_code "<b>getprop</b> <code>$(escape_html "$name")</code>
<pre>$(escape_html "$val")</pre>"
}

# --- Ứng dụng ---
_dev_sanitize_pkg() {
  echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d ' '
}

handle_kill() {
  pkg="$(_dev_sanitize_pkg "$1")"
  if [ -z "$pkg" ]; then
    send_code "❌ Cú pháp: <code>/kill com.example.app</code>"
    return
  fi
  case "$pkg" in
    *[!a-zA-Z0-9._]*)
      send_code "❌ Tên gói không hợp lệ."
      return
      ;;
  esac
  am force-stop "$pkg" 2>/dev/null
  send_code "✅ Đã <code>am force-stop</code> → <code>$(escape_html "$pkg")</code>"
}

handle_open() {
  pkg="$(_dev_sanitize_pkg "$1")"
  if [ -z "$pkg" ]; then
    send_code "❌ Cú pháp: <code>/open com.example.app</code>"
    return
  fi
  case "$pkg" in
    *[!a-zA-Z0-9._]*)
      send_code "❌ Tên gói không hợp lệ."
      return
      ;;
  esac
  if monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; then
    send_code "✅ Đã mở <code>$(escape_html "$pkg")</code>"
    return
  fi
  if am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p "$pkg" >/dev/null 2>&1; then
    send_code "✅ Đã mở <code>$(escape_html "$pkg")</code> (am start)"
  else
    send_code "❌ Không mở được <code>$(escape_html "$pkg")</code>."
  fi
}

# --- Cài đặt nhanh ---
handle_sync_on() {
  if _dev_settings_put global auto_sync 1; then
    send_code "✅ Đồng bộ tài khoản: <b>BẬT</b>"
  else
    send_code "❌ Không bật auto_sync."
  fi
}

handle_sync_off() {
  if _dev_settings_put global auto_sync 0; then
    send_code "✅ Đồng bộ tài khoản: <b>TẮT</b>"
  else
    send_code "❌ Không tắt auto_sync."
  fi
}

handle_location_on() {
  if _dev_settings_put secure location_mode 3; then
    send_code "✅ GPS / vị trí: <b>BẬT</b> (chế độ cao)"
  else
    send_code "❌ Không bật location (settings secure)."
  fi
}

handle_location_off() {
  if _dev_settings_put secure location_mode 0; then
    send_code "✅ GPS / vị trí: <b>TẮT</b>"
  else
    send_code "❌ Không tắt location."
  fi
}

handle_dnd_on() {
  if command -v cmd >/dev/null 2>&1 && cmd notification set_interruption_filter 2 >/dev/null 2>&1; then
    send_code "✅ Không làm phiền (DND): <b>BẬT</b>"
    return
  fi
  if _dev_settings_put global zen_mode 1; then
    send_code "✅ DND (zen_mode): <b>BẬT</b>"
  else
    send_code "❌ Không bật DND."
  fi
}

handle_dnd_off() {
  if command -v cmd >/dev/null 2>&1 && cmd notification set_interruption_filter 1 >/dev/null 2>&1; then
    send_code "✅ Không làm phiền: <b>TẮT</b>"
    return
  fi
  if _dev_settings_put global zen_mode 0; then
    send_code "✅ DND: <b>TẮT</b>"
  else
    send_code "❌ Không tắt DND."
  fi
}

_dev_out_trim() {
  printf '%s' "$1" | head -c 3600
}

# --- Bổ sung: màn hình / âm thanh ---
handle_stayon_on() {
  svc power stayon true 2>/dev/null || settings put system stay_on_while_plugged_in 7 2>/dev/null || true
  send_code "✅ Giữ màn hình sáng khi cắm sạc / stayon: <b>BẬT</b>"
}

handle_stayon_off() {
  svc power stayon false 2>/dev/null || settings put system stay_on_while_plugged_in 0 2>/dev/null || true
  send_code "✅ Đã tắt chế độ giữ màn sáng (stayon)."
}

handle_lock() {
  input keyevent 26 2>/dev/null || input keyevent KEYCODE_POWER 2>/dev/null || true
  send_code "✅ Đã gửi lệnh <b>khóa màn hình</b>."
}

handle_rotate_on() {
  _dev_settings_put system accelerometer_rotation 1 && send_code "✅ Xoay màn hình tự động: <b>BẬT</b>" \
    || send_code "❌ Không bật xoay màn hình."
}

handle_rotate_off() {
  _dev_settings_put system accelerometer_rotation 0
  _dev_settings_put system user_rotation 0 2>/dev/null || true
  send_code "✅ Xoay màn hình tự động: <b>TẮT</b> (khóa dọc)."
}

handle_ringer_normal() {
  if command -v cmd >/dev/null 2>&1 && cmd audio set-ringer-mode normal 2>/dev/null; then
    send_code "✅ Chuông: <b>chuẩn</b>"
    return
  fi
  _dev_settings_put global mode_ringer 2 && send_code "✅ Chuông: chế độ chuẩn" || send_code "❌ Không đổi được chuông."
}

handle_ringer_silent() {
  if command -v cmd >/dev/null 2>&1 && cmd audio set-ringer-mode silent 2>/dev/null; then
    send_code "✅ Chuông: <b>im lặng</b>"
    return
  fi
  _dev_settings_put global mode_ringer 0 && send_code "✅ Chuông: im lặng" || send_code "❌ Không đổi được chuông."
}

handle_ringer_vibrate() {
  if command -v cmd >/dev/null 2>&1 && cmd audio set-ringer-mode vibrate 2>/dev/null; then
    send_code "✅ Chuông: <b>rung</b>"
    return
  fi
  _dev_settings_put global mode_ringer 1 && send_code "✅ Chuông: rung" || send_code "❌ Không đổi được chuông."
}

handle_vol_up() {
  input keyevent 24 2>/dev/null || true
  send_code "🔊 Vol+"
}

handle_vol_down() {
  input keyevent 25 2>/dev/null || true
  send_code "🔉 Vol−"
}

handle_media_play() {
  input keyevent 85 2>/dev/null || true
  send_code "⏯ Play/Pause"
}

handle_brightness_auto() {
  _dev_settings_put system screen_brightness_mode 1 && send_code "✅ Độ sáng: <b>tự động</b>" || send_code "❌ Không bật auto brightness."
}

handle_brightness_manual() {
  _dev_settings_put system screen_brightness_mode 0 && send_code "✅ Độ sáng: <b>thủ công</b>" || send_code "❌ Không tắt auto brightness."
}

handle_anim_off() {
  _dev_settings_put global window_animation_scale 0
  _dev_settings_put global transition_animation_scale 0
  _dev_settings_put global animator_duration_scale 0
  send_code "✅ Tắt animation hệ thống (0x)."
}

handle_anim_on() {
  _dev_settings_put global window_animation_scale 1
  _dev_settings_put global transition_animation_scale 1
  _dev_settings_put global animator_duration_scale 1
  send_code "✅ Bật animation hệ thống (1x)."
}

handle_screenshot() {
  path="/data/local/tmp/tg_bot_screen.png"
  rm -f "$path" 2>/dev/null || true
  if screencap -p "$path" 2>/dev/null || screencap "$path" 2>/dev/null; then
    if send_photo "$path" "📸 Screenshot"; then
      send_code "✅ Đã gửi ảnh chụp màn hình."
    else
      send_code "❌ Chụp được nhưng gửi Telegram thất bại."
    fi
    rm -f "$path" 2>/dev/null || true
  else
    send_code "❌ <code>screencap</code> thất bại."
  fi
}

# --- Mạng bổ sung ---
handle_wifi_scan() {
  out=""
  if command -v cmd >/dev/null 2>&1; then
    out="$(cmd wifi list-scan-results 2>/dev/null | head -n 25)"
  fi
  [ -z "$out" ] && out="$(dumpsys wifi 2>/dev/null | grep -E 'SSID:|BSSID:|RSSI:' | head -n 40)"
  [ -z "$out" ] && {
    send_code "❌ Không quét được Wi‑Fi (bật Wi‑Fi và thử lại)."
    return
  }
  out_esc="$(printf '%s' "$out" | head -c 3200 | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"
  send_code "<b>📡 Quét Wi‑Fi</b>
<pre>${out_esc}</pre>"
}

handle_bt_info() {
  dump="$(dumpsys bluetooth_manager 2>/dev/null; dumpsys bluetooth 2>/dev/null)"
  state="$(printf '%s' "$dump" | grep -iE 'enabled: true|state=ON|mState=12' | head -n1)"
  name="$(printf '%s' "$dump" | sed -n 's/.*name: \(.*\)/\1/p' | head -n1)"
  [ -z "$name" ] && name="$(getprop bluetooth.name 2>/dev/null)"
  if printf '%s' "$dump" | grep -qi 'enabled: true\|state=ON'; then
    st="Bật ✅"
  else
    st="Tắt ❌"
  fi
  send_code "<b>📳 Bluetooth</b>
Trạng thái: ${st}
Tên: <code>$(escape_html "${name:-—}")</code>"
}

handle_tether_status() {
  dump="$(dumpsys connectivity 2>/dev/null | grep -iE 'tether|usb|rndis|ncm|hotspot' | head -n 20)"
  usb="$(getprop_safe sys.usb.config)"
  [ -z "$dump" ] && dump="(không có dòng tether trong dumpsys)"
  dump_esc="$(printf '%s' "$dump" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"
  send_code "<b>🔗 Tether / USB</b>
<code>sys.usb.config</code>=<code>$(escape_html "$usb")</code>
<pre>${dump_esc}</pre>"
}

handle_usb_status() {
  send_code "<b>🔌 USB</b>
state: <code>$(escape_html "$(getprop_safe sys.usb.state)")</code>
config: <code>$(escape_html "$(getprop_safe sys.usb.config)")</code>
configfs: <code>$(escape_html "$(getprop_safe sys.usb.configfs)")</code>"
}

handle_dns() {
  d1="$(getprop net.dns1 2>/dev/null)"
  d2="$(getprop net.dns2 2>/dev/null)"
  priv="$(dumpsys connectivity 2>/dev/null | grep -i 'DnsAddresses' | head -n 3)"
  send_code "<b>🌐 DNS</b>
net.dns1: <code>$(escape_html "${d1:-—}")</code>
net.dns2: <code>$(escape_html "${d2:-—}")</code>
<pre>$(escape_html "$(printf '%s' "$priv" | head -c 800)")</pre>"
}

handle_net_if() {
  if command -v ip >/dev/null 2>&1; then
    out="$(ip -br addr 2>/dev/null | head -n 25)"
  else
    out="$(ifconfig 2>/dev/null | head -n 40)"
  fi
  [ -z "$out" ] && { send_code "❌ Không đọc được interface."; return; }
  out_esc="$(printf '%s' "$out" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"
  send_code "<b>🖧 Giao diện mạng</b>
<pre>${out_esc}</pre>"
}

handle_hotspot_status() {
  hs="$(get_hotspot_state_simple 2>/dev/null || echo "?")"
  send_code "<b>📡 Hotspot</b>: <code>$(escape_html "$hs")</code>
(dumpsys wifi / softap)"
}

# --- Hệ thống bổ sung ---
handle_device() {
  rel="$(getprop ro.build.version.release 2>/dev/null)"
  sdk="$(getprop ro.build.version.sdk 2>/dev/null)"
  model="$(getprop ro.product.model 2>/dev/null)"
  brand="$(getprop ro.product.brand 2>/dev/null)"
  build="$(getprop ro.build.display.id 2>/dev/null)"
  sel="$(getenforce 2>/dev/null || echo '?')"
  send_code "<b>📱 Thiết bị</b>
${brand} ${model}
Android <code>$(escape_html "$rel")</code> (SDK <code>$(escape_html "$sdk")</code>)
Build: <code>$(escape_html "$build")</code>
SELinux: <code>$(escape_html "$sel")</code>"
}

handle_cpu() {
  freq="$(_status_get_cpu_freq 2>/dev/null)"
  temp="$(_status_get_cpu_temp 2>/dev/null)"
  load="$(awk '{print $1" "$2" "$3}' /proc/loadavg 2>/dev/null)"
  topout=""
  if top -n 1 -b 2>/dev/null | head -n 12 | grep -q .; then
    topout="$(top -n 1 -b 2>/dev/null | head -n 12)"
  elif dumpsys cpuinfo 2>/dev/null | head -n 15 | grep -q .; then
    topout="$(dumpsys cpuinfo 2>/dev/null | head -n 15)"
  fi
  top_esc="$(printf '%s' "$topout" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' | head -c 2400)"
  send_code "<b>⚙️ CPU</b>
Tần số: <code>$(escape_html "$freq")</code> · Nhiệt: <code>$(escape_html "$temp")</code>
Load: <code>$(escape_html "$load")</code>
<pre>${top_esc}</pre>"
}

handle_temp() {
  out=""
  for f in /sys/class/thermal/thermal_zone*/temp; do
    [ -f "$f" ] || continue
    t="$(cat "$f" 2>/dev/null)"
    case "$t" in ''|*[!0-9]*) continue ;; esac
    if [ ${#t} -gt 3 ] 2>/dev/null; then
      t="$((t / 1000))°C"
    else
      t="${t}°C"
    fi
    zone="$(basename "$(dirname "$f")")"
    out="${out}${zone}: ${t}
"
  done
  [ -z "$out" ] && { send_code "❌ Không đọc được thermal zone."; return; }
  send_code "<b>🌡 Nhiệt độ</b>
<pre>$(escape_html "$(printf '%s' "$out" | head -c 3000)")</pre>"
}

handle_datetime() {
  send_code "<b>🕐 Thời gian</b>
<code>$(escape_html "$(date '+%d/%m/%Y %H:%M:%S %Z' 2>/dev/null)")</code>
TZ: <code>$(escape_html "$(getprop persist.sys.timezone 2>/dev/null)")</code>"
}

handle_rootid() {
  idout="$(id 2>/dev/null)"
  send_code "<b>🔐 Quyền</b>
<pre>$(escape_html "$idout")</pre>
SELinux: <code>$(escape_html "$(getenforce 2>/dev/null)")</code>"
}

handle_logcat() {
  lines="${1:-40}"
  case "$lines" in ''|*[!0-9]*) lines=40 ;; esac
  [ "$lines" -gt 200 ] 2>/dev/null && lines=200
  out="$(logcat -d -t "$lines" 2>/dev/null)"
  [ -z "$out" ] && { send_code "❌ logcat trống hoặc bị chặn."; return; }
  out_esc="$(printf '%s' "$out" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' | tail -c 3500)"
  send_code "<b>📋 logcat</b> (≤${lines} dòng)
<pre>${out_esc}</pre>"
}

handle_logcat_clear() {
  logcat -c 2>/dev/null && send_code "✅ Đã xóa buffer logcat." || send_code "❌ Không xóa được logcat."
}

handle_dmesg() {
  out="$(dmesg 2>/dev/null | tail -n 35)"
  [ -z "$out" ] && { send_code "❌ dmesg không khả dụng."; return; }
  out_esc="$(printf '%s' "$out" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' | head -c 3500)"
  send_code "<b>📋 dmesg</b> (cuối)
<pre>${out_esc}</pre>"
}

# --- Ứng dụng bổ sung ---
handle_packages() {
  filter="$1"
  filter="$(echo "$filter" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [ -n "$filter" ]; then
    list="$(pm list packages 2>/dev/null | grep -i "$filter" | head -n 30)"
  else
    list="$(pm list packages -3 2>/dev/null | head -n 35)"
  fi
  [ -z "$list" ] && { send_code "ℹ️ Không có gói khớp."; return; }
  list_esc="$(printf '%s' "$list" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"
  send_code "<b>📦 Gói cài sẵn</b> (user, tối đa 35)
<pre>${list_esc}</pre>
Lọc: <code>/packages từ_khóa</code>"
}

handle_pkg() {
  pkg="$(_dev_sanitize_pkg "$1")"
  [ -z "$pkg" ] && { send_code "❌ <code>/pkg com.app</code>"; return; }
  ver="$(dumpsys package "$pkg" 2>/dev/null | sed -n 's/.*versionName=\([^ ]*\).*/\1/p' | head -n1)"
  code="$(dumpsys package "$pkg" 2>/dev/null | sed -n 's/.*versionCode=\([0-9]*\).*/\1/p' | head -n1)"
  path="$(pm path "$pkg" 2>/dev/null | head -n1 | sed 's/package://')"
  [ -z "$ver" ] && { send_code "❌ Không tìm thấy <code>$(escape_html "$pkg")</code>."; return; }
  send_code "<b>📦 $(escape_html "$pkg")</b>
versionName: <code>$(escape_html "$ver")</code>
versionCode: <code>$(escape_html "${code:-?}")</code>
apk: <code>$(escape_html "${path:-?}")</code>"
}

handle_clear() {
  pkg="$(_dev_sanitize_pkg "$1")"
  [ -z "$pkg" ] && { send_code "❌ <code>/clear com.app</code> — xóa dữ liệu app."; return; }
  if pm clear "$pkg" 2>/dev/null; then
    send_code "✅ Đã <code>pm clear</code> → <code>$(escape_html "$pkg")</code>"
  else
    send_code "❌ Không clear được <code>$(escape_html "$pkg")</code>."
  fi
}

handle_input_text() {
  text="$1"
  text="$(echo "$text" | sed 's/^[[:space:]]*//')"
  [ -z "$text" ] && { send_code "❌ <code>/input Văn bản</code>"; return; }
  if input text "$text" 2>/dev/null; then
    send_code "✅ Đã gõ: <code>$(escape_html "$(printf '%s' "$text" | head -c 200)")</code>"
  else
    send_code "❌ <code>input text</code> thất bại (focus vào ô nhập trước)."
  fi
}

handle_unknown_sources_on() {
  _dev_settings_put secure install_non_market_apps 1 2>/dev/null \
    || _dev_settings_put global install_non_market_apps 1 2>/dev/null
  send_code "✅ Cho phép cài APK ngoài CH Play (nếu ROM hỗ trợ settings)."
}

handle_unknown_sources_off() {
  _dev_settings_put secure install_non_market_apps 0 2>/dev/null \
    || _dev_settings_put global install_non_market_apps 0 2>/dev/null
  send_code "✅ Chặn cài APK nguồn không xác định (settings)."
}

# Danh sách /dev — một tin, HTML gọn (Telegram parse_mode HTML)
dev_commands_help_full() {
  cat <<'EOF'
<b>🛠 Lệnh nâng cao · /dev</b>
<i>Một số lệnh phụ thuộc ROM / quyền — thử từng lệnh nếu không phản hồi</i>
<code>────────────────────────</code>

<b>📡 Mạng</b>
• <code>/airplane_on</code> · <code>/airplane_off</code> — Máy bay
• <code>/data_on</code> · <code>/data_off</code> — Dữ liệu di động
• <code>/nfc_on</code> · <code>/nfc_off</code> — NFC
• <code>/wifi_on</code> · <code>/wifi_off</code> · <code>/wifi_info</code> · <code>/wifi_scan</code>
• <code>/bt_on</code> · <code>/bt_off</code> · <code>/bt_info</code>
• <code>/usb_lan_on</code> · <code>/usb_lan_off</code> · <code>/rndis_on</code> · <code>/rndis_off</code>
• <code>/usb_status</code> · <code>/tether_status</code> · <code>/dns</code> · <code>/net_if</code>
• <code>/hotspot_on</code> [SSID mật_khẩu] · <code>/hotspot_off</code> · <code>/hotspot_status</code>

<b>🖥 Màn hình · âm thanh</b>
• <code>/torch_on</code> · <code>/torch_off</code> · <code>/screen_on</code> · <code>/screen_off</code>
• <code>/lock</code> · <code>/screenshot</code>
• <code>/brightness</code> [0–255] · <code>/brightness_auto</code> · <code>/brightness_manual</code>
• <code>/volume</code> [0–15] · <code>/vol_up</code> · <code>/vol_down</code> · <code>/media_play</code>
• <code>/stayon_on</code> · <code>/stayon_off</code> · <code>/rotate_on</code> · <code>/rotate_off</code>
• <code>/ringer_normal</code> · <code>/ringer_silent</code> · <code>/ringer_vibrate</code>
• <code>/anim_on</code> · <code>/anim_off</code>

<b>⚙️ Hệ thống</b>
• <code>/device</code> · <code>/cpu</code> · <code>/temp</code> · <code>/storage</code> · <code>/mem</code>
• <code>/uptime</code> · <code>/datetime</code>
• <code>/prop</code> tên_thuộc_tính · <code>/rootid</code>
• <code>/logcat</code> [số_dòng] · <code>/logcat_clear</code> · <code>/dmesg</code>
• <code>/reboot_recovery</code> · <code>/reboot_bootloader</code>

<b>📦 Ứng dụng</b>
• <code>/packages</code> [lọc] · <code>/pkg</code> tên_gói · <code>/open</code> · <code>/kill</code> · <code>/clear</code>
• <code>/input</code> văn_bản (focus ô nhập trước)
• <code>/unknown_sources_on</code> · <code>/unknown_sources_off</code>

<b>📨 SMS</b>
• <code>/sent_sms</code> SĐT nội_dung — Gửi SMS (vd: <code>/sent_sms 888 data_on</code>)

<b>🔁 Khác</b>
• <code>/sync_on</code> · <code>/sync_off</code> — Đồng bộ
• <code>/location_on</code> · <code>/location_off</code> — GPS
• <code>/dnd_on</code> · <code>/dnd_off</code> — Không làm phiền
• SMS mới → Telegram <i>(tự bật khi bot chạy)</i> · <code>/sms_watch_off</code> tạm dừng · <code>/sms_watch_on</code> bật lại
• <code>/loop_on</code> &lt;phút&gt; &lt;lệnh&gt; · <code>/loop_off</code>

<code>────────────────────────</code>
<i>Lệnh cơ bản: gõ /help · Tham số [ ] là tuỳ chọn</i>
EOF
}

dev_commands_send_help() {
  send_code "$(dev_commands_help_full)"
}

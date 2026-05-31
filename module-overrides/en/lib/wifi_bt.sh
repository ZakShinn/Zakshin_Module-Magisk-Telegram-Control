# shellcheck shell=sh
# Toggle Wi‑Fi and Bluetooth via svc/cmd (depends on ROM).

handle_wifi_on() {
  if svc wifi enable 2>/dev/null || cmd wifi set-wifi-enabled enabled 2>/dev/null; then
    send_code "✅ Wi‑Fi is ON."
  else
    send_code "❌ Failed to enable Wi‑Fi (try <code>svc wifi enable</code> / root permission / ROM)."
  fi
}

handle_wifi_off() {
  if svc wifi disable 2>/dev/null || cmd wifi set-wifi-enabled disabled 2>/dev/null; then
    send_code "✅ Wi‑Fi is OFF."
  else
    send_code "❌ Failed to disable Wi‑Fi (ROM or permission)."
  fi
}

handle_bt_on() {
  if svc bluetooth enable 2>/dev/null || cmd bluetooth_manager enable 2>/dev/null; then
    send_code "✅ Bluetooth is ON."
  else
    send_code "❌ Failed to enable Bluetooth (try <code>svc bluetooth enable</code> / ROM)."
  fi
}

handle_bt_off() {
  if svc bluetooth disable 2>/dev/null || cmd bluetooth_manager disable 2>/dev/null; then
    send_code "✅ Bluetooth is OFF."
  else
    send_code "❌ Failed to disable Bluetooth (ROM or permission)."
  fi
}


#!/system/bin/sh
test_cmd() {
  name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "OK  $name"
  else
    echo "FAIL $name"
  fi
}

echo "=== Dev backends (read-only / safe) ==="
test_cmd settings settings get global airplane_mode_on
test_cmd dumpsys_wifi dumpsys wifi
test_cmd dumpsys_bt dumpsys bluetooth_manager
test_cmd dumpsys_usb dumpsys usb
test_cmd dumpsys_net dumpsys connectivity
test_cmd screencap screencap -h
test_cmd cmd_wifi cmd wifi status
test_cmd thermal cat /sys/class/thermal/thermal_zone0/temp
test_cmd df df -h /data
test_cmd meminfo head -n 3 /proc/meminfo
test_cmd logcat logcat -t 3
test_cmd pm_list pm list packages -3
if command -v cmd >/dev/null 2>&1; then
  cmd flashlight 2>/dev/null; ec=$?
  [ "$ec" = 0 ] && echo "OK  cmd_flashlight" || echo "FAIL cmd_flashlight (ec=$ec)"
else
  echo "SKIP cmd"
fi

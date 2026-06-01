#!/system/bin/sh
# Smoke-test backends used by /dev commands (run: adb shell su -c 'sh /sdcard/test-dev-on-device.sh')
MOD="${MOD:-/data/adb/modules/TelegramControl}"
ok=0
fail=0
skip=0

t() {
  name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "OK  $name"
    ok=$((ok + 1))
  else
    echo "FAIL $name"
    fail=$((fail + 1))
  fi
}

t_skip() {
  echo "SKIP $1"
  skip=$((skip + 1))
}

echo "=== Dev command backend smoke test ==="
echo "Module: $MOD"
echo ""

t "settings" command -v settings
t "svc" command -v svc
t "cmd" command -v cmd
t "content" command -v content
t "dumpsys battery" dumpsys battery
t "getprop ro.product.model" getprop ro.product.model
t "inbox query" content query --uri content://sms/inbox --projection _id:address:date:body --sort 'date DESC'

if [ -f "$MOD/lib/sms.sh" ]; then
  # shellcheck source=/dev/null
  . "$MOD/lib/common.sh"
  . "$MOD/lib/sms.sh"
  line="$(content query --uri content://sms/inbox --projection _id:address:date:body --sort 'date DESC' | grep '^Row:' | head -n1)"
  body="$(_sms_parse_body_from_row "$line")"
  if [ -n "$body" ]; then
    echo "OK  sms body parse"
    ok=$((ok + 1))
  else
    echo "FAIL sms body parse"
    fail=$((fail + 1))
  fi
else
  t_skip "sms.sh not at $MOD"
fi

if [ -f "$MOD/lib/dev_cmds.sh" ]; then
  for fn in handle_device handle_cpu handle_storage handle_mem handle_wifi_info handle_usb_status; do
    if grep -q "^${fn}()" "$MOD/lib/dev_cmds.sh" 2>/dev/null; then
      echo "OK  fn $fn defined"
      ok=$((ok + 1))
    else
      echo "FAIL fn $fn missing"
      fail=$((fail + 1))
    fi
  done
else
  t_skip "dev_cmds.sh"
fi

if [ -f "$MOD/lib/handlers.sh" ]; then
  grep -q '/sentsms' "$MOD/lib/handlers.sh" && echo "OK  handler /sentsms" || echo "FAIL handler /sentsms"
  grep -q 'handle_sentsms' "$MOD/lib/handlers.sh" && echo "OK  dispatch handle_sentsms" || echo "FAIL dispatch (use lib/sms.sh)"
  grep -q '/sms_watch_off' "$MOD/lib/handlers.sh" && echo "OK  handler /sms_watch_off"
fi

echo ""
echo "=== Summary: OK=$ok FAIL=$fail SKIP=$skip ==="

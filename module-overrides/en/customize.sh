#!/system/bin/sh
# Post-extract checks — percentage bar + clear errors (Magisk-compatible installers).

umask 022

TG_PAYPAL_URL="https://paypal.me/Zakshin"

_tg_progress_bar() {
  pct="$1"
  shift
  msg="$*"
  width=20
  filled=$(( pct * width / 100 ))
  empty=$(( width - filled ))
  bar=""
  i=0
  while [ "$i" -lt "$filled" ]; do
    bar="${bar}#"
    i=$(( i + 1 ))
  done
  i=0
  while [ "$i" -lt "$empty" ]; do
    bar="${bar}-"
    i=$(( i + 1 ))
  done
  ui_print "[${bar}] ${pct}% — ${msg}"
}

ui_print ""
ui_print "* PayPal (donate): ${TG_PAYPAL_URL}"
ui_print "* Bank transfer (VN): 0968884946"
ui_print ""

_tg_progress_bar 8 "Initializing checks…"
[ -n "$MODPATH" ] || abort "! Install error: MODPATH is not set."
[ -d "$MODPATH" ] || abort "! Install error: module directory missing."

TG_HAD_CONFIG=0
[ -f "$MODPATH/config.sh" ] && TG_HAD_CONFIG=1
ZIP_HAS_CONFIG=0
if [ -n "$ZIPFILE" ] && [ -f "$ZIPFILE" ]; then
  unzip -l "$ZIPFILE" 2>/dev/null | grep -qE '[[:space:]]config\.sh$' && ZIP_HAS_CONFIG=1
fi
if [ "$ZIP_HAS_CONFIG" -eq 0 ] && [ "$TG_HAD_CONFIG" -eq 1 ]; then
  ui_print "- Module update: keeping your config.sh (no uninstall needed)."
elif [ "$ZIP_HAS_CONFIG" -eq 1 ]; then
  ui_print "- config.sh embedded from ZIP (fresh install or web download)."
else
  ui_print "- No config.sh yet: use the web builder or rename config.sh.example."
fi

_tg_progress_bar 22 "Verifying module.prop…"
[ -f "$MODPATH/module.prop" ] || abort "! Install error: module.prop missing from ZIP."

_tg_progress_bar 38 "Verifying service.sh…"
[ -f "$MODPATH/service.sh" ] || abort "! Install error: service.sh missing — ZIP may be incomplete."

_tg_progress_bar 52 "Verifying lib/…"
[ -d "$MODPATH/lib" ] || abort "! Install error: lib/ folder missing."

found_lib=0
for _tg_f in "$MODPATH/lib"/*.sh; do
  [ -f "$_tg_f" ] || continue
  found_lib=1
  break
done
[ "$found_lib" -eq 1 ] || abort "! Install error: no .sh scripts under lib/."

_tg_progress_bar 68 "chmod service.sh…"
if command -v set_perm >/dev/null 2>&1; then
  set_perm "$MODPATH/service.sh" 0 0 0755 || abort "! Install error: set_perm failed on service.sh."
  if [ -d "$MODPATH/lib" ]; then
    for _tg_f in "$MODPATH/lib"/*.sh; do
      [ -f "$_tg_f" ] || continue
      set_perm "$_tg_f" 0 0 0755 || true
    done
  fi
else
  chmod 755 "$MODPATH/service.sh" || abort "! Install error: chmod 755 failed on service.sh."
  if [ -d "$MODPATH/lib" ]; then
    for _tg_f in "$MODPATH/lib"/*.sh; do
      [ -f "$_tg_f" ] || continue
      chmod 755 "$_tg_f" 2>/dev/null || true
    done
  fi
fi

_tg_progress_bar 88 "Checking shell…"
command -v sh >/dev/null 2>&1 || abort "! Install error: sh not found in PATH."

_tg_progress_bar 100 "Module checks complete."
if [ -f "$MODPATH/module.prop" ] && grep -q '^updateJson=' "$MODPATH/module.prop" 2>/dev/null; then
  ui_print "- Stable build: you can update later in Magisk (module Update button)."
else
  ui_print "- Beta / personal build: no public Magisk OTA until a stable release."
fi
ui_print "- Reboot after install or update."
ui_print ""

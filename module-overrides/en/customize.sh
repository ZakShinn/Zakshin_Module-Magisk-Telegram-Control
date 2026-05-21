#!/system/bin/sh
# Post-extract checks — supports reinstall over existing module (no uninstall).

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

_tg_progress_bar 5 "Initializing…"
[ -n "$MODPATH" ] || abort "! Install error: MODPATH is not set."
[ -d "$MODPATH" ] || abort "! Install error: module directory missing."

[ -f "$MODPATH/lib/install.sh" ] || abort "! Install error: missing lib/install.sh."
# shellcheck source=/dev/null
. "$MODPATH/lib/install.sh"

_tg_progress_bar 12 "Stopping old bot (reinstall)…"
tg_stop_old_bots

if [ -n "$ZIPFILE" ] && [ -f "$ZIPFILE" ]; then
  _tg_progress_bar 20 "Removing stale lib scripts…"
  tg_prune_orphan_lib "$MODPATH" "$ZIPFILE"
  tg_preserve_config "$MODPATH" "$ZIPFILE"
  if tg_zip_has_file "$ZIPFILE" "config.sh"; then
    ui_print "- ZIP includes config.sh — using embedded settings."
  elif [ -f "$MODPATH/config.sh" ]; then
    ui_print "- Reinstall: keeping your config.sh (no uninstall needed)."
  else
    ui_print "- No config.sh yet: use the web builder or rename config.sh.example."
  fi
else
  ui_print "- Reinstall / update (same module id TelegramControl)."
fi

_tg_progress_bar 32 "Verifying module.prop…"
[ -f "$MODPATH/module.prop" ] || abort "! Install error: module.prop missing from ZIP."

_tg_progress_bar 44 "Verifying service.sh…"
[ -f "$MODPATH/service.sh" ] || abort "! Install error: service.sh missing — ZIP may be incomplete."

_tg_progress_bar 56 "Verifying lib/…"
[ -d "$MODPATH/lib" ] || abort "! Install error: lib/ folder missing."

found_lib=0
for _tg_f in "$MODPATH/lib"/*.sh; do
  [ -f "$_tg_f" ] || continue
  found_lib=1
  break
done
[ "$found_lib" -eq 1 ] || abort "! Install error: no .sh scripts under lib/."

_tg_progress_bar 72 "Setting permissions…"
tg_chmod_exec "$MODPATH/service.sh" || abort "! Install error: could not chmod service.sh."
tg_chmod_lib_dir "$MODPATH"

_tg_progress_bar 88 "Checking shell…"
command -v sh >/dev/null 2>&1 || abort "! Install error: sh not found in PATH."

_tg_progress_bar 100 "Module checks complete."
ui_print "- You can reinstall over the old module — no uninstall required."
ui_print "- Reboot after install or update."
ui_print ""

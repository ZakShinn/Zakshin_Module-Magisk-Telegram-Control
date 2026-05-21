# shellcheck shell=sh
# Hỗ trợ cài đè / cập nhật Magisk (sourced từ customize.sh).

tg_zip_has_file() {
  zf="$1"
  entry="$2"
  [ -n "$zf" ] && [ -f "$zf" ] || return 1
  command -v unzip >/dev/null 2>&1 || return 1
  unzip -Z1 "$zf" 2>/dev/null | grep -qx "$entry"
}

tg_stop_old_bots() {
  if [ -f /data/local/tmp/tg_device_bot_service.pid ]; then
    _opid="$(cat /data/local/tmp/tg_device_bot_service.pid 2>/dev/null)"
    [ -n "$_opid" ] && kill "$_opid" 2>/dev/null
    kill -9 "$_opid" 2>/dev/null
    rm -f /data/local/tmp/tg_device_bot_service.pid 2>/dev/null
  fi
  if [ -f /data/local/tmp/tg_device_bot_loop_pids ]; then
    while IFS= read -r _lp || [ -n "$_lp" ]; do
      [ -z "$_lp" ] && continue
      kill "$_lp" 2>/dev/null
      kill -9 "$_lp" 2>/dev/null
    done < /data/local/tmp/tg_device_bot_loop_pids
    rm -f /data/local/tmp/tg_device_bot_loop_pids 2>/dev/null
  fi
  if [ -f /data/local/tmp/tg_check_sms_watch.pid ]; then
    _wp="$(cat /data/local/tmp/tg_check_sms_watch.pid 2>/dev/null)"
    [ -n "$_wp" ] && kill "$_wp" 2>/dev/null
    kill -9 "$_wp" 2>/dev/null
    rm -f /data/local/tmp/tg_check_sms_watch.pid 2>/dev/null
  fi
}

# File .sh cũ còn sót sau cài đè → gây lỗi khi service source lib.
tg_prune_orphan_lib() {
  _mp="$1"
  _zip="$2"
  [ -d "$_mp/lib" ] || return 0
  _list="$(unzip -Z1 "$_zip" 2>/dev/null)" || return 0
  for _old in "$_mp/lib"/*.sh; do
    [ -f "$_old" ] || continue
    _base="$(basename "$_old")"
    echo "$_list" | grep -qx "lib/${_base}" || rm -f "$_old" 2>/dev/null
  done
}

# Giữ config.sh khi ZIP không chứa config (cài đè chỉ code).
tg_preserve_config() {
  _mp="$1"
  _zip="$2"
  _bak="${TMPDIR:-/tmp}/tg_install_config_keep.sh"

  if [ -f "$_mp/config.sh" ]; then
    cp "$_mp/config.sh" "$_bak" 2>/dev/null || true
  fi

  if tg_zip_has_file "$_zip" "config.sh"; then
    return 0
  fi

  if [ -f "$_mp/config.sh" ]; then
    return 0
  fi

  if [ -f "$_bak" ]; then
    cp "$_bak" "$_mp/config.sh" 2>/dev/null || true
  fi
}

tg_chmod_exec() {
  _f="$1"
  [ -f "$_f" ] || return 1
  if command -v set_perm >/dev/null 2>&1; then
    set_perm "$_f" 0 0 0755 2>/dev/null && return 0
  fi
  chmod 755 "$_f" 2>/dev/null
}

tg_chmod_lib_dir() {
  _mp="$1"
  [ -d "$_mp/lib" ] || return 0
  for _f in "$_mp/lib"/*.sh; do
    [ -f "$_f" ] || continue
    tg_chmod_exec "$_f" || true
  done
}

#!/system/bin/sh
# Kiểm tra module sau khi giải nén — hỗ trợ cài đè (không cần gỡ bản cũ).

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
ui_print "* Timo/Momo STK: 0968884946"
ui_print ""

_tg_progress_bar 5 "Khởi tạo…"
[ -n "$MODPATH" ] || abort "! Lỗi cài đặt: biến MODPATH không có (installer không hợp lệ)."
[ -d "$MODPATH" ] || abort "! Lỗi cài đặt: không thấy thư mục module tại MODPATH."

[ -f "$MODPATH/lib/install.sh" ] || abort "! Lỗi cài đặt: thiếu lib/install.sh."
# shellcheck source=/dev/null
. "$MODPATH/lib/install.sh"

_tg_progress_bar 12 "Dừng bot cũ (cài đè)…"
tg_stop_old_bots

if [ -n "$ZIPFILE" ] && [ -f "$ZIPFILE" ]; then
  _tg_progress_bar 20 "Dọn file lib cũ thừa…"
  tg_prune_orphan_lib "$MODPATH" "$ZIPFILE"
  tg_preserve_config "$MODPATH" "$ZIPFILE"
  if tg_zip_has_file "$ZIPFILE" "config.sh"; then
    ui_print "- ZIP có config.sh — dùng cấu hình trong gói."
  elif [ -f "$MODPATH/config.sh" ]; then
    ui_print "- Cài đè: giữ nguyên config.sh (không cần gỡ module)."
  else
    ui_print "- Chưa có config.sh — tải ZIP từ web hoặc đổi tên config.sh.example."
  fi
else
  ui_print "- Cài đè / cập nhật (cùng id TelegramControl)."
fi

_tg_progress_bar 32 "Đang kiểm tra module.prop…"
[ -f "$MODPATH/module.prop" ] || abort "! Lỗi cài đặt: thiếu module.prop trong ZIP."

_tg_progress_bar 44 "Đang kiểm tra service.sh…"
[ -f "$MODPATH/service.sh" ] || abort "! Lỗi cài đặt: thiếu service.sh — ZIP có thể hỏng hoặc sync không đầy đủ."

_tg_progress_bar 56 "Đang kiểm tra thư mục lib…"
[ -d "$MODPATH/lib" ] || abort "! Lỗi cài đặt: thiếu thư mục lib."

found_lib=0
for _tg_f in "$MODPATH/lib"/*.sh; do
  [ -f "$_tg_f" ] || continue
  found_lib=1
  break
done
[ "$found_lib" -eq 1 ] || abort "! Lỗi cài đặt: trong lib không có file .sh — kiểm tra lại gói module."

_tg_progress_bar 72 "Đang gán quyền thực thi…"
tg_chmod_exec "$MODPATH/service.sh" || abort "! Lỗi cài đặt: không chmod được service.sh."
tg_chmod_lib_dir "$MODPATH"

_tg_progress_bar 88 "Đang kiểm tra shell…"
command -v sh >/dev/null 2>&1 || abort "! Lỗi cài đặt: không tìm thấy sh trong PATH."

_tg_progress_bar 100 "Kiểm tra module hoàn tất."
ui_print "- Có thể cài đè bản cũ — không cần gỡ module trước."
ui_print "- Khởi động lại sau khi cài / cập nhật xong."
ui_print ""

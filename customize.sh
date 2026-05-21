#!/system/bin/sh
# Kiểm tra module sau khi giải nén — thanh % + báo lỗi rõ ràng (Magisk / installer tương thích).

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

_tg_progress_bar 8 "Khởi tạo kiểm tra…"
[ -n "$MODPATH" ] || abort "! Lỗi cài đặt: biến MODPATH không có (installer không hợp lệ)."
[ -d "$MODPATH" ] || abort "! Lỗi cài đặt: không thấy thư mục module tại MODPATH."

_tg_progress_bar 22 "Đang kiểm tra module.prop…"
[ -f "$MODPATH/module.prop" ] || abort "! Lỗi cài đặt: thiếu module.prop trong ZIP."

_tg_progress_bar 38 "Đang kiểm tra service.sh…"
[ -f "$MODPATH/service.sh" ] || abort "! Lỗi cài đặt: thiếu service.sh — ZIP có thể hỏng hoặc sync không đầy đủ."

_tg_progress_bar 52 "Đang kiểm tra thư mục lib…"
[ -d "$MODPATH/lib" ] || abort "! Lỗi cài đặt: thiếu thư mục lib."

found_lib=0
for _tg_f in "$MODPATH/lib"/*.sh; do
  [ -f "$_tg_f" ] || continue
  found_lib=1
  break
done
[ "$found_lib" -eq 1 ] || abort "! Lỗi cài đặt: trong lib không có file .sh — kiểm tra lại gói module."

_tg_progress_bar 68 "Đang gán quyền thực thi cho service.sh…"
if command -v set_perm >/dev/null 2>&1; then
  set_perm "$MODPATH/service.sh" 0 0 0755 || abort "! Lỗi cài đặt: không set_perm được service.sh (chmod/chown/chcon)."
  if [ -d "$MODPATH/lib" ]; then
    for _tg_f in "$MODPATH/lib"/*.sh; do
      [ -f "$_tg_f" ] || continue
      set_perm "$_tg_f" 0 0 0755 || true
    done
  fi
else
  chmod 755 "$MODPATH/service.sh" || abort "! Lỗi cài đặt: không chmod 755 được service.sh."
  if [ -d "$MODPATH/lib" ]; then
    for _tg_f in "$MODPATH/lib"/*.sh; do
      [ -f "$_tg_f" ] || continue
      chmod 755 "$_tg_f" 2>/dev/null || true
    done
  fi
fi

_tg_progress_bar 88 "Đang kiểm tra đọc shell…"
command -v sh >/dev/null 2>&1 || abort "! Lỗi cài đặt: không tìm thấy sh trong PATH."

_tg_progress_bar 100 "Kiểm tra module hoàn tất."
ui_print "- Chuẩn bị hoàn tất (khởi động lại sau khi flash xong)."
ui_print ""

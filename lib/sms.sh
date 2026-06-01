# shellcheck shell=sh
# Đọc SMS inbox qua lệnh content (cần READ_SMS / ROM cho phép).

SMS_INBOX_URI="content://sms/inbox"
SMS_SHOW_COUNT=1
SMS_BODY_PREVIEW_MAX=1200
SMS_BODY_FULL_MAX=3800
SMS_SHOW_MAX=50
SMS_TG_MSG_MAX=3900

_sms_content_bin() {
  if command -v content >/dev/null 2>&1; then
    echo "content"
    return
  fi
  for p in /system/bin/content /system_ext/bin/content; do
    if [ -x "$p" ]; then
      echo "$p"
      return
    fi
  done
  echo ""
}

sms_query_inbox_raw() {
  bin="$(_sms_content_bin)"
  [ -z "$bin" ] && return 1
  out="$($bin query --uri "$SMS_INBOX_URI" --projection _id,address,date,body --sort "date DESC" --limit "$SMS_SHOW_COUNT" 2>/dev/null)"
  if printf '%s' "$out" | grep -q '^Row:'; then
    printf '%s' "$out"
    return 0
  fi
  out="$($bin query --uri "$SMS_INBOX_URI" --projection address,date,body --sort "date DESC" --limit "$SMS_SHOW_COUNT" 2>/dev/null)"
  if printf '%s' "$out" | grep -q '^Row:'; then
    printf '%s' "$out"
    return 0
  fi
  $bin query --uri "$SMS_INBOX_URI" 2>/dev/null
}

_sms_fmt_date_ms() {
  ms="$1"
  case "$ms" in ''|*[!0-9]*) echo "—"; return ;; esac
  sec=$((ms / 1000))
  ds="$(date -r "$sec" '+%d/%m/%Y %H:%M' 2>/dev/null || date -d "@$sec" '+%d/%m/%Y %H:%M' 2>/dev/null || true)"
  if [ -n "$ds" ]; then
    echo "$ds"
  else
    echo "$ms"
  fi
}

_sms_parse_address() {
  line="$1"
  addr="$(printf '%s' "$line" | sed -n 's/.*, address=\([^,]*\).*/\1/p')"
  [ -z "$addr" ] && addr="$(printf '%s' "$line" | sed -n 's/^[^,]*address=\([^,]*\).*/\1/p')"
  printf '%s' "$addr"
}

_sms_parse_date_ms() {
  line="$1"
  dt_ms="$(printf '%s' "$line" | sed -n 's/.*, date=\([0-9][0-9]*\), date_sent=.*/\1/p')"
  [ -z "$dt_ms" ] && dt_ms="$(printf '%s' "$line" | sed -n 's/.*, date=\([0-9][0-9]*\).*/\1/p')"
  printf '%s' "$dt_ms"
}

# Trích body=… (hỗ trợ nội dung có dấu phẩy, kết thúc bằng , service_center= nếu có).
_sms_parse_body_from_row() {
  line="$1"
  case "$line" in *body=*) ;; *) return 1 ;; esac
  rest="${line#*body=}"
  case "$rest" in
    *,\ service_center=*|*, service_center=*)
      body="${rest%%, service_center=*}"
      body="${body%%, service_center=*}"
      ;;
    *)
      body="$rest"
      ;;
  esac
  printf '%s' "$body"
}

_sms_body_for_telegram() {
  body="$1"
  max="$2"
  [ -z "$max" ] || [ "$max" -le 0 ] 2>/dev/null && {
    printf '%s' "$body"
    return
  }
  blen="$(printf '%s' "$body" | wc -c | tr -d ' ')"
  if [ "${blen:-0}" -gt "$max" ] 2>/dev/null; then
    printf '%s…' "$(printf '%s' "$body" | head -c "$max")"
  else
    printf '%s' "$body"
  fi
}

# Gửi một tin SMS inbox (full=1: nội dung đầy đủ, dùng cho /sms 1 và watcher).
sms_send_inbox_row() {
  line="$1"
  full="${2:-0}"
  title="${3:-📩 SMS}"

  addr="$(_sms_parse_address "$line")"
  dt_ms="$(_sms_parse_date_ms "$line")"
  body="$(_sms_parse_body_from_row "$line")"
  [ -z "$body" ] && body="$(printf '%s' "$line" | sed -n 's/.*, body=\(.*\), service_center=.*/\1/p')"
  [ -z "$body" ] && body="$(printf '%s' "$line" | sed -n 's/.*, body=\(.*\)$/\1/p')"

  if [ "$full" = "1" ]; then
    body_out="$(_sms_body_for_telegram "$body" "$SMS_BODY_FULL_MAX")"
  else
    body_out="$(_sms_body_for_telegram "$body" "$SMS_BODY_PREVIEW_MAX")"
  fi

  dt_h="$(_sms_fmt_date_ms "$dt_ms")"
  addr_esc="$(escape_html "$addr")"
  dt_esc="$(escape_html "$dt_h")"
  body_esc="$(escape_html "$body_out")"
  ts="$(date '+%H:%M:%S · %d/%m/%Y' 2>/dev/null || echo '—')"
  ts_esc="$(escape_html "$ts")"

  out="<b>${title}</b>
<i>${ts_esc}</i>
━━━━━━━━━━━━━━━━
<b>Từ</b> <code>${addr_esc}</code>
<b>Lúc</b> <i>${dt_esc}</i>
<pre>${body_esc}</pre>"

  msg_len="$(printf '%s' "$out" | wc -c | tr -d ' ')"
  if [ "${msg_len:-0}" -gt "$SMS_TG_MSG_MAX" ] 2>/dev/null; then
    cut=$((SMS_TG_MSG_MAX - 200))
    body_esc="$(escape_html "$(printf '%s' "$body_out" | head -c "$cut")")…"
    out="<b>${title}</b>
<i>${ts_esc}</i>
━━━━━━━━━━━━━━━━
<b>Từ</b> <code>${addr_esc}</code>
<b>Lúc</b> <i>${dt_esc}</i>
<pre>${body_esc}</pre>"
  fi
  send_code "$out"
}

handle_sms() {
  bin="$(_sms_content_bin)"
  if [ -z "$bin" ]; then
    send_code "❌ Không tìm thấy lệnh <code>content</code> (PATH / system)."
    return 1
  fi

  rest="$(echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  SMS_SHOW_COUNT=1
  if [ -n "$rest" ]; then
    case "$rest" in
      *[!0-9]*)
        send_code "❌ Số lượng SMS không hợp lệ (ví dụ <code>/sms 1</code> hoặc <code>/sms 5</code>)."
        return 1
        ;;
      0)
        send_code "❌ Số lượng phải ≥ 1."
        return 1
        ;;
      *)
        SMS_SHOW_COUNT="$rest"
        if [ "$SMS_SHOW_COUNT" -gt "$SMS_SHOW_MAX" ] 2>/dev/null; then
          SMS_SHOW_COUNT="$SMS_SHOW_MAX"
        fi
        ;;
    esac
  fi

  raw="$(sms_query_inbox_raw)"
  if [ -z "$raw" ]; then
    send_code "❌ Không đọc được SMS (quyền <code>READ_SMS</code> / ROM, hoặc hộp thư trống)."
    return 1
  fi

  rows="$(printf '%s\n' "$raw" | grep '^Row:' | head -n "$SMS_SHOW_COUNT")"
  if [ -z "$rows" ]; then
    send_code "ℹ️ Không có tin nhắn trong <code>sms/inbox</code>."
    return 0
  fi

  if [ "$SMS_SHOW_COUNT" -eq 1 ] 2>/dev/null; then
    line="$(printf '%s\n' "$rows" | head -n1)"
    sms_send_inbox_row "$line" 1 "📩 SMS gần nhất (inbox)"
    return 0
  fi

  ts="$(date '+%H:%M:%S · %d/%m/%Y' 2>/dev/null || echo '—')"
  ts_esc="$(escape_html "$ts")"
  out="<b>📩 ${SMS_SHOW_COUNT} SMS gần nhất (inbox)</b>
<i>${ts_esc}</i>
━━━━━━━━━━━━━━━━
"

  idx=0
  while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    idx=$((idx + 1))
    addr="$(_sms_parse_address "$line")"
    dt_ms="$(_sms_parse_date_ms "$line")"
    body="$(_sms_parse_body_from_row "$line")"
    [ -z "$body" ] && body="$(printf '%s' "$line" | sed -n 's/.*, body=\(.*\), service_center=.*/\1/p')"
    dt_h="$(_sms_fmt_date_ms "$dt_ms")"
    body_out="$(_sms_body_for_telegram "$body" "$SMS_BODY_PREVIEW_MAX")"
    addr_esc="$(escape_html "$addr")"
    dt_esc="$(escape_html "$dt_h")"
    body_esc="$(escape_html "$body_out")"
    out="${out}<b>${idx}.</b> <code>${addr_esc}</code> · <i>${dt_esc}</i>
<pre>${body_esc}</pre>

"
  done <<EOF
$rows
EOF

  send_code "$out"
}

SMS_SENT_URI="content://sms/sent"
SMS_SEND_CALLING_PKG="com.android.phone"

_sms_digits_only() {
  printf '%s' "$1" | tr -cd '0-9'
}

_sms_dest_match() {
  a="$(_sms_digits_only "$1")"
  b="$(_sms_digits_only "$2")"
  [ -z "$a" ] || [ -z "$b" ] && return 1
  [ "$a" = "$b" ] && return 0
  case "$a" in *"$b") return 0 ;; esac
  case "$b" in *"$a") return 0 ;; esac
  return 1
}

_sms_valid_dest() {
  d="$1"
  [ -z "$d" ] && return 1
  case "$d" in +*) d="${d#+}" ;; esac
  case "$d" in *[!0-9]*) return 1 ;; esac
  [ "${#d}" -ge 3 ] && [ "${#d}" -le 16 ]
}

_sms_svc_text() {
  printf '%s' "$1" | tr '\n\r' ' ' | sed 's/"/'"'"'/g'
}

_sms_service_ok() {
  printf '%s' "$1" | grep -qiE 'Parcel\(\(null\)|Parcel\(NULL\)|0x00000000:\s*00000000\s*00000000'
}

_sms_try_service_send() {
  dest="$1"
  text="$2"
  sub="$3"
  pkg="$4"
  meth="$5"
  out="$(service call isms "$meth" i32 "$sub" s16 "$pkg" s16 "null" s16 "$dest" s16 "null" s16 "$text" s16 "null" s16 "null" i32 0 i64 0 2>&1)" || true
  if _sms_service_ok "$out"; then
    return 0
  fi
  out="$(service call isms "$meth" i32 "$sub" s16 "$pkg" s16 "$dest" s16 "null" s16 "$text" s16 "null" s16 "null" i32 0 i32 0 2>&1)" || true
  _sms_service_ok "$out"
}

sms_send_text() {
  dest="$(_sms_svc_text "$1")"
  text="$(_sms_svc_text "$2")"
  [ -z "$dest" ] || [ -z "$text" ] && return 1
  command -v service >/dev/null 2>&1 || return 1
  for sub in 0 1 2; do
    _sms_try_service_send "$dest" "$text" "$sub" "com.android.mms.service" 5 && return 0
    _sms_try_service_send "$dest" "$text" "$sub" "$SMS_SEND_CALLING_PKG" 5 && return 0
    _sms_try_service_send "$dest" "$text" "$sub" "com.android.mms" 5 && return 0
    _sms_try_service_send "$dest" "$text" "$sub" "com.android.mms.service" 7 && return 0
    _sms_try_service_send "$dest" "$text" "$sub" "com.android.mms" 7 && return 0
    _sms_try_service_send "$dest" "$text" "$sub" "com.android.phone" 7 && return 0
  done
  return 1
}

sms_query_sent_raw() {
  lim="${1:-5}"
  bin="$(_sms_content_bin)"
  [ -z "$bin" ] && return 1
  out="$($bin query --uri "$SMS_SENT_URI" --projection address,date,body --sort "date DESC" --limit "$lim" 2>/dev/null)"
  if printf '%s' "$out" | grep -q '^Row:'; then
    printf '%s' "$out"
    return 0
  fi
  $bin query --uri "$SMS_SENT_URI" 2>/dev/null
}

sms_find_sent_row() {
  dest="$1"
  body="$2"
  raw="$(sms_query_sent_raw 8)"
  [ -z "$raw" ] && return 1
  _found=""
  while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    addr="$(_sms_parse_address "$line")"
    row_body="$(_sms_parse_body_from_row "$line")"
    [ -z "$row_body" ] && row_body="$(printf '%s' "$line" | sed -n 's/.*, body=\(.*\), service_center=.*/\1/p')"
    _sms_dest_match "$dest" "$addr" || continue
    case "$row_body" in
      "$body"*) _found="$line"; break ;;
    esac
    body_d="$(_sms_digits_only "$body")"
    row_d="$(_sms_digits_only "$row_body")"
    if [ -n "$body_d" ] && [ "$body_d" = "$row_d" ]; then
      _found="$line"
      break
    fi
  done <<EOF
$(printf '%s\n' "$raw" | grep '^Row:' | head -n 8)
EOF
  [ -n "$_found" ] && printf '%s' "$_found"
}

sms_report_sent_to_telegram() {
  dest="$1"
  body="$2"
  status="$3"
  sent_line="$4"

  dest_esc="$(escape_html "$dest")"
  body_esc="$(escape_html "$body")"
  ts="$(date '+%H:%M:%S · %d/%m/%Y' 2>/dev/null || echo '—')"
  ts_esc="$(escape_html "$ts")"

  if [ "$status" = "ok" ]; then
    head="✅ <b>Đã gửi SMS</b>"
    stat_line="<b>Trạng thái</b>: Đã gửi (service isms)"
  else
    head="❌ <b>Gửi SMS thất bại</b>"
    stat_line="<b>Trạng thái</b>: Không gọi được <code>service isms</code> (ROM / quyền SEND_SMS)"
  fi

  out="${head}
<i>${ts_esc}</i>
<code>────────────────────────</code>
<b>Đến</b> <code>${dest_esc}</code>
<b>Nội dung đã gửi</b>
<pre>${body_esc}</pre>
${stat_line}"

  if [ -n "$sent_line" ]; then
    s_addr="$(_sms_parse_address "$sent_line")"
    s_dt="$(_sms_fmt_date_ms "$(_sms_parse_date_ms "$sent_line")")"
    s_body="$(_sms_parse_body_from_row "$sent_line")"
    [ -z "$s_body" ] && s_body="$(printf '%s' "$sent_line" | sed -n 's/.*, body=\(.*\), service_center=.*/\1/p')"
    s_body_out="$(_sms_body_for_telegram "$s_body" "$SMS_BODY_FULL_MAX")"
    out="${out}

<b>📤 Xác nhận (hộp thư đã gửi)</b>
<b>Đến</b> <code>$(escape_html "$s_addr")</code>
<b>Lúc</b> <i>$(escape_html "$s_dt")</i>
<pre>$(escape_html "$s_body_out")</pre>"
  fi

  send_code "$out"
}

handle_sent_sms() {
  rest="$1"
  rest="$(echo "$rest" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [ -z "$rest" ]; then
    send_code "❌ Cú pháp: <code>/sent_sms SĐT Nội_dung</code>

Ví dụ: <code>/sent_sms 888 data_on</code> — gửi <code>data_on</code> tới <code>888</code>."
    return 1
  fi

  num="$(printf '%s' "$rest" | awk '{print $1}')"
  body="$(printf '%s' "$rest" | awk '{$1=""; sub(/^ /,""); print}')"

  if [ -z "$num" ] || [ -z "$body" ]; then
    send_code "❌ Thiếu SĐT hoặc nội dung. Ví dụ: <code>/sent_sms 888 data_on</code>"
    return 1
  fi

  if ! _sms_valid_dest "$num"; then
    send_code "❌ Số đích không hợp lệ (3–16 chữ số, có thể bắt đầu bằng <code>+</code>)."
    return 1
  fi

  if [ "$(printf '%s' "$body" | wc -c | tr -d ' ')" -gt 640 ] 2>/dev/null; then
    send_code "❌ Nội dung quá dài (tối đa ~640 byte SMS đơn)."
    return 1
  fi

  send_code "📤 Đang gửi SMS tới <code>$(escape_html "$num")</code>…"

  if sms_send_text "$num" "$body"; then
    ok=1
  else
    ok=0
  fi

  sent_line=""
  sleep 2
  sent_line="$(sms_find_sent_row "$num" "$body" | head -n1)"

  if [ -n "$sent_line" ] || [ "$ok" = "1" ]; then
    sms_report_sent_to_telegram "$num" "$body" "ok" "$sent_line"
  else
    sms_report_sent_to_telegram "$num" "$body" "fail" "$sent_line"
  fi
}

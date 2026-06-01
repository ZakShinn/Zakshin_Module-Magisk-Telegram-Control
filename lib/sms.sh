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

# Samsung / một số ROM: không hỗ trợ --limit; projection dùng dấu ':'.
_sms_content_query_inbox() {
  bin="$1"
  lim="$2"
  for proj in "_id:address:date:body" "_id,address,date,body" "address:date:body" "address,date,body"; do
    out="$($bin query --uri "$SMS_INBOX_URI" --projection "$proj" --sort "date DESC" 2>/dev/null)"
    if echo "$out" | grep -q '^Row:'; then
      echo "$out" | grep '^Row:' | head -n "$lim"
      return 0
    fi
  done
  out="$($bin query --uri "$SMS_INBOX_URI" 2>/dev/null)"
  echo "$out" | grep '^Row:' | head -n "$lim"
}

sms_query_inbox_raw() {
  bin="$(_sms_content_bin)"
  [ -z "$bin" ] && return 1
  lim="${SMS_SHOW_COUNT:-1}"
  _sms_content_query_inbox "$bin" "$lim"
}

# date trong DB: giây (10 chữ số) hoặc mili-giây (13). Trả về giây hợp lệ hoặc rỗng.
_sms_date_ms_to_sec() {
  ms="$1"
  tg_is_uint "$ms" || return 1
  if [ "${#ms}" -le 10 ]; then
    sec="$ms"
  else
    sec=$((ms / 1000))
  fi
  [ "$sec" -ge 946684800 ] 2>/dev/null || return 1
  now="$(date +%s 2>/dev/null)"
  tg_is_uint "$now" || now=0
  [ "$sec" -le $((now + 3600)) ] 2>/dev/null || return 1
  printf '%s' "$sec"
}

_sms_fmt_date_ms() {
  ms="$1"
  sec="$(_sms_date_ms_to_sec "$ms")" || {
    echo ""
    return
  }
  ds="$(date -r "$sec" '+%d/%m/%Y %H:%M' 2>/dev/null || date -d "@$sec" '+%d/%m/%Y %H:%M' 2>/dev/null || true)"
  [ -n "$ds" ] && printf '%s' "$ds"
}

_sms_parse_address() {
  line="$1"
  addr="$(printf '%s' "$line" | sed -n 's/.*, address=\([^,]*\).*/\1/p')"
  [ -z "$addr" ] && addr="$(printf '%s' "$line" | sed -n 's/^[^,]*address=\([^,]*\).*/\1/p')"
  printf '%s' "$addr"
}

_sms_parse_date_ms() {
  line="$1"
  dt_ms="$(echo "$line" | sed -n 's/^Row:.* date=\([0-9][0-9]*\), body=.*/\1/p')"
  [ -z "$dt_ms" ] && dt_ms="$(echo "$line" | sed -n 's/.* date=\([0-9][0-9]*\), body=.*/\1/p')"
  [ -z "$dt_ms" ] && dt_ms="$(echo "$line" | sed -n 's/.*, date=\([0-9][0-9]*\), date_sent=.*/\1/p')"
  [ -z "$dt_ms" ] && dt_ms="$(echo "$line" | sed -n 's/.*, date=\([0-9][0-9]*\).*/\1/p')"
  printf '%s' "$dt_ms"
}

# Trich body= tu dong content query (cat phay trong noi dung).
_sms_parse_body_from_row() {
  line="$1"
  echo "$line" | grep -q 'body=' || return 1
  rest="${line#*body=}"
  body="$(echo "$rest" | sed 's/, service_center=.*//')"
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

  addr_esc="$(escape_html "$addr")"
  body_esc="$(escape_html "$body_out")"
  ts="$(date '+%H:%M:%S · %d/%m/%Y' 2>/dev/null || echo '-')"
  ts_esc="$(escape_html "$ts")"

  out="<b>${title}</b>
<i>${ts_esc}</i>
━━━━━━━━━━━━━━━━
<b>Từ</b> ${addr_esc}
${body_esc}"

  msg_len="$(printf '%s' "$out" | wc -c | tr -d ' ')"
  if [ "${msg_len:-0}" -gt "$SMS_TG_MSG_MAX" ] 2>/dev/null; then
    cut=$((SMS_TG_MSG_MAX - 200))
    body_esc="$(escape_html "$(printf '%s' "$body_out" | head -c "$cut")")…"
    out="<b>${title}</b>
<i>${ts_esc}</i>
━━━━━━━━━━━━━━━━
<b>Từ</b> ${addr_esc}
${body_esc}"
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
    if ! tg_is_uint "$rest"; then
      send_code "❌ Số lượng SMS không hợp lệ (ví dụ <code>/sms 1</code> hoặc <code>/sms 5</code>)."
      return 1
    fi
    if [ "$rest" -eq 0 ] 2>/dev/null; then
      send_code "❌ Số lượng phải ≥ 1."
      return 1
    fi
    SMS_SHOW_COUNT="$rest"
    if [ "$SMS_SHOW_COUNT" -gt "$SMS_SHOW_MAX" ] 2>/dev/null; then
      SMS_SHOW_COUNT="$SMS_SHOW_MAX"
    fi
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

  _tf="/data/local/tmp/tg_sms_rows.$$"
  printf '%s\n' "$rows" >"$_tf"
  idx=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    idx=$((idx + 1))
    addr="$(_sms_parse_address "$line")"
    body="$(_sms_parse_body_from_row "$line")"
    [ -z "$body" ] && body="$(printf '%s' "$line" | sed -n 's/.*, body=\(.*\), service_center=.*/\1/p')"
    body_out="$(_sms_body_for_telegram "$body" "$SMS_BODY_PREVIEW_MAX")"
    addr_esc="$(escape_html "$addr")"
    body_esc="$(escape_html "$body_out")"
    out="${out}<b>${idx}.</b> ${addr_esc}
${body_esc}

"
  done <"$_tf"
  rm -f "$_tf"

  send_code "$out"
}

SMS_SEND_CALLING_PKG="com.android.phone"
SMS_SENT_URI="content://sms/sent"
SMS_SEND_VERIFY_SEC="${TG_SMS_VERIFY_SEC:-35}"

_sms_valid_dest() {
  d="$1"
  [ -z "$d" ] && return 1
  case "$d" in +*) d="${d#+}" ;; esac
  echo "$d" | grep -q '^[0-9][0-9]*$' || return 1
  [ "${#d}" -ge 3 ] && [ "${#d}" -le 16 ]
}

_sms_svc_text() {
  printf '%s' "$1" | tr '\n\r' ' ' | sed 's/"/'"'"'/g'
}

# Binder trả Parcel không có nghĩa SMS đã gửi — chỉ coi là không lỗi tức thì.
_sms_service_ok() {
  out="$1"
  [ -z "$out" ] && return 1
  printf '%s' "$out" | grep -qiE 'SecurityException|Permission denial|Not allowed|Unknown service|No such service|IllegalArgument|NullPointerException|Error type|does not exist' && return 1
  printf '%s' "$out" | grep -qiE 'fffffffe|fffffffc|Parcelable|Exception' && return 1
  printf '%s' "$out" | grep -qiE 'Result: Parcel\([^)]*00000000' && return 0
  return 1
}

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

_sms_sub_ids_list() {
  for id in 1 0 2; do
    echo "$id"
  done
}

_sms_content_query_sent() {
  bin="$1"
  lim="$2"
  for proj in "_id:address:date:body" "_id,address,date,body" "address:date:body" "address,date,body"; do
    out="$($bin query --uri "$SMS_SENT_URI" --projection "$proj" --sort "date DESC" 2>/dev/null)"
    if echo "$out" | grep -q '^Row:'; then
      echo "$out" | grep '^Row:' | head -n "$lim"
      return 0
    fi
    out="$($bin query --uri "$SMS_SENT_URI" --projection "$proj" 2>/dev/null)"
    if echo "$out" | grep -q '^Row:'; then
      echo "$out" | grep '^Row:' | head -n "$lim"
      return 0
    fi
  done
  out="$($bin query --uri "$SMS_SENT_URI" 2>/dev/null)"
  echo "$out" | grep '^Row:' | head -n "$lim"
}

_sms_row_body_matches() {
  row_body="$1"
  want="$2"
  [ -z "$row_body" ] || [ -z "$want" ] && return 1
  case "$row_body" in "$want"*) return 0 ;; esac
  want_d="$(_sms_digits_only "$want")"
  row_d="$(_sms_digits_only "$row_body")"
  [ -n "$want_d" ] && [ "$want_d" = "$row_d" ] && return 0
  return 1
}

# Chờ tin xuất hiện trong content://sms/sent (sau khi user bấm xác nhận MmsService nếu có).
sms_verify_sent() {
  dest="$1"
  text="$2"
  since_sec="${3:-0}"
  max_wait="${4:-$SMS_SEND_VERIFY_SEC}"
  bin="$(_sms_content_bin)"
  [ -z "$bin" ] && return 1
  elapsed=0
  while [ "$elapsed" -lt "$max_wait" ]; do
    raw="$(_sms_content_query_sent "$bin" 12)"
    _tf="/data/local/tmp/tg_sms_sent_chk.$$"
    printf '%s\n' "$raw" | grep '^Row:' >"$_tf"
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      addr="$(_sms_parse_address "$line")"
      _sms_dest_match "$dest" "$addr" || continue
      row_body="$(_sms_parse_body_from_row "$line")"
      [ -z "$row_body" ] && row_body="$(printf '%s' "$line" | sed -n 's/.*, body=\(.*\), service_center=.*/\1/p')"
      _sms_row_body_matches "$row_body" "$text" || continue
      if [ -n "$since_sec" ] && tg_is_uint "$since_sec"; then
        dt_ms="$(_sms_parse_date_ms "$line")"
        row_sec="$(_sms_date_ms_to_sec "$dt_ms")" || row_sec=""
        if [ -n "$row_sec" ] && [ "$row_sec" -lt "$((since_sec - 10))" ] 2>/dev/null; then
          continue
        fi
      fi
      rm -f "$_tf"
      return 0
    done <"$_tf"
    rm -f "$_tf"
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

# App SMS mặc định (Android 10+): gửi với package này ít bị hộp thoại MmsService hơn com.android.mms.service.
_sms_default_calling_pkg() {
  def=""
  if command -v cmd >/dev/null 2>&1; then
    def="$(cmd role get-role-holders android.app.role.SMS 2>/dev/null | head -n1)"
  fi
  [ -z "$def" ] && def="$(settings get secure sms_default_application 2>/dev/null)"
  def="$(printf '%s' "$def" | tr -d '\r\n ')"
  case "$def" in null|""|*[!a-zA-Z0-9._]*) def="" ;; esac
  printf '%s' "$def"
}

# Gói ưu tiên: app SMS mặc định → phone → Samsung/Google Messages → mms (cuối: mms.service dễ bật xác nhận).
_sms_calling_pkg_list() {
  list=""
  def="$(_sms_default_calling_pkg)"
  [ -n "$def" ] && list="$def"
  for p in \
    "${TG_SMS_CALLING_PKG:-}" \
    "$SMS_SEND_CALLING_PKG" \
    com.samsung.android.messaging \
    com.google.android.apps.messaging \
    com.android.mms \
    com.android.mms.service; do
    [ -z "$p" ] && continue
    case "$p" in *[!a-zA-Z0-9._]*) continue ;; esac
    printf '%s\n' "$list" | grep -qx "$p" && continue
    list="${list:+$list
}$p"
  done
  printf '%s' "$list"
}

# sendTextForSubscriber (API 31+): persistMessageForNonDefaultSmsApp=0 (i32 0) trước messageId (i64 0).
_sms_try_service_send_m5() {
  dest="$1"
  text="$2"
  sub="$3"
  pkg="$4"
  tag="$pkg"
  out="$(service call isms 5 i32 "$sub" s16 "$pkg" s16 "$tag" s16 "$dest" s16 "null" s16 "$text" s16 "null" s16 "null" i32 0 i64 0 2>&1)" || true
  if _sms_service_ok "$out"; then
    return 0
  fi
  out="$(service call isms 5 i32 "$sub" s16 "$pkg" s16 "null" s16 "$dest" s16 "null" s16 "$text" s16 "null" s16 "null" i32 0 i64 0 2>&1)" || true
  if _sms_service_ok "$out"; then
    return 0
  fi
  out="$(service call isms 5 i32 "$sub" s16 "$pkg" s16 "" s16 "$dest" s16 "null" s16 "$text" s16 "null" s16 "null" i32 0 i64 0 2>&1)" || true
  _sms_service_ok "$out"
}

# sendTextForSubscriberWithSelfPermissions — thử trước khi gọi qua MmsService broker.
_sms_try_service_send_m7() {
  dest="$1"
  text="$2"
  sub="$3"
  pkg="$4"
  out="$(service call isms 7 i32 "$sub" s16 "$pkg" s16 "$dest" s16 "null" s16 "$text" s16 "null" s16 "null" i32 0 i32 0 2>&1)" || true
  if _sms_service_ok "$out"; then
    return 0
  fi
  out="$(service call isms 7 i32 "$sub" s16 "$pkg" s16 "null" s16 "$dest" s16 "null" s16 "$text" s16 "null" s16 "null" i32 0 i32 0 2>&1)" || true
  _sms_service_ok "$out"
}

_sms_try_cmd_phone() {
  dest="$1"
  text="$2"
  command -v cmd >/dev/null 2>&1 || return 1
  cmd phone sms send --subscription 0 "$dest" "$text" 2>/dev/null && return 0
  return 1
}

_sms_try_am_sendto() {
  dest="$1"
  text="$2"
  command -v am >/dev/null 2>&1 || return 1
  am start -a android.intent.action.SENDTO -d "smsto:${dest}" --es sms_body "$text" --ez exit_on_sent true 2>/dev/null && return 0
  am start -a android.intent.action.SENDTO -d "sms:${dest}" --es sms_body "$text" 2>/dev/null && return 0
  return 1
}

_sms_send_and_verify() {
  dest="$1"
  text="$2"
  since_sec="$3"
  shift 3
  if "$@"; then
    sms_verify_sent "$dest" "$text" "$since_sec" "$SMS_SEND_VERIFY_SEC"
  else
    return 1
  fi
}

sms_send_text() {
  dest="$(_sms_svc_text "$1")"
  text="$(_sms_svc_text "$2")"
  [ -z "$dest" ] || [ -z "$text" ] && return 1

  command -v service >/dev/null 2>&1 || return 1
  since_sec="$(date +%s 2>/dev/null)" || since_sec=0
  _pkgtf="/data/local/tmp/tg_sms_pkgs.$$"
  _stf="/data/local/tmp/tg_sms_subs.$$"
  _sms_calling_pkg_list >"$_pkgtf"
  _sms_sub_ids_list >"$_stf"
  while IFS= read -r sub; do
    [ -z "$sub" ] && continue
    while IFS= read -r pkg; do
      [ -z "$pkg" ] && continue
      if _sms_send_and_verify "$dest" "$text" "$since_sec" _sms_try_service_send_m5 "$dest" "$text" "$sub" "$pkg"; then
        rm -f "$_pkgtf" "$_stf"
        return 0
      fi
      if _sms_send_and_verify "$dest" "$text" "$since_sec" _sms_try_service_send_m7 "$dest" "$text" "$sub" "$pkg"; then
        rm -f "$_pkgtf" "$_stf"
        return 0
      fi
    done <"$_pkgtf"
  done <"$_stf"
  rm -f "$_pkgtf" "$_stf"
  if _sms_try_cmd_phone "$dest" "$text"; then
    sms_verify_sent "$dest" "$text" "$since_sec" "$SMS_SEND_VERIFY_SEC" && return 0
  fi
  if [ "${TG_SMS_USE_UI:-0}" = "1" ]; then
    _sms_try_am_sendto "$dest" "$text" || true
    sms_verify_sent "$dest" "$text" "$since_sec" "$SMS_SEND_VERIFY_SEC" && return 0
  fi
  return 1
}

handle_sentsms() {
  rest="$1"
  rest="$(echo "$rest" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [ -z "$rest" ]; then
    send_code "❌ Cú pháp: <code>/sentsms SĐT Nội_dung</code>

Ví dụ: <code>/sentsms 888 data_on</code> — gửi <code>data_on</code> tới <code>888</code>."
    return 1
  fi

  num="$(printf '%s' "$rest" | awk '{print $1}')"
  body="$(printf '%s' "$rest" | awk '{$1=""; sub(/^ /,""); print}')"
  case "$num" in @*) num="${num#@}" ;; esac

  if [ -z "$num" ] || [ -z "$body" ]; then
    send_code "❌ Thiếu SĐT hoặc nội dung. Ví dụ: <code>/sentsms 888 data_on</code>"
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

  send_code "📤 Đang gửi… <i>(nếu máy hỏi xác nhận MmsService, bấm Gửi trong ~${SMS_SEND_VERIFY_SEC}s)</i>"

  if sms_send_text "$num" "$body"; then
    send_code "✅ Đã gửi tin nhắn."
  else
    send_code "❌ Không gửi được tin nhắn (không thấy trong hộp thư đã gửi). Kiểm tra màn hình máy và thử lại."
  fi
}

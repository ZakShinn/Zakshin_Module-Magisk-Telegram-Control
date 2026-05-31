# shellcheck shell=sh
# Read inbox SMS via the `content` command (requires READ_SMS / ROM policy).

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
<b>From</b> <code>${addr_esc}</code>
<b>Time</b> <i>${dt_esc}</i>
<pre>${body_esc}</pre>"

  msg_len="$(printf '%s' "$out" | wc -c | tr -d ' ')"
  if [ "${msg_len:-0}" -gt "$SMS_TG_MSG_MAX" ] 2>/dev/null; then
    cut=$((SMS_TG_MSG_MAX - 200))
    body_esc="$(escape_html "$(printf '%s' "$body_out" | head -c "$cut")")…"
    out="<b>${title}</b>
<i>${ts_esc}</i>
━━━━━━━━━━━━━━━━
<b>From</b> <code>${addr_esc}</code>
<b>Time</b> <i>${dt_esc}</i>
<pre>${body_esc}</pre>"
  fi
  send_code "$out"
}

handle_sms() {
  bin="$(_sms_content_bin)"
  if [ -z "$bin" ]; then
    send_code "❌ Cannot find <code>content</code> command (PATH / system)."
    return 1
  fi

  rest="$(echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  SMS_SHOW_COUNT=1
  if [ -n "$rest" ]; then
    case "$rest" in
      *[!0-9]*)
        send_code "❌ Invalid count (e.g. <code>/sms 1</code> or <code>/sms 5</code>)."
        return 1
        ;;
      0)
        send_code "❌ Count must be ≥ 1."
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
    send_code "❌ Failed to read SMS (<code>READ_SMS</code> / ROM, or empty inbox)."
    return 1
  fi

  rows="$(printf '%s\n' "$raw" | grep '^Row:' | head -n "$SMS_SHOW_COUNT")"
  if [ -z "$rows" ]; then
    send_code "ℹ️ No messages in <code>sms/inbox</code>."
    return 0
  fi

  if [ "$SMS_SHOW_COUNT" -eq 1 ] 2>/dev/null; then
    line="$(printf '%s\n' "$rows" | head -n1)"
    sms_send_inbox_row "$line" 1 "📩 Latest SMS (inbox)"
    return 0
  fi

  ts="$(date '+%H:%M:%S · %d/%m/%Y' 2>/dev/null || echo '—')"
  ts_esc="$(escape_html "$ts")"
  out="<b>📩 Last ${SMS_SHOW_COUNT} SMS (inbox)</b>
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

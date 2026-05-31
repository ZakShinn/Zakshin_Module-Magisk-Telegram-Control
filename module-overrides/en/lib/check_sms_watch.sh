# shellcheck shell=sh
# Poll content://sms/inbox for new messages — /sms_watch_on|off under /dev.

CHECK_SMS_WATCH_PID_FILE="${CHECK_SMS_WATCH_PID_FILE:-/data/local/tmp/tg_device_bot_check_sms_watch_pid}"
CHECK_SMS_WATCH_LAST_TS_FILE="${CHECK_SMS_WATCH_LAST_TS_FILE:-/data/local/tmp/tg_device_bot_check_sms_last_ts}"
CHECK_SMS_WATCH_LAST_TIE_FILE="${CHECK_SMS_WATCH_LAST_TIE_FILE:-/data/local/tmp/tg_device_bot_check_sms_last_tie}"
CHECK_SMS_WATCH_SORT_TMP="${CHECK_SMS_WATCH_SORT_TMP:-/data/local/tmp/tg_chk_sms_watch_sort}"
CHECK_SMS_WATCH_INTERVAL="${CHECK_SMS_WATCH_INTERVAL:-8}"
CHECK_SMS_WATCH_INTERVAL_MIN=3
CHECK_SMS_WATCH_INTERVAL_MAX=120

_check_sms_watch_extract_id() {
  printf '%s' "$1" | sed -n 's/.*_id=[[:space:]]*\([0-9][0-9]*\).*/\1/p'
}

_check_sms_watch_extract_date() {
  _sms_parse_date_ms "$1"
}

_check_sms_watch_is_perm_error() {
  printf '%s' "$1" | grep -qiE 'permission denial|securityexception|requires .*read_sms|not allowed to access'
}

_check_sms_watch_query_raw_limit() {
  lim="$1"
  bin="$(_sms_content_bin)"
  [ -z "$bin" ] && return 1
  out="$($bin query --uri "$SMS_INBOX_URI" --projection _id,address,date,body --sort "date DESC" --limit "$lim" 2>&1)"
  printf '%s' "$out"
}

_check_sms_watch_send_one_row() {
  sms_send_inbox_row "$1" 1 "📩 New SMS (inbox)"
}

_check_sms_watch_loop() {
  CID="$1"
  [ -n "$CID" ] && TELEGRAM_CHAT_ID="$CID"

  bin="$(_sms_content_bin)"
  [ -z "$bin" ] && return 1

  raw="$(_check_sms_watch_query_raw_limit 1)"
  if _check_sms_watch_is_perm_error "$raw"; then
    send_code "❌ Cannot watch SMS: <code>READ_SMS</code> denied or ROM blocks <code>content://sms</code> in background."
    return 1
  fi
  row="$(printf '%s' "$raw" | grep '^Row:' | head -n1)"
  base_ts=0
  base_id=0
  if [ -n "$row" ]; then
    base_ts="$(_check_sms_watch_extract_date "$row")"
    case "$base_ts" in ''|*[!0-9]*) base_ts=0 ;; esac
    base_id="$(_check_sms_watch_extract_id "$row")"
    case "$base_id" in ''|*[!0-9]*) base_id=0 ;; esac
  fi
  printf '%s' "$base_ts" >"$CHECK_SMS_WATCH_LAST_TS_FILE"
  printf '%s,%s' "$base_ts" "$base_id" >"$CHECK_SMS_WATCH_LAST_TIE_FILE"

  poll="$CHECK_SMS_WATCH_INTERVAL"
  case "$poll" in ''|*[!0-9]*) poll=8 ;; esac

  while true; do
    sleep "$poll"

    raw_top="$(_check_sms_watch_query_raw_limit 1)"
    if _check_sms_watch_is_perm_error "$raw_top"; then
      send_code "❌ SMS watch stopped: no <code>READ_SMS</code> / inbox access blocked."
      return 1
    fi
    row_top="$(printf '%s' "$raw_top" | grep '^Row:' | head -n1)"
    cur_top_ts=0
    cur_top_id=0
    if [ -n "$row_top" ]; then
      cur_top_ts="$(_check_sms_watch_extract_date "$row_top")"
      case "$cur_top_ts" in ''|*[!0-9]*) cur_top_ts=0 ;; esac
      cur_top_id="$(_check_sms_watch_extract_id "$row_top")"
      case "$cur_top_id" in ''|*[!0-9]*) cur_top_id=0 ;; esac
    fi

    last_ts="$(cat "$CHECK_SMS_WATCH_LAST_TS_FILE" 2>/dev/null)"
    case "$last_ts" in ''|*[!0-9]*) last_ts=0 ;; esac
    last_tie="$(cat "$CHECK_SMS_WATCH_LAST_TIE_FILE" 2>/dev/null)"
    last_tie_ts="${last_tie%%,*}"
    last_tie_id="${last_tie#*,}"
    case "$last_tie_ts" in ''|*[!0-9]*) last_tie_ts="$last_ts" ;; esac
    case "$last_tie_id" in ''|*[!0-9]*) last_tie_id=0 ;; esac

    if [ "$cur_top_ts" -lt "$last_ts" ] 2>/dev/null; then
      printf '%s' "$cur_top_ts" >"$CHECK_SMS_WATCH_LAST_TS_FILE"
      printf '%s,%s' "$cur_top_ts" "$cur_top_id" >"$CHECK_SMS_WATCH_LAST_TIE_FILE"
      continue
    fi

    [ "$cur_top_ts" -gt "$last_ts" ] 2>/dev/null || continue

    batch="$(_check_sms_watch_query_raw_limit 80)"
    if _check_sms_watch_is_perm_error "$batch"; then
      send_code "❌ SMS watch stopped: cannot read inbox (Permission Denial)."
      return 1
    fi
    [ -z "$batch" ] && continue

    tmp_rows="/data/local/tmp/tg_chk_sms_rows.$$"
    printf '%s\n' "$batch" | grep '^Row:' >"$tmp_rows" 2>/dev/null || : >"$tmp_rows"

    rm -f "$CHECK_SMS_WATCH_SORT_TMP"
    while IFS= read -r line || [ -n "$line" ]; do
      [ -z "$line" ] && continue
      ts="$(_check_sms_watch_extract_date "$line")"
      case "$ts" in ''|*[!0-9]*) continue ;; esac
      [ "$ts" -gt "$last_ts" ] 2>/dev/null || continue
      [ "$ts" -le "$cur_top_ts" ] 2>/dev/null || continue
      id="$(_check_sms_watch_extract_id "$line")"
      case "$id" in ''|*[!0-9]*) id=0 ;; esac
      if [ "$ts" -eq "$last_tie_ts" ] 2>/dev/null && [ "$id" -le "$last_tie_id" ] 2>/dev/null; then
        continue
      fi
      printf '%s\t%s\t%s\n' "$ts" "$id" "$line" >>"$CHECK_SMS_WATCH_SORT_TMP"
    done <"$tmp_rows"
    rm -f "$tmp_rows"

    if [ -f "$CHECK_SMS_WATCH_SORT_TMP" ] && [ -s "$CHECK_SMS_WATCH_SORT_TMP" ]; then
      sort -n "$CHECK_SMS_WATCH_SORT_TMP" | while IFS= read -r rec || [ -n "$rec" ]; do
        [ -z "$rec" ] && continue
        line="$(printf '%s' "$rec" | cut -f3-)"
        _check_sms_watch_send_one_row "$line"
      done
      printf '%s' "$cur_top_ts" >"$CHECK_SMS_WATCH_LAST_TS_FILE"
      printf '%s,%s' "$cur_top_ts" "$cur_top_id" >"$CHECK_SMS_WATCH_LAST_TIE_FILE"
    fi

    rm -f "$CHECK_SMS_WATCH_SORT_TMP"
  done
}

handle_sms_watch_on() {
  arg="$1"
  CID="$2"
  [ -n "$CID" ] && TELEGRAM_CHAT_ID="$CID"

  interval="$CHECK_SMS_WATCH_INTERVAL"
  if [ -n "$arg" ]; then
    case "$arg" in
      *[!0-9]*)
        send_code "❌ Usage: <code>/sms_watch_on</code> or <code>/sms_watch_on 10</code> (seconds, ${CHECK_SMS_WATCH_INTERVAL_MIN}–${CHECK_SMS_WATCH_INTERVAL_MAX})."
        return 1
        ;;
    esac
    interval="$arg"
    if [ "$interval" -lt "$CHECK_SMS_WATCH_INTERVAL_MIN" ] 2>/dev/null \
      || [ "$interval" -gt "$CHECK_SMS_WATCH_INTERVAL_MAX" ] 2>/dev/null; then
      send_code "❌ Valid poll interval: ${CHECK_SMS_WATCH_INTERVAL_MIN}–${CHECK_SMS_WATCH_INTERVAL_MAX} seconds."
      return 1
    fi
  fi

  if [ -f "$CHECK_SMS_WATCH_PID_FILE" ]; then
    old_pid="$(cat "$CHECK_SMS_WATCH_PID_FILE" 2>/dev/null)"
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
      send_code "ℹ️ SMS watch already running (PID <code>${old_pid}</code>). Stop: <code>/sms_watch_off</code>"
      return 0
    fi
    rm -f "$CHECK_SMS_WATCH_PID_FILE" 2>/dev/null || true
  fi

  (
    CHECK_SMS_WATCH_INTERVAL="$interval"
    export CHECK_SMS_WATCH_INTERVAL
    _check_sms_watch_loop "$CID"
  ) &
  watch_pid=$!
  echo "$watch_pid" >"$CHECK_SMS_WATCH_PID_FILE"

  send_code "✅ <b>SMS watch ON</b> (poll every <b>${interval}</b>s, full message body).
Existing inbox messages are not resent.
Stop: <code>/sms_watch_off</code>
<i>Not instant push — needs <code>READ_SMS</code> and ROM allowing background access.</i>"
}

handle_sms_watch_off() {
  if [ ! -f "$CHECK_SMS_WATCH_PID_FILE" ]; then
    send_code "ℹ️ SMS watch is not running (<code>/sms_watch_on</code>)."
    return 0
  fi
  pid="$(cat "$CHECK_SMS_WATCH_PID_FILE" 2>/dev/null)"
  killed=0
  if [ -n "$pid" ] && kill "$pid" 2>/dev/null; then
    killed=1
  fi
  rm -f "$CHECK_SMS_WATCH_PID_FILE" 2>/dev/null || true
  if [ "$killed" = "1" ]; then
    send_code "✅ SMS watch stopped."
  else
    send_code "ℹ️ SMS watch process was not running (cleared PID file)."
  fi
}

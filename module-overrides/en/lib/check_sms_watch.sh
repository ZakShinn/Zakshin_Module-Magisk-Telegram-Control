# shellcheck shell=sh
# Poll SMS inbox — auto-starts with the bot (new messages → Telegram).

CHECK_SMS_WATCH_PID_FILE="${CHECK_SMS_WATCH_PID_FILE:-/data/local/tmp/tg_device_bot_check_sms_watch_pid}"
CHECK_SMS_WATCH_LAST_TS_FILE="${CHECK_SMS_WATCH_LAST_TS_FILE:-/data/local/tmp/tg_device_bot_check_sms_last_ts}"
CHECK_SMS_WATCH_LAST_TIE_FILE="${CHECK_SMS_WATCH_LAST_TIE_FILE:-/data/local/tmp/tg_device_bot_check_sms_last_tie}"
CHECK_SMS_WATCH_SORT_TMP="${CHECK_SMS_WATCH_SORT_TMP:-/data/local/tmp/tg_chk_sms_watch_sort}"
CHECK_SMS_WATCH_DISABLED_FILE="${CHECK_SMS_WATCH_DISABLED_FILE:-/data/local/tmp/tg_sms_watch_disabled}"
CHECK_SMS_WATCH_LOG="${CHECK_SMS_WATCH_LOG:-/data/local/tmp/tg_device_bot.log}"

CHECK_SMS_WATCH_INTERVAL="${SMS_WATCH_INTERVAL:-${CHECK_SMS_WATCH_INTERVAL:-8}}"
CHECK_SMS_WATCH_INTERVAL_MIN=3
CHECK_SMS_WATCH_INTERVAL_MAX=120

SMS_WATCH_AUTO="${SMS_WATCH_AUTO:-1}"

_check_sms_watch_log() {
  printf '%s\n' "$*" >>"$CHECK_SMS_WATCH_LOG" 2>/dev/null || true
}

_check_sms_watch_extract_id() {
  line="$1"
  id="$(printf '%s' "$line" | sed -n 's/.*[[:space:]]_id=\([0-9][0-9]*\).*/\1/p')"
  [ -n "$id" ] && { printf '%s' "$id"; return; }
  id="$(printf '%s' "$line" | sed -n 's/.*_id=\([0-9][0-9]*\).*/\1/p')"
  printf '%s' "$id"
}

_check_sms_watch_extract_date() {
  _sms_parse_date_ms "$1"
}

_check_sms_watch_is_perm_error() {
  printf '%s' "$1" | grep -qiE 'permission denial|securityexception|requires .*read_sms|not allowed to access|not found'
}

_check_sms_watch_query_raw_limit() {
  lim="$1"
  _save="$SMS_SHOW_COUNT"
  SMS_SHOW_COUNT="$lim"
  sms_query_inbox_raw
  SMS_SHOW_COUNT="$_save"
}

_check_sms_watch_send_one_row() {
  sms_send_inbox_row "$1" 1 "📩 New SMS"
}

_check_sms_watch_baseline_from_inbox() {
  raw="$(_check_sms_watch_query_raw_limit 1)"
  if _check_sms_watch_is_perm_error "$raw"; then
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
  return 0
}

_check_sms_watch_is_newer_than() {
  ts="$1"
  id="$2"
  last_ts="$3"
  last_id="$4"
  [ "$ts" -gt "$last_ts" ] 2>/dev/null && return 0
  if [ "$ts" -eq "$last_ts" ] 2>/dev/null && [ "$id" -gt "$last_id" ] 2>/dev/null; then
    return 0
  fi
  return 1
}

_check_sms_watch_not_after() {
  ts="$1"
  id="$2"
  max_ts="$3"
  max_id="$4"
  [ "$ts" -lt "$max_ts" ] 2>/dev/null && return 0
  [ "$ts" -eq "$max_ts" ] 2>/dev/null && [ "$id" -le "$max_id" ] 2>/dev/null && return 0
  return 1
}

_check_sms_watch_process_new_batch() {
  last_ts="$1"
  last_tie_ts="$2"
  last_tie_id="$3"
  cur_top_ts="$4"
  cur_top_id="$5"

  batch="$(_check_sms_watch_query_raw_limit 80)"
  if _check_sms_watch_is_perm_error "$batch"; then
    return 1
  fi
  [ -z "$batch" ] && return 0

  rm -f "$CHECK_SMS_WATCH_SORT_TMP"
  printf '%s\n' "$batch" | grep '^Row:' | while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    ts="$(_check_sms_watch_extract_date "$line")"
    case "$ts" in ''|*[!0-9]*) continue ;; esac
    id="$(_check_sms_watch_extract_id "$line")"
    case "$id" in ''|*[!0-9]*) id=0 ;; esac
    _check_sms_watch_is_newer_than "$ts" "$id" "$last_tie_ts" "$last_tie_id" || continue
    _check_sms_watch_not_after "$ts" "$id" "$cur_top_ts" "$cur_top_id" || continue
    printf '%s\t%s\t%s\n' "$ts" "$id" "$line" >>"$CHECK_SMS_WATCH_SORT_TMP"
  done

  if [ ! -f "$CHECK_SMS_WATCH_SORT_TMP" ] || [ ! -s "$CHECK_SMS_WATCH_SORT_TMP" ]; then
    rm -f "$CHECK_SMS_WATCH_SORT_TMP"
    return 0
  fi

  sort -t '	' -k1,1n -k2,2n "$CHECK_SMS_WATCH_SORT_TMP" | while IFS= read -r rec || [ -n "$rec" ]; do
    [ -z "$rec" ] && continue
    line="$(printf '%s' "$rec" | cut -f3-)"
    [ -n "$line" ] && _check_sms_watch_send_one_row "$line"
  done

  printf '%s' "$cur_top_ts" >"$CHECK_SMS_WATCH_LAST_TS_FILE"
  printf '%s,%s' "$cur_top_ts" "$cur_top_id" >"$CHECK_SMS_WATCH_LAST_TIE_FILE"
  rm -f "$CHECK_SMS_WATCH_SORT_TMP"
  return 0
}

_check_sms_watch_loop() {
  CID="$1"
  [ -n "$CID" ] && TELEGRAM_CHAT_ID="$CID"

  if ! _check_sms_watch_baseline_from_inbox; then
    _check_sms_watch_log "sms_watch: baseline failed (content/READ_SMS?)"
  fi

  poll="$CHECK_SMS_WATCH_INTERVAL"
  case "$poll" in ''|*[!0-9]*) poll=8 ;; esac

  _perm_warn=0

  while true; do
    if [ -f "$CHECK_SMS_WATCH_DISABLED_FILE" ]; then
      _check_sms_watch_log "sms_watch: stopped (disabled flag)"
      return 0
    fi

    sleep "$poll"

    [ -z "$(_sms_content_bin)" ] && continue

    raw_top="$(_check_sms_watch_query_raw_limit 1)"
    if _check_sms_watch_is_perm_error "$raw_top"; then
      if [ "$_perm_warn" -eq 0 ] && [ -n "$TELEGRAM_CHAT_ID" ] && [ -n "$TELEGRAM_TOKEN" ]; then
        send_code "⚠️ SMS watch: cannot read inbox (<code>READ_SMS</code> / ROM). Retrying…"
        _perm_warn=1
      fi
      continue
    fi
    _perm_warn=0

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

    if [ ! -f "$CHECK_SMS_WATCH_LAST_TIE_FILE" ]; then
      _check_sms_watch_baseline_from_inbox || true
      continue
    fi

    if [ "$cur_top_ts" -lt "$last_ts" ] 2>/dev/null; then
      printf '%s' "$cur_top_ts" >"$CHECK_SMS_WATCH_LAST_TS_FILE"
      printf '%s,%s' "$cur_top_ts" "$cur_top_id" >"$CHECK_SMS_WATCH_LAST_TIE_FILE"
      continue
    fi

    if ! _check_sms_watch_is_newer_than "$cur_top_ts" "$cur_top_id" "$last_tie_ts" "$last_tie_id"; then
      continue
    fi

    _check_sms_watch_process_new_batch "$last_ts" "$last_tie_ts" "$last_tie_id" "$cur_top_ts" "$cur_top_id" || true
  done
}

_check_sms_watch_stop_pid() {
  if [ ! -f "$CHECK_SMS_WATCH_PID_FILE" ]; then
    return 0
  fi
  pid="$(cat "$CHECK_SMS_WATCH_PID_FILE" 2>/dev/null)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
    kill -9 "$pid" 2>/dev/null
  fi
  rm -f "$CHECK_SMS_WATCH_PID_FILE" 2>/dev/null || true
}

start_sms_inbox_watch_auto() {
  [ "$SMS_WATCH_AUTO" = "0" ] && return 0
  [ -f "$CHECK_SMS_WATCH_DISABLED_FILE" ] && return 0
  [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ] && return 0

  if [ -f "$CHECK_SMS_WATCH_PID_FILE" ]; then
    old_pid="$(cat "$CHECK_SMS_WATCH_PID_FILE" 2>/dev/null)"
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
      return 0
    fi
    rm -f "$CHECK_SMS_WATCH_PID_FILE" 2>/dev/null || true
  fi

  (
    export CHECK_SMS_WATCH_INTERVAL="${SMS_WATCH_INTERVAL:-$CHECK_SMS_WATCH_INTERVAL}"
    _check_sms_watch_loop ""
  ) >>"$CHECK_SMS_WATCH_LOG" 2>&1 &
  watch_pid=$!
  echo "$watch_pid" >"$CHECK_SMS_WATCH_PID_FILE"
  _check_sms_watch_log "sms_watch: auto-started pid=$watch_pid interval=$CHECK_SMS_WATCH_INTERVAL"
}

handle_sms_watch_on() {
  arg="$1"
  CID="$2"

  interval="${SMS_WATCH_INTERVAL:-$CHECK_SMS_WATCH_INTERVAL}"
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
    SMS_WATCH_INTERVAL="$interval"
    export SMS_WATCH_INTERVAL
  fi

  rm -f "$CHECK_SMS_WATCH_DISABLED_FILE" 2>/dev/null || true
  _check_sms_watch_stop_pid

  (
    export CHECK_SMS_WATCH_INTERVAL="${SMS_WATCH_INTERVAL:-$CHECK_SMS_WATCH_INTERVAL}"
    _check_sms_watch_loop "$CID"
  ) >>"$CHECK_SMS_WATCH_LOG" 2>&1 &
  watch_pid=$!
  echo "$watch_pid" >"$CHECK_SMS_WATCH_PID_FILE"

  send_code "✅ SMS watch enabled (every <b>${interval}</b>s). Existing inbox messages are not resent.
<i>The module auto-watches after boot — use /sms_watch_off to pause.</i>"
}

handle_sms_watch_off() {
  touch "$CHECK_SMS_WATCH_DISABLED_FILE" 2>/dev/null || true
  _check_sms_watch_stop_pid
  send_code "⏸ Auto-forward of new SMS to Telegram is paused.
Resume: <code>/sms_watch_on</code> or remove <code>tg_sms_watch_disabled</code> and restart the module."
}

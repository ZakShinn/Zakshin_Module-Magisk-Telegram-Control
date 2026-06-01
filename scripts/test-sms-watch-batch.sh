#!/system/bin/sh
MOD="/data/adb/modules/TelegramControl"
. "$MOD/config.sh"
. "$MOD/lib/common.sh"
. "$MOD/lib/sms.sh"
. "$MOD/lib/check_sms_watch.sh"
last_tie_ts=1780308658266
last_tie_id=82
last_ts=1780308658266
raw="$(_check_sms_watch_query_raw_limit 1)"
row="$(printf '%s' "$raw" | grep '^Row:' | head -n1)"
cur_top_ts="$(_check_sms_watch_extract_date "$row")"
cur_top_id="$(_check_sms_watch_extract_id "$row")"
echo "cur=$cur_top_ts,$cur_top_id tie=$last_tie_ts,$last_tie_id"
_check_sms_watch_process_new_batch "$last_ts" "$last_tie_ts" "$last_tie_id" "$cur_top_ts" "$cur_top_id"
echo "after tie=$(cat /data/local/tmp/tg_device_bot_check_sms_last_tie 2>/dev/null)"

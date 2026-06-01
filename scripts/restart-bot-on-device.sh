#!/system/bin/sh
kill "$(cat /data/local/tmp/tg_device_bot_service.pid 2>/dev/null)" 2>/dev/null
kill "$(cat /data/local/tmp/tg_device_bot_check_sms_watch_pid 2>/dev/null)" 2>/dev/null
pkill -f sms_watch_runner 2>/dev/null
rm -f /data/local/tmp/tg_device_bot_service.pid
rm -f /data/local/tmp/tg_device_bot_check_sms_watch_pid
rm -f /data/local/tmp/tg_sms_watch_disabled
echo "---" >/data/local/tmp/tg_device_bot.log
export TG_SERVICE_DAEMON=1
nohup sh /data/adb/modules/TelegramControl/service.sh >>/data/local/tmp/tg_device_bot.log 2>&1 &

#!/system/bin/sh
MOD="/data/adb/modules/TelegramControl"
. "$MOD/config.sh"
. "$MOD/lib/common.sh"
. "$MOD/lib/sms.sh"
line="$(content query --uri content://sms/inbox --projection _id:address:date:body --sort 'date DESC' | grep '^Row:' | head -n1)"
echo "Sending test Telegram for inbox row..."
sms_send_inbox_row "$line" 1 "TEST SMS forward"
echo "Done."

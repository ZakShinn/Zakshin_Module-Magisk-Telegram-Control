@echo off
REM Chay trong thu muc platform-tools (co adb.exe). May bat USB debugging.
REM KHONG dung: tr -d '\r' tren Android (co the xoa het chu "r" trong file .sh).
setlocal
where adb >nul 2>&1 || (
  echo Khong tim thay adb trong PATH. cd vao thu muc platform-tools roi chay lai.
  exit /b 1
)
echo === Thiet bi ===
adb devices
echo.
echo === Doc inbox (giong /sms) ===
adb shell "content query --uri content://sms/inbox --projection _id:address:date:body --sort \"date DESC\"" | head -n 3
echo.
echo === Thu gui SMS (giong /sentsms) ===
adb shell "cmd phone send-sms 888 test_from_adb"
echo.
echo === Log module ===
adb shell "tail -n 30 /data/local/tmp/tg_device_bot.log 2>/dev/null"
echo.
echo === PID sms watch ===
adb shell "cat /data/local/tmp/tg_device_bot_check_sms_watch_pid 2>/dev/null; ls -l /data/local/tmp/tg_sms_watch_disabled 2>/dev/null"
endlocal

# Push .sh (LF) to /sdcard then su cp -> Magisk module. Run from repo root.
$pt = Join-Path $PSScriptRoot "..\platform-tools\adb.exe"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$mod = "/data/adb/modules/TelegramControl"

function Push-LfSh($rel, $name) {
  $src = Join-Path $root $rel
  $c = [IO.File]::ReadAllText($src) -replace "`r`n", "`n" -replace "`r", ""
  $tmp = Join-Path $env:TEMP "tg_$name"
  [IO.File]::WriteAllText($tmp, $c, [Text.UTF8Encoding]::new($false))
  & $pt push $tmp "/sdcard/tg_$name"
  & $pt shell "su -c 'cp /sdcard/tg_$name $mod/$rel && chmod 644 $mod/$rel'"
}

Push-LfSh "lib/sms.sh" "sms.sh"
Push-LfSh "lib/common.sh" "common.sh"
Push-LfSh "lib/check_sms_watch.sh" "check_sms_watch.sh"
Push-LfSh "lib/sms_watch_runner.sh" "sms_watch_runner.sh"
Push-LfSh "lib/handlers.sh" "handlers.sh"
Push-LfSh "lib/dev_cmds.sh" "dev_cmds.sh"
Push-LfSh "lib/bot_commands.sh" "bot_commands.sh"
Push-LfSh "service.sh" "service.sh"
& $pt shell "su -c 'chmod 755 $mod/lib/sms_watch_runner.sh; sh -n $mod/lib/sms.sh; sh -n $mod/lib/check_sms_watch.sh; sh -n $mod/lib/dev_cmds.sh; sh -n $mod/lib/handlers.sh'"
Write-Host "Done. Restart module service or reboot."

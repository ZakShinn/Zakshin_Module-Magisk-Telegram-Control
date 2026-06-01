# shellcheck shell=sh
# English /dev help (overrides lib/dev_cmds.sh after sourcing)

dev_commands_help_full() {
  cat <<'EOF'
<b>🛠 Advanced commands · /dev</b>
<i>Some commands depend on ROM / permissions — try individually if one fails</i>
<code>────────────────────────</code>

<b>📡 Network</b>
• <code>/airplane_on</code> · <code>/airplane_off</code> — Airplane mode
• <code>/data_on</code> · <code>/data_off</code> — Mobile data
• <code>/nfc_on</code> · <code>/nfc_off</code> — NFC
• <code>/wifi_on</code> · <code>/wifi_off</code> · <code>/wifi_info</code> · <code>/wifi_scan</code>
• <code>/bt_on</code> · <code>/bt_off</code> · <code>/bt_info</code>
• <code>/usb_lan_on</code> · <code>/usb_lan_off</code> · <code>/rndis_on</code> · <code>/rndis_off</code>
• <code>/usb_status</code> · <code>/tether_status</code> · <code>/dns</code> · <code>/net_if</code>
• <code>/hotspot_on</code> [SSID password] · <code>/hotspot_off</code> · <code>/hotspot_status</code>

<b>🖥 Display · audio</b>
• <code>/torch_on</code> · <code>/torch_off</code> · <code>/screen_on</code> · <code>/screen_off</code>
• <code>/lock</code> · <code>/screenshot</code>
• <code>/brightness</code> [0–255] · <code>/brightness_auto</code> · <code>/brightness_manual</code>
• <code>/volume</code> [0–15] · <code>/vol_up</code> · <code>/vol_down</code> · <code>/media_play</code>
• <code>/stayon_on</code> · <code>/stayon_off</code> · <code>/rotate_on</code> · <code>/rotate_off</code>
• <code>/ringer_normal</code> · <code>/ringer_silent</code> · <code>/ringer_vibrate</code>
• <code>/anim_on</code> · <code>/anim_off</code>

<b>⚙️ System</b>
• <code>/device</code> · <code>/cpu</code> · <code>/temp</code> · <code>/storage</code> · <code>/mem</code>
• <code>/uptime</code> · <code>/datetime</code>
• <code>/prop</code> name · <code>/rootid</code>
• <code>/logcat</code> [lines] · <code>/logcat_clear</code> · <code>/dmesg</code>
• <code>/reboot_recovery</code> · <code>/reboot_bootloader</code>

<b>📦 Apps</b>
• <code>/packages</code> [filter] · <code>/pkg</code> package · <code>/open</code> · <code>/kill</code> · <code>/clear</code>
• <code>/input</code> text (focus a field first)
• <code>/unknown_sources_on</code> · <code>/unknown_sources_off</code>

<b>📨 SMS inbox → Telegram</b>
• <b>On</b> by default while the bot runs
• <code>/sms_watch_off</code> — Pause
• <code>/sms_watch_on</code> [seconds] — Resume (poll interval, default 8s)

<b>🔁 Other</b>
• <code>/sync_on</code> · <code>/sync_off</code> — Sync
• <code>/location_on</code> · <code>/location_off</code> — GPS
• <code>/dnd_on</code> · <code>/dnd_off</code> — Do not disturb
• <code>/loop_on</code> &lt;minutes&gt; &lt;command&gt; · <code>/loop_off</code>

<code>────────────────────────</code>
<i>Basic commands: /help · [ ] = optional</i>
EOF
}

dev_commands_send_help() {
  send_code "$(dev_commands_help_full)"
}

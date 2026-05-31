# shellcheck shell=sh
# Monitor charging / RNDIS / hotspot changes

handle_monitor_changes() {
  last_charge="$(get_charge_state_simple)"
  last_rndis="$(get_rndis_state_simple)"
  last_hotspot="$(get_hotspot_state_simple)"
  last_low_batt_warned=0

  while true; do
    cur_charge="$(get_charge_state_simple)"
    cur_rndis="$(get_rndis_state_simple)"
    cur_hotspot="$(get_hotspot_state_simple)"

    if [ "$cur_charge" != "$last_charge" ]; then
      case "$cur_charge" in
        charging)     send_code "⚡ Battery: <b>START CHARGING</b> (level: $(get_batt_level)%)" ;;
        not_charging) send_code "🔋 Battery: <b>STOP CHARGING</b> (level: $(get_batt_level)%)" ;;
        *)            send_code "🔋 Battery: <b>UNKNOWN STATE</b>" ;;
      esac
      last_charge="$cur_charge"
    fi

    if [ "$cur_rndis" != "$last_rndis" ]; then
      if [ "$cur_rndis" = "on" ]; then
        send_code "🔌 RNDIS: <b>ON</b>"
      else
        send_code "🔌 RNDIS: <b>OFF</b>"
      fi
      last_rndis="$cur_rndis"
    fi

    if [ "$cur_hotspot" != "$last_hotspot" ]; then
      if [ "$cur_hotspot" = "off" ]; then
        # /hotspot_off already sent "Hotspot is OFF." after verification — avoid duplicates.
        if [ -f /data/local/tmp/tg_hotspot_off_by_cmd ]; then
          rm -f /data/local/tmp/tg_hotspot_off_by_cmd 2>/dev/null || true
        else
          send_code "📡 Hotspot: <b>OFF</b>"
        fi
      else
        send_code "📡 Hotspot: <b>UNKNOWN</b>"
      fi
      last_hotspot="$cur_hotspot"
    fi

    lvl="$(get_batt_level_int)"
    if [ -n "$lvl" ] && [ "$lvl" -lt 10 ] 2>/dev/null; then
      if [ "$cur_charge" = "charging" ]; then
        last_low_batt_warned=0
      else
        if [ "$last_low_batt_warned" != "1" ]; then
          send_code "🪫 <b>Low battery (${lvl}%)</b>\nBelow 10% — please <b>charge now</b>."
          last_low_batt_warned=1
        fi
      fi
    else
      last_low_batt_warned=0
    fi

    sleep 5
  done
}


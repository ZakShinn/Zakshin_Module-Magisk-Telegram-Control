# shellcheck shell=sh
# Theo dõi sạc / RNDIS / hotspot (giống bản gốc trong old/service.sh)

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
        charging)     send_code "⚡ Pin: <b>BẮT ĐẦU SẠC</b> (level: $(get_batt_level)%)" ;;
        not_charging) send_code "🔋 Pin: <b>NGỪNG SẠC</b> (level: $(get_batt_level)%)" ;;
        *)            send_code "🔋 Pin: <b>TRẠNG THÁI KHÔNG RÕ</b>" ;;
      esac
      last_charge="$cur_charge"
    fi

    if [ "$cur_rndis" != "$last_rndis" ]; then
      if [ "$cur_rndis" = "on" ]; then
        send_code "🔌 RNDIS: <b>ĐÃ BẬT</b>"
      else
        send_code "🔌 RNDIS: <b>ĐÃ TẮT</b>"
      fi
      last_rndis="$cur_rndis"
    fi

    if [ "$cur_hotspot" != "$last_hotspot" ]; then
      if [ "$cur_hotspot" = "off" ]; then
        # /hotspot_off đã gửi "Hotspot đã tắt." sau khi kiểm tra — tránh trùng tin.
        if [ -f /data/local/tmp/tg_hotspot_off_by_cmd ]; then
          rm -f /data/local/tmp/tg_hotspot_off_by_cmd 2>/dev/null || true
        else
          send_code "📡 Hotspot: <b>ĐÃ TẮT</b>"
        fi
      else
        send_code "📡 Hotspot: <b>KHÔNG RÕ</b>"
      fi
      last_hotspot="$cur_hotspot"
    fi

    lvl="$(get_batt_level_int)"
    if [ -n "$lvl" ] && [ "$lvl" -lt 10 ] 2>/dev/null; then
      if [ "$cur_charge" = "charging" ]; then
        last_low_batt_warned=0
      else
        if [ "$last_low_batt_warned" != "1" ]; then
          send_code "🪫 <b>Pin yếu (${lvl}%)</b>\nCòn dưới 10% — vui lòng <b>sạc pin</b> ngay."
          last_low_batt_warned=1
        fi
      fi
    else
      last_low_batt_warned=0
    fi

    sleep 5
  done
}

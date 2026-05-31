# shellcheck shell=sh
# Tổng hợp lưu lượng iface + shutdown/restart/datausage

hr_mb() {
  bytes="$1"
  [ -z "$bytes" ] && bytes=0
  awk -v b="$bytes" 'BEGIN{printf "%.2f MB", b/1024/1024}'
}

collect_iface_totals() {
  NETS=$(dumpsys netstats 2>/dev/null)
  DEBUG=${DEBUG:-0}

  if [ -z "$NETS" ]; then
    if [ -r /proc/net/dev ]; then
      awk -v dbg="$DEBUG" '
        NR>2 {
          line=$0
          sub(/^[ \t]+/, "", line)
          split(line, parts, ":")
          iface=parts[1]
          sub(/@.*/, "", iface)
          split(parts[2], a)
          rx = (a[1] + 0)
          tx = (a[9] + 0)

          if(iface=="p2p0" || iface=="wlan1" || iface=="ap0" || iface=="br0" || iface=="usb0" || iface ~ /rmnet_usb/ || iface ~ /^usb/){
            h_rx+=rx; h_tx+=tx
            if(dbg==1) printf("DEBUG_HOTSPOT %s %d %d\n", iface, rx, tx) > "/dev/stderr"
            next
          }
          if(iface ~ /^rndis/){
            r_rx+=rx; r_tx+=tx
            if(dbg==1) printf("DEBUG_RNDIS %s %d %d\n", iface, rx, tx) > "/dev/stderr"
            next
          }
          if(iface ~ /^rmnet/ || iface ~ /^ccmni/ || iface ~ /^rmnet_data/){ m_rx+=rx; m_tx+=tx; next }
          if(iface ~ /^bond/){ b_rx+=rx; b_tx+=tx; next }
          if(iface ~ /^eth/){ e_rx+=rx; e_tx+=tx; next }
          if(iface ~ /^wlan[0-9]+$/){ w_rx+=rx; w_tx+=tx; next }
        }
        END{
          if(w_rx=="") w_rx=0; if(w_tx=="") w_tx=0;
          if(m_rx=="") m_rx=0; if(m_tx=="") m_tx=0;
          if(r_rx=="") r_rx=0; if(r_tx=="") r_tx=0;
          if(h_rx=="") h_rx=0; if(h_tx=="") h_tx=0;
          if(e_rx=="") e_rx=0; if(e_tx=="") e_tx=0;
          if(b_rx=="") b_rx=0; if(b_tx=="") b_tx=0;
          printf "%d %d %d %d %d %d %d %d %d %d %d %d\n", w_rx, w_tx, m_rx, m_tx, r_rx, r_tx, h_rx, h_tx, e_rx, e_tx, b_rx, b_tx
        }
      ' /proc/net/dev
    else
      echo ""
      return 1
    fi
    return 0
  fi

  printf '%s\n' "$NETS" | awk -v dbg="$DEBUG" '
    /mIfaceStatsMap:/{in=1; next}
    /mStatsMapB:/{in=0}
    in && NF>=6 {
      iface=$2; sub(/@.*/, "", iface); rx=$3; tx=$5
      if(iface=="p2p0" || iface=="wlan1" || iface=="ap0" || iface=="br0" || iface=="usb0" || iface ~ /rmnet_usb/ || iface ~ /^usb/){h_rx+=rx; h_tx+=tx; if(dbg==1) printf("DEBUG_HOTSPOT %s %d %d\n", iface, rx, tx) > "/dev/stderr"; next}
      else if(iface ~ /^rndis/){r_rx+=rx; r_tx+=tx; if(dbg==1) printf("DEBUG_RNDIS %s %d %d\n", iface, rx, tx) > "/dev/stderr"; next}
      else if(iface ~ /^rmnet/ || iface ~ /^ccmni/ || iface ~ /^rmnet_data/){m_rx+=rx; m_tx+=tx; next}
      else if(iface ~ /^bond/){b_rx+=rx; b_tx+=tx; next}
      else if(iface ~ /^eth/){e_rx+=rx; e_tx+=tx; next}
      else if(iface ~ /^wlan[0-9]+$/){w_rx+=rx; w_tx+=tx; next}
    }
    END{
      if(w_rx=="") w_rx=0; if(w_tx=="") w_tx=0;
      if(m_rx=="") m_rx=0; if(m_tx=="") m_tx=0;
      if(r_rx=="") r_rx=0; if(r_tx=="") r_tx=0;
      if(h_rx=="") h_rx=0; if(h_tx=="") h_tx=0;
      if(e_rx=="") e_rx=0; if(e_tx=="") e_tx=0;
      if(b_rx=="") b_rx=0; if(b_tx=="") b_tx=0;
      printf "%d %d %d %d %d %d %d %d %d %d %d %d\n", w_rx, w_tx, m_rx, m_tx, r_rx, r_tx, h_rx, h_tx, e_rx, e_tx, b_rx, b_tx
    }
  '
}

_totals_fallback_sysfs() {
  W_RX=0; W_TX=0
  for _wf in /sys/class/net/wlan*; do
    [ -e "$_wf" ] || continue
    _bn="${_wf##*/}"
    case "$_bn" in wlan1) continue ;; esac
    echo "$_bn" | grep -qE '^wlan[0-9]+$' || continue
    if [ -r "$_wf/statistics/rx_bytes" ]; then
      W_RX=$((W_RX + $(cat "$_wf/statistics/rx_bytes")))
      W_TX=$((W_TX + $(cat "$_wf/statistics/tx_bytes")))
    fi
  done

  E_RX=0; E_TX=0
  for _ef in /sys/class/net/eth[0-9]*; do
    [ -e "$_ef" ] || continue
    if [ -r "$_ef/statistics/rx_bytes" ]; then
      E_RX=$((E_RX + $(cat "$_ef/statistics/rx_bytes")))
      E_TX=$((E_TX + $(cat "$_ef/statistics/tx_bytes")))
    fi
  done

  B_RX=0; B_TX=0
  for _bf in /sys/class/net/bond[0-9]*; do
    [ -e "$_bf" ] || continue
    if [ -r "$_bf/statistics/rx_bytes" ]; then
      B_RX=$((B_RX + $(cat "$_bf/statistics/rx_bytes")))
      B_TX=$((B_TX + $(cat "$_bf/statistics/tx_bytes")))
    fi
  done

  M_RX=0; M_TX=0
  for ifn in rmnet0 rmnet_data0 ccmni0; do
    if [ -r "/sys/class/net/$ifn/statistics/rx_bytes" ]; then
      M_RX=$((M_RX + $(cat "/sys/class/net/$ifn/statistics/rx_bytes")))
      M_TX=$((M_TX + $(cat "/sys/class/net/$ifn/statistics/tx_bytes")))
    fi
  done

  R_RX=0; R_TX=0
  for ifn in rndis0 rndis1; do
    if [ -r "/sys/class/net/$ifn/statistics/rx_bytes" ]; then
      R_RX=$((R_RX + $(cat "/sys/class/net/$ifn/statistics/rx_bytes")))
      R_TX=$((R_TX + $(cat "/sys/class/net/$ifn/statistics/tx_bytes")))
    fi
  done

  HS_RX=0; HS_TX=0
  for ifn in p2p0 wlan1 ap0 br0 usb0; do
    if [ -r "/sys/class/net/$ifn/statistics/rx_bytes" ]; then
      HS_RX=$((HS_RX + $(cat "/sys/class/net/$ifn/statistics/rx_bytes")))
      HS_TX=$((HS_TX + $(cat "/sys/class/net/$ifn/statistics/tx_bytes")))
    fi
  done

  printf "%s %s %s %s %s %s %s %s %s %s %s %s\n" \
    "$W_RX" "$W_TX" "$M_RX" "$M_TX" "$R_RX" "$R_TX" "$HS_RX" "$HS_TX" \
    "$E_RX" "$E_TX" "$B_RX" "$B_TX"
}

_resolve_totals_vars() {
  totals="$(collect_iface_totals)"
  rc=$?
  if [ $rc -ne 0 ] || [ -z "$totals" ]; then
    totals="$(_totals_fallback_sysfs)"
  fi

  set -- $totals
  W_RX=${1:-0}; W_TX=${2:-0}
  M_RX=${3:-0}; M_TX=${4:-0}
  R_RX=${5:-0}; R_TX=${6:-0}
  HS_RX=${7:-0}; HS_TX=${8:-0}
  E_RX=${9:-0}; E_TX=${10:-0}
  B_RX=${11:-0}; B_TX=${12:-0}

  W_RX=${W_RX:-0}; W_TX=${W_TX:-0}
  M_RX=${M_RX:-0}; M_TX=${M_TX:-0}
  R_RX=${R_RX:-0}; R_TX=${R_TX:-0}
  HS_RX=${HS_RX:-0}; HS_TX=${HS_TX:-0}
  E_RX=${E_RX:-0}; E_TX=${E_TX:-0}
  B_RX=${B_RX:-0}; B_TX=${B_TX:-0}
}

_build_usage_summary_html() {
  title="$1"

  _resolve_totals_vars

  W_RX_H=$(hr_mb "$W_RX"); W_TX_H=$(hr_mb "$W_TX")
  M_RX_H=$(hr_mb "$M_RX"); M_TX_H=$(hr_mb "$M_TX")
  R_RX_H=$(hr_mb "$R_RX"); R_TX_H=$(hr_mb "$R_TX")
  HS_RX_H=$(hr_mb "$HS_RX"); HS_TX_H=$(hr_mb "$HS_TX")
  E_RX_H=$(hr_mb "$E_RX"); E_TX_H=$(hr_mb "$E_TX")
  B_RX_H=$(hr_mb "$B_RX"); B_TX_H=$(hr_mb "$B_TX")

  SUMMARY="<b>${title}</b>\n<code>────────────────────────</code>\n\n"
  SUMMARY="${SUMMARY}🔵 <b>Wi‑Fi STA</b> <i>(wlan[0-9], trừ wlan1/ap)</i>\n └ RX <code>${W_RX_H}</code> · TX <code>${W_TX_H}</code>\n\n"
  SUMMARY="${SUMMARY}🖧 <b>Ethernet</b> <i>(eth*)</i>\n └ RX <code>${E_RX_H}</code> · TX <code>${E_TX_H}</code>\n\n"
  SUMMARY="${SUMMARY}🔗 <b>Bond</b> <i>(bond*)</i>\n └ RX <code>${B_RX_H}</code> · TX <code>${B_TX_H}</code>\n\n"
  SUMMARY="${SUMMARY}📶 <b>Mobile</b> <i>(rmnet*)</i>\n └ RX <code>${M_RX_H}</code> · TX <code>${M_TX_H}</code>\n\n"
  SUMMARY="${SUMMARY}🔌 <b>RNDIS</b> <i>(rndis*)</i>\n └ RX <code>${R_RX_H}</code> · TX <code>${R_TX_H}</code>\n\n"
  SUMMARY="${SUMMARY}📡 <b>Hotspot</b> <i>(p2p0/wlan1…)</i>\n └ RX <code>${HS_RX_H}</code> · TX <code>${HS_TX_H}</code>\n"

  if [ "${DEBUG:-0}" = "1" ] && [ -r /proc/net/dev ]; then
    debug_list=$(awk '
      NR>2 {
        line=$0; sub(/^[ \t]+/, "", line)
        split(line, parts, ":"); iface=parts[1]; split(parts[2], a)
        rx=a[1]+0; tx=a[9]+0
        if(iface ~ /^rndis/){ printf("RNDIS %s: RX=%d TX=%d\n", iface, rx, tx) }
        if(iface=="p2p0" || iface=="wlan1" || iface=="ap0" || iface=="br0" || iface=="usb0" || iface ~ /rmnet_usb/ || iface ~ /^usb/){
          printf("HOTSPOT %s: RX=%d TX=%d\n", iface, rx, tx)
        }
        if(iface ~ /^eth/){ printf("ETH %s: RX=%d TX=%d\n", iface, rx, tx) }
        if(iface ~ /^bond/){ printf("BOND %s: RX=%d TX=%d\n", iface, rx, tx) }
      }
    ' /proc/net/dev)
    SUMMARY="${SUMMARY}\n<code>${debug_list}</code>"
  fi

  printf '%s' "$SUMMARY"
}

handle_shutdown() {
  send_code "🛑 Đang tắt máy..."

  NETS=$(dumpsys netstats 2>/dev/null)

  if [ -z "$NETS" ] && [ ! -r /proc/net/dev ]; then
    send_code "⚠️ Không lấy được dumpsys netstats và /proc/net/dev không đọc được. Tiến hành tắt."
    if command -v svc >/dev/null 2>&1; then
      svc power shutdown 2>/dev/null || reboot -p
    else
      reboot -p
    fi
    return 1
  fi

  _resolve_totals_vars

  W_RX_H=$(hr_mb "$W_RX"); W_TX_H=$(hr_mb "$W_TX")
  M_RX_H=$(hr_mb "$M_RX"); M_TX_H=$(hr_mb "$M_TX")
  R_RX_H=$(hr_mb "$R_RX"); R_TX_H=$(hr_mb "$R_TX")
  HS_RX_H=$(hr_mb "$HS_RX"); HS_TX_H=$(hr_mb "$HS_TX")
  E_RX_H=$(hr_mb "$E_RX"); E_TX_H=$(hr_mb "$E_TX")
  B_RX_H=$(hr_mb "$B_RX"); B_TX_H=$(hr_mb "$B_TX")

  SUMMARY="📊 <b>Tổng lưu lượng trước tắt máy:</b>\n\n"
  SUMMARY="${SUMMARY}🔵 <b>Wi‑Fi STA (wlan*):</b> <code>RX ${W_RX_H} | TX ${W_TX_H}</code>\n"
  SUMMARY="${SUMMARY}🖧 <b>Ethernet (eth*):</b> <code>RX ${E_RX_H} | TX ${E_TX_H}</code>\n"
  SUMMARY="${SUMMARY}🔗 <b>Bond (bond*):</b> <code>RX ${B_RX_H} | TX ${B_TX_H}</code>\n"
  SUMMARY="${SUMMARY}📶 <b>Mobile (rmnet*):</b> <code>RX ${M_RX_H} | TX ${M_TX_H}</code>\n"
  SUMMARY="${SUMMARY}🔌 <b>RNDIS (rndis*):</b> <code>RX ${R_RX_H} | TX ${R_TX_H}</code>\n"
  SUMMARY="${SUMMARY}📡 <b>Hotspot (p2p0/wlan1/ap0/br0/usb*):</b> <code>RX ${HS_RX_H} | TX ${HS_TX_H}</code>\n"

  if [ "${DEBUG:-0}" = "1" ] && [ -r /proc/net/dev ]; then
    debug_list=$(awk '
      NR>2 {
        line=$0; sub(/^[ \t]+/, "", line)
        split(line, parts, ":"); iface=parts[1]; split(parts[2], a)
        rx=a[1]+0; tx=a[9]+0
        if(iface ~ /^rndis/){ printf("RNDIS %s: RX=%d TX=%d\n", iface, rx, tx) }
        if(iface=="p2p0" || iface=="wlan1" || iface=="ap0" || iface=="br0" || iface=="usb0" || iface ~ /rmnet_usb/ || iface ~ /^usb/){
          printf("HOTSPOT %s: RX=%d TX=%d\n", iface, rx, tx)
        }
        if(iface ~ /^eth/){ printf("ETH %s: RX=%d TX=%d\n", iface, rx, tx) }
        if(iface ~ /^bond/){ printf("BOND %s: RX=%d TX=%d\n", iface, rx, tx) }
      }
    ' /proc/net/dev)
    SUMMARY="${SUMMARY}\n<code>DEBUG interfaces:\n${debug_list}</code>"
  fi

  send_code "$SUMMARY"
  sleep 1

  if command -v svc >/dev/null 2>&1; then
    svc power shutdown 2>/dev/null || reboot -p
  else
    reboot -p
  fi

  return 0
}

handle_restart() {
  send_code "🔁 Đang khởi động lại..."

  NETS=$(dumpsys netstats 2>/dev/null)

  if [ -z "$NETS" ] && [ ! -r /proc/net/dev ]; then
    send_code "⚠️ Không lấy được dumpsys netstats và /proc/net/dev không đọc được. Tiến hành khởi động lại."
    if command -v svc >/dev/null 2>&1; then
      svc power reboot 2>/dev/null || reboot
    else
      reboot
    fi
    return 1
  fi

  _resolve_totals_vars

  W_RX_H=$(hr_mb "$W_RX"); W_TX_H=$(hr_mb "$W_TX")
  M_RX_H=$(hr_mb "$M_RX"); M_TX_H=$(hr_mb "$M_TX")
  R_RX_H=$(hr_mb "$R_RX"); R_TX_H=$(hr_mb "$R_TX")
  HS_RX_H=$(hr_mb "$HS_RX"); HS_TX_H=$(hr_mb "$HS_TX")
  E_RX_H=$(hr_mb "$E_RX"); E_TX_H=$(hr_mb "$E_TX")
  B_RX_H=$(hr_mb "$B_RX"); B_TX_H=$(hr_mb "$B_TX")

  SUMMARY="📊 <b>Tổng lưu lượng trước khởi động lại:</b>\n\n"
  SUMMARY="${SUMMARY}🔵 <b>Wi‑Fi STA (wlan*):</b> <code>RX ${W_RX_H} | TX ${W_TX_H}</code>\n"
  SUMMARY="${SUMMARY}🖧 <b>Ethernet (eth*):</b> <code>RX ${E_RX_H} | TX ${E_TX_H}</code>\n"
  SUMMARY="${SUMMARY}🔗 <b>Bond (bond*):</b> <code>RX ${B_RX_H} | TX ${B_TX_H}</code>\n"
  SUMMARY="${SUMMARY}📶 <b>Mobile (rmnet*):</b> <code>RX ${M_RX_H} | TX ${M_TX_H}</code>\n"
  SUMMARY="${SUMMARY}🔌 <b>RNDIS (rndis*):</b> <code>RX ${R_RX_H} | TX ${R_TX_H}</code>\n"
  SUMMARY="${SUMMARY}📡 <b>Hotspot (p2p0/wlan1/ap0/br0/usb*):</b> <code>RX ${HS_RX_H} | TX ${HS_TX_H}</code>\n"

  if [ "${DEBUG:-0}" = "1" ] && [ -r /proc/net/dev ]; then
    debug_list=$(awk '
      NR>2 {
        line=$0; sub(/^[ \t]+/, "", line)
        split(line, parts, ":"); iface=parts[1]; split(parts[2], a)
        rx=a[1]+0; tx=a[9]+0
        if(iface ~ /^rndis/){ printf("RNDIS %s: RX=%d TX=%d\n", iface, rx, tx) }
        if(iface=="p2p0" || iface=="wlan1" || iface=="ap0" || iface=="br0" || iface=="usb0" || iface ~ /rmnet_usb/ || iface ~ /^usb/){
          printf("HOTSPOT %s: RX=%d TX=%d\n", iface, rx, tx)
        }
        if(iface ~ /^eth/){ printf("ETH %s: RX=%d TX=%d\n", iface, rx, tx) }
        if(iface ~ /^bond/){ printf("BOND %s: RX=%d TX=%d\n", iface, rx, tx) }
      }
    ' /proc/net/dev)
    SUMMARY="${SUMMARY}\n<code>DEBUG interfaces:\n${debug_list}</code>"
  fi

  send_code "$SUMMARY"
  sleep 1

  if command -v svc >/dev/null 2>&1; then
    svc power reboot 2>/dev/null || reboot
  else
    reboot
  fi

  return 0
}

handle_datausage() {
  send_code "📡 Đang tổng hợp số liệu mạng (realtime)..."

  DEBUG=${DEBUG:-0}
  SUMMARY="$(_build_usage_summary_html "📊 Báo cáo lưu lượng realtime")"

  send_code "$SUMMARY"
  return 0
}

#!/system/bin/sh
# Tiến trình nền theo dõi SMS — tự nạp lib (tránh mất hàm khi fork từ service cũ).
MODDIR="${1:-}"
CID="${2:-}"
[ -z "$MODDIR" ] && MODDIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$MODDIR"
export SCRIPT_DIR

# shellcheck disable=SC1091
[ -f "${MODDIR}/config.sh" ] && . "${MODDIR}/config.sh"
# shellcheck source=/dev/null
. "${MODDIR}/lib/common.sh"
# shellcheck source=/dev/null
. "${MODDIR}/lib/sms.sh"
# shellcheck source=/dev/null
. "${MODDIR}/lib/check_sms_watch.sh"

_check_sms_watch_loop "$CID"

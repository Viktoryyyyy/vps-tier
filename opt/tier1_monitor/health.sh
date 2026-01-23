#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${LOG_FILE:-/var/log/tier1_health.log}"

ts="$(date -Is)"

iface="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
if [ -z "${iface:-}" ]; then
  iface="eth0"
fi

read -r load1 load5 load15 _ < /proc/loadavg

cpu_stat_1="$(awk '/^cpu /{print $2,$3,$4,$5,$6,$7,$8,$9,$10,$11}' /proc/stat)"
sleep 1
cpu_stat_2="$(awk '/^cpu /{print $2,$3,$4,$5,$6,$7,$8,$9,$10,$11}' /proc/stat)"

calc_iowait() {
  local a="$1" b="$2"
  awk -v a="$a" -v b="$b" '
    BEGIN{
      split(a,A," "); split(b,B," ");
      total1=0; total2=0;
      for(i=1;i<=10;i++){ total1+=A[i]; total2+=B[i]; }
      dtotal=total2-total1;
      diow=B[5]-A[5];
      if(dtotal<=0){ print "0.0"; exit }
      printf "%.1f", (diow*100.0)/dtotal
    }'
}
iowait_pct="$(calc_iowait "$cpu_stat_1" "$cpu_stat_2")"

mem_total_kb="$(awk '/^MemTotal:/{print $2}' /proc/meminfo)"
mem_avail_kb="$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)"
swap_total_kb="$(awk '/^SwapTotal:/{print $2}' /proc/meminfo)"
swap_free_kb="$(awk '/^SwapFree:/{print $2}' /proc/meminfo)"

mem_used_pct="$(awk -v t="$mem_total_kb" -v a="$mem_avail_kb" 'BEGIN{if(t<=0){print "0.0";exit} printf "%.1f", ((t-a)*100.0)/t}')"
mem_avail_mb="$(awk -v a="$mem_avail_kb" 'BEGIN{printf "%.0f", a/1024.0}')"

swap_used_pct="0.0"
if [ "${swap_total_kb:-0}" -gt 0 ]; then
  swap_used_pct="$(awk -v t="$swap_total_kb" -v f="$swap_free_kb" 'BEGIN{printf "%.1f", ((t-f)*100.0)/t}')"
fi

disk_used_pct="$(df -P / | awk 'NR==2{gsub("%","",$5); print $5}')"
inode_used_pct="$(df -Pi / | awk 'NR==2{gsub("%","",$5); print $5}')"

rx1="$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)"
tx1="$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)"
sleep 1
rx2="$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)"
tx2="$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)"

rx_bps="$(awk -v a="$rx1" -v b="$rx2" 'BEGIN{d=b-a; if(d<0)d=0; printf "%.0f", d*8.0}')"
tx_bps="$(awk -v a="$tx1" -v b="$tx2" 'BEGIN{d=b-a; if(d<0)d=0; printf "%.0f", d*8.0}')"

tcp_est="$(ss -Htan state established 2>/dev/null | wc -l | tr -d ' ')"
tcp_total="$(ss -Htan 2>/dev/null | wc -l | tr -d ' ')"

svc_xray="down"
if systemctl is-active --quiet xray; then svc_xray="up"; fi
svc_nginx="down"
if systemctl is-active --quiet nginx; then svc_nginx="up"; fi

rst_xray="$(systemctl show -p NRestarts --value xray 2>/dev/null || echo "")"
rst_nginx="$(systemctl show -p NRestarts --value nginx 2>/dev/null || echo "")"

set +o pipefail
err_xray="$(journalctl -u xray -n 50 --no-pager 2>/dev/null | grep -Eai 'panic|fatal|segfault|out of memory|too many open files|bind\(|failed' | wc -l | tr -d ' ')"
err_nginx="$(journalctl -u nginx -n 50 --no-pager 2>/dev/null | grep -Eai 'emerg|alert|crit|panic|segfault|out of memory|too many open files|bind\(|failed' | wc -l | tr -d ' ')"
set -o pipefail

is_gt() { awk -v x="$1" -v y="$2" 'BEGIN{exit !(x>y)}'; }
is_ge_int() { [ "${1:-0}" -ge "${2:-0}" ]; }

status="OK"
warn=0

# CRIT conditions
if [ "$svc_xray" != "up" ] || [ "$svc_nginx" != "up" ]; then status="CRIT"; fi
if is_gt "$load5" "3.0" || is_gt "$load1" "4.0"; then status="CRIT"; fi
if is_gt "$iowait_pct" "25.0"; then status="CRIT"; fi
if is_gt "$mem_used_pct" "92.0" || is_gt "$(printf "%s" "$mem_avail_mb")" "999999"; then :; fi
if is_gt "$mem_used_pct" "92.0" || is_gt "150" "$mem_avail_mb"; then status="CRIT"; fi
if is_gt "$swap_used_pct" "25.0"; then status="CRIT"; fi
if is_ge_int "$disk_used_pct" "90" || is_ge_int "$inode_used_pct" "85"; then status="CRIT"; fi
if is_ge_int "$err_xray" "1" || is_ge_int "$err_nginx" "1"; then
  if [ "$status" != "CRIT" ]; then status="WARN"; fi
fi

# WARN conditions (only if not already CRIT)
if [ "$status" != "CRIT" ]; then
  if is_gt "$load5" "2.0" || is_gt "$load1" "3.0"; then warn=$((warn+1)); fi
  if is_gt "$iowait_pct" "10.0"; then warn=$((warn+1)); fi
  if is_gt "$mem_used_pct" "85.0" || is_gt "300" "$mem_avail_mb"; then warn=$((warn+1)); fi
  if is_gt "$swap_used_pct" "10.0"; then warn=$((warn+1)); fi
  if is_ge_int "$disk_used_pct" "80" || is_ge_int "$inode_used_pct" "70"; then warn=$((warn+1)); fi
  if is_ge_int "$tcp_est" "500" || is_ge_int "$tcp_total" "2000"; then warn=$((warn+1)); fi
  if is_ge_int "$warn" "2"; then status="WARN"; fi
fi

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

printf '%s status=%s iface=%s load1=%s load5=%s load15=%s iowait_pct=%s mem_used_pct=%s mem_avail_mb=%s swap_used_pct=%s disk_used_pct=%s inode_used_pct=%s rx_bps=%s tx_bps=%s tcp_est=%s tcp_total=%s xray=%s nginx=%s xray_restarts=%s nginx_restarts=%s xray_err50=%s nginx_err50=%s\n' \
  "$ts" "$status" "$iface" "$load1" "$load5" "$load15" "$iowait_pct" "$mem_used_pct" "$mem_avail_mb" "$swap_used_pct" \
  "$disk_used_pct" "$inode_used_pct" "$rx_bps" "$tx_bps" "$tcp_est" "$tcp_total" "$svc_xray" "$svc_nginx" \
  "${rst_xray:-}" "${rst_nginx:-}" "$err_xray" "$err_nginx" >> "$LOG_FILE"

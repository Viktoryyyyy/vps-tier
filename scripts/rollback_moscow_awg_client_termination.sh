#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_IPV4="147.45.184.140"
IFACE="awg-client"
UNIT="awg-quick@$IFACE.service"
TARGET_CONF="/etc/amnezia/amneziawg/$IFACE.conf"
STATE_DIR="/var/lib/vps-tier/moscow-awg-client-termination"
STATE_FILE="$STATE_DIR/state.env"
UFW_COMMENT="vps-tier-awg-client-ingress"

fail() { echo "ERROR: $*" >&2; exit 1; }
ufw_has_marker() { ufw status numbered 2>/dev/null | grep -F "$UFW_COMMENT" >/dev/null; }
remove_owned_ufw_rule() {
  while ufw_has_marker; do
    num="$(ufw status numbered | sed -nE "s/^\[[[:space:]]*([0-9]+)\].*${UFW_COMMENT}.*/\1/p" | head -n1)"
    [ -n "$num" ] || fail "cannot identify owned UFW rule number"
    ufw --force delete "$num" >/dev/null
  done
}

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "run as root"
ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fx "$EXPECTED_IPV4" >/dev/null || fail "host identity mismatch"
[ -r "$STATE_FILE" ] || fail "managed Stage-5 state missing"
# shellcheck disable=SC1090
. "$STATE_FILE"
[ "${owner:-}" = vps-tier ] || fail "state ownership mismatch"
[ "${interface:-}" = "$IFACE" ] || fail "state interface mismatch"
[ "${config_path:-}" = "$TARGET_CONF" ] || fail "state config path mismatch"
[ -n "${material_dir:-}" ] || fail "state material directory missing"
case "$material_dir" in /etc/amnezia/amneziawg/vps-tier/awg-client) ;; *) fail "unexpected material directory" ;; esac

if [ -e "$TARGET_CONF" ]; then
  [ "$(sha256sum "$TARGET_CONF" | awk '{print $1}')" = "${config_sha256:-}" ] || fail "current AWG config diverged; rollback blocked"
fi

DEFAULT_ROUTE_BEFORE="$(ip -4 route show default)"
IPV4_FORWARD_BEFORE="$(sysctl -n net.ipv4.ip_forward)"
IPV6_FORWARD_BEFORE="$(sysctl -n net.ipv6.conf.all.forwarding)"

systemctl disable --now "$UNIT" >/dev/null 2>&1 || true
if ip link show "$IFACE" >/dev/null 2>&1; then
  awg-quick down "$TARGET_CONF" >/dev/null 2>&1 || true
fi
ip link show "$IFACE" >/dev/null 2>&1 && ip link delete "$IFACE" >/dev/null 2>&1 || true
remove_owned_ufw_rule
rm -f "$TARGET_CONF"
rm -rf "$material_dir"

ip link show "$IFACE" >/dev/null 2>&1 && fail "AWG interface still present"
systemctl is-active --quiet "$UNIT" && fail "AWG unit still active"
systemctl is-enabled --quiet "$UNIT" && fail "AWG unit still enabled"
ufw_has_marker && fail "owned UFW rule still present"
[ ! -e "$TARGET_CONF" ] || fail "AWG config still present"
[ ! -e "$material_dir" ] || fail "AWG material still present"
[ "$(ip -4 route show default)" = "$DEFAULT_ROUTE_BEFORE" ] || fail "default route changed during rollback"
[ "$(sysctl -n net.ipv4.ip_forward)" = "$IPV4_FORWARD_BEFORE" ] || fail "IPv4 forwarding changed during rollback"
[ "$(sysctl -n net.ipv6.conf.all.forwarding)" = "$IPV6_FORWARD_BEFORE" ] || fail "IPv6 forwarding changed during rollback"
ping -c 1 -W 2 10.70.0.2 >/dev/null || fail "backbone ping failed after rollback"

ROLLBACK_EVIDENCE="${backup_set:-/var/backups/vps-tier/moscow-awg-client-termination}/rollback-evidence.md"
cat > "$ROLLBACK_EVIDENCE" <<EVIDENCE
# Moscow AmneziaWG Client Termination — Rollback Evidence

- UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- AWG interface removed: yes
- AWG unit disabled/stopped: yes
- Managed UDP/443 UFW rule removed: yes
- Managed AWG config removed: yes
- Managed server/client key and parameter material removed: yes
- IPv4 forwarding changed: no
- IPv6 forwarding changed: no
- Default route changed: no
- Backbone ping after rollback: passed
- Secrets recorded: no
EVIDENCE
chmod 0600 "$ROLLBACK_EVIDENCE"
rm -rf "$STATE_DIR"

echo "DONE: Moscow AWG client termination rollback complete"
echo "INTERFACE=$IFACE"
echo "BACKBONE=preserved"
echo "ROLLBACK_EVIDENCE=$ROLLBACK_EVIDENCE"

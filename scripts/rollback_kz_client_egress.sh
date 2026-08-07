#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_IPV4="194.32.142.88"
WG_IF="wg-backbone"
WAN_IF="enp3s0"
CLIENT_SUBNET="10.71.0.0/24"
PEER_PUBLIC_KEY="tfSZHDDhIcgim4s6fujmel13vSvThM1Q5EAq/lK8kDQ="
BASE_ALLOWED="10.70.0.1/32"
TARGET_CONF="/etc/wireguard/wg-backbone.conf"
TARGET_TMP="${TARGET_CONF}.vps-tier.tmp"
STATE_DIR="/var/lib/vps-tier/kz-client-egress"
STATE_FILE="$STATE_DIR/state.env"
UFW_COMMENT="vps-tier-kz-client-egress-forward"
NAT_COMMENT="vps-tier-kz-client-egress"

fail() { echo "ERROR: $*" >&2; exit 1; }
[ "${EUID:-$(id -u)}" -eq 0 ] || fail "run as root"
for cmd in awk cut grep install ip iptables iptables-save mv ping sha256sum systemctl ufw wg wg-quick; do command -v "$cmd" >/dev/null 2>&1 || fail "missing command: $cmd"; done
[ -r "$STATE_FILE" ] || fail "managed client-egress state missing"
# shellcheck disable=SC1090
. "$STATE_FILE"
[ "$owner" = vps-tier ] || fail "state ownership mismatch"
[ "$client_subnet" = "$CLIENT_SUBNET" ] || fail "state subnet mismatch"
[ -r "$backup_set/wg-backbone.conf.before" ] || fail "backup config missing"
CURRENT_CONFIG_SHA="$(sha256sum "$TARGET_CONF" | awk '{print $1}')"
case "$CURRENT_CONFIG_SHA" in
  "$applied_config_sha256"|"$before_config_sha256") ;;
  *) fail "current backbone config diverged; rollback blocked" ;;
esac
ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fx "$EXPECTED_IPV4" >/dev/null || fail "host identity mismatch"
WG_PRESENT=no
ip link show "$WG_IF" >/dev/null 2>&1 && WG_PRESENT=yes

if iptables -t nat -C POSTROUTING -s "$CLIENT_SUBNET" -o "$WAN_IF" -m comment --comment "$NAT_COMMENT" -j SNAT --to-source "$EXPECTED_IPV4" 2>/dev/null; then
  iptables -t nat -D POSTROUTING -s "$CLIENT_SUBNET" -o "$WAN_IF" -m comment --comment "$NAT_COMMENT" -j SNAT --to-source "$EXPECTED_IPV4"
fi
if ufw status numbered | grep -F "$UFW_COMMENT" >/dev/null; then
  ufw --force delete route allow in on "$WG_IF" out on "$WAN_IF" from "$CLIENT_SUBNET" >/dev/null
fi
if [ "$WG_PRESENT" = yes ]; then
  ip route del "$CLIENT_SUBNET" dev "$WG_IF" 2>/dev/null || true
  wg set "$WG_IF" peer "$PEER_PUBLIC_KEY" allowed-ips "$BASE_ALLOWED"
fi
install -o root -g root -m 0600 "$backup_set/wg-backbone.conf.before" "$TARGET_TMP"
mv -f "$TARGET_TMP" "$TARGET_CONF"
wg-quick strip "$TARGET_CONF" >/dev/null
[ "$(sha256sum "$TARGET_CONF" | awk '{print $1}')" = "$before_config_sha256" ] || fail "baseline config hash not restored"

if ! systemctl is-active --quiet wg-quick@wg-backbone.service; then
  systemctl start wg-quick@wg-backbone.service || fail "baseline config restored but backbone unit could not be started"
fi
WG_PRESENT=no
ip link show "$WG_IF" >/dev/null 2>&1 && WG_PRESENT=yes
[ "$WG_PRESENT" = yes ] || fail "backbone interface absent after config restore"
RUNTIME_ALLOWED="$(wg show "$WG_IF" dump | awk -F '\t' -v key="$PEER_PUBLIC_KEY" '$1==key {print $4}')"
[ "$RUNTIME_ALLOWED" = "$BASE_ALLOWED" ] || fail "baseline AllowedIPs not restored"
ip -4 route show table all | grep -F "$CLIENT_SUBNET" >/dev/null && fail "client subnet route still present"
ufw status numbered | grep -F "$UFW_COMMENT" >/dev/null && fail "UFW client-egress rule still present"
iptables-save -t nat | grep -F "$NAT_COMMENT" >/dev/null && fail "SNAT rule still present"
ping -c 1 -W 2 10.70.0.1 >/dev/null || fail "backbone ping failed after rollback"

ROLLBACK_EVIDENCE="$backup_set/rollback-evidence.md"
cat > "$ROLLBACK_EVIDENCE" <<EVIDENCE
# Kazakhstan Client Egress — Rollback Evidence

- UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Client subnet route removed: yes
- Runtime peer AllowedIPs restored: yes
- Persistent WireGuard config restored: yes
- UFW routed allow removed: yes
- SNAT removed: yes
- Backbone active after rollback: yes
- Backbone ping after rollback: passed
- Secrets recorded: no
EVIDENCE
rm -rf "$STATE_DIR"
echo "DONE: Kazakhstan client egress rollback complete"
echo "CLIENT_SUBNET=$CLIENT_SUBNET"
echo "BACKBONE=preserved"
echo "ROLLBACK_EVIDENCE=$ROLLBACK_EVIDENCE"

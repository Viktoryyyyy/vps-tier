#!/usr/bin/env bash
set -Eeuo pipefail

ROLE="${1:-}"
INTERFACE="wg-backbone"
PORT="51820"
BACKBONE_SUBNET="10.70.0.0/30"
TARGET_CONF="/etc/wireguard/${INTERFACE}.conf"
UNIT="wg-quick@${INTERFACE}.service"
STATE_DIR="/var/lib/vps-tier/wireguard-backbone/${ROLE}"
STATE_FILE="${STATE_DIR}/state.env"
PUBLIC_RULE_MARKER="${STATE_DIR}/ufw-public-rule.created"
PEER_RULE_MARKER="${STATE_DIR}/ufw-peer-rule.created"

case "$ROLE" in
  moscow)
    EXPECTED_IPV4="147.45.184.140"
    LOCAL_TUNNEL_IPV4="10.70.0.1"
    PEER_TUNNEL_IPV4="10.70.0.2"
    PEER_PUBLIC_IPV4="194.32.142.88"
    ;;
  kazakhstan)
    EXPECTED_IPV4="194.32.142.88"
    LOCAL_TUNNEL_IPV4="10.70.0.2"
    PEER_TUNNEL_IPV4="10.70.0.1"
    PEER_PUBLIC_IPV4="147.45.184.140"
    ;;
  *)
    echo "ERROR: role must be moscow or kazakhstan" >&2
    exit 1
    ;;
esac

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

host_has_expected_ipv4() {
  ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fx "$EXPECTED_IPV4" >/dev/null
}

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "run as root"
host_has_expected_ipv4 || fail "host identity mismatch; expected IPv4 $EXPECTED_IPV4"
[ -f "$STATE_FILE" ] || fail "managed backbone state is absent: $STATE_FILE"
grep -x 'owner=vps-tier' "$STATE_FILE" >/dev/null || fail "state ownership mismatch"

systemctl disable --now "$UNIT" >/dev/null 2>&1 || true
ip link delete "$INTERFACE" >/dev/null 2>&1 || true
rm -f "$TARGET_CONF"

if [ -f "$PEER_RULE_MARKER" ]; then
  ufw --force delete allow in on "$INTERFACE" from "$PEER_TUNNEL_IPV4" to "$LOCAL_TUNNEL_IPV4" >/dev/null
  rm -f "$PEER_RULE_MARKER"
fi
if [ -f "$PUBLIC_RULE_MARKER" ]; then
  ufw --force delete allow from "$PEER_PUBLIC_IPV4" to any port "$PORT" proto udp >/dev/null
  rm -f "$PUBLIC_RULE_MARKER"
fi

! ip link show "$INTERFACE" >/dev/null 2>&1 || fail "backbone interface remains"
! ip -4 route show | grep -F "$BACKBONE_SUBNET" >/dev/null || fail "backbone route remains"
! systemctl is-active --quiet "$UNIT" || fail "backbone unit remains active"
! systemctl is-enabled --quiet "$UNIT" || fail "backbone unit remains enabled"
[ ! -e "$TARGET_CONF" ] || fail "backbone config remains"

BACKUP_SET="$(awk -F= '$1=="backup_set" {print substr($0,index($0,"=")+1)}' "$STATE_FILE" | tail -n 1)"
rm -rf "$STATE_DIR"

echo "DONE: WireGuard backbone host rollback completed"
echo "ROLE=$ROLE"
echo "INTERFACE=absent"
echo "ROUTE=absent"
echo "MANAGED_UFW_RULES=absent"
echo "BACKUP_SET=$BACKUP_SET"

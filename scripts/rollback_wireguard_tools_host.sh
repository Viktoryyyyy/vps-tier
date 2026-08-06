#!/usr/bin/env bash
set -Eeuo pipefail

ROLE="${1:-}"
BACKBONE_ROUTE="10.70.0.0/30"

case "$ROLE" in
  moscow)
    EXPECTED_IPV4="147.45.184.140"
    ;;
  kazakhstan)
    EXPECTED_IPV4="194.32.142.88"
    ;;
  *)
    echo "ERROR: role must be moscow or kazakhstan" >&2
    exit 1
    ;;
esac

STATE_DIR="/var/lib/vps-tier/wireguard-tools/$ROLE"
STATE_FILE="$STATE_DIR/state.env"
NEW_PACKAGES_FILE="$STATE_DIR/new-packages.txt"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

snapshot_network_state() {
  {
    ufw status numbered
    ip -4 rule show
    ip -4 route show table all
    sysctl -n net.ipv4.ip_forward
    sysctl -n net.ipv6.conf.all.forwarding
    ss -H -lunp 'sport = :51820'
  } | sha256sum | awk '{print $1}'
}

host_has_expected_ipv4() {
  ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fx "$EXPECTED_IPV4" >/dev/null
}

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "run as root"
host_has_expected_ipv4 || fail "host identity mismatch; expected IPv4 $EXPECTED_IPV4"
[ -f "$STATE_FILE" ] || fail "managed state is absent: $STATE_FILE"
[ -f "$NEW_PACKAGES_FILE" ] || fail "managed package list is absent: $NEW_PACKAGES_FILE"

ip -o link show type wireguard 2>/dev/null | grep . >/dev/null && \
  fail "WireGuard interface exists; toolchain-only rollback is blocked"
ip -4 route show | grep -F "$BACKBONE_ROUTE" >/dev/null && \
  fail "backbone route exists; toolchain-only rollback is blocked"
ss -H -lunp 'sport = :51820' | grep . >/dev/null && \
  fail "udp/51820 is occupied; toolchain-only rollback is blocked"

NETWORK_HASH_BEFORE="$(snapshot_network_state)"
if [ -s "$NEW_PACKAGES_FILE" ]; then
  xargs -r apt-get purge -y -- < "$NEW_PACKAGES_FILE"
fi
rm -rf "$STATE_DIR"

command -v wg >/dev/null 2>&1 && fail "wg command remains after rollback"
modinfo wireguard >/dev/null 2>&1 || fail "wireguard kernel module metadata disappeared"
NETWORK_HASH_AFTER="$(snapshot_network_state)"
[ "$NETWORK_HASH_AFTER" = "$NETWORK_HASH_BEFORE" ] || \
  fail "firewall, forwarding, route, or listener state changed"

echo "DONE: WireGuard tools rollback completed"
echo "ROLE=$ROLE"
echo "MANAGED_STATE=absent"
echo "WIREGUARD_MODULE=present"

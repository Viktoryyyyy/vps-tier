#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_IPV4="194.32.142.88"
EXPECTED_CODENAME="jammy"
WG_IF="wg-backbone"
KZ_WG_IP="10.70.0.2"
MOSCOW_WG_IP="10.70.0.1"
LISTEN_PORT="18080"
TARGET_HOST="api.telegram.org"
TARGET_PORT="443"

fail() { echo "ERROR: $*" >&2; exit 1; }
host_ok() { ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fx "$EXPECTED_IPV4" >/dev/null; }
wg_address_ok() { ip -4 -o addr show dev "$WG_IF" | awk '{print $4}' | grep -Fx "$KZ_WG_IP/30" >/dev/null; }
port_in_use() { ss -H -ltn | awk -v suffix=":$LISTEN_PORT" '$4 ~ suffix"$" {found=1} END{exit(found?0:1)}'; }

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "run as root"
for cmd in awk cut grep ip ping python3 sha256sum ss systemctl ufw wg; do command -v "$cmd" >/dev/null 2>&1 || fail "missing command: $cmd"; done
host_ok || fail "host identity mismatch"
. /etc/os-release
[ "${ID:-}" = ubuntu ] && [ "${VERSION_CODENAME:-}" = "$EXPECTED_CODENAME" ] || fail "OS/suite mismatch"
systemctl is-active --quiet wg-quick@wg-backbone.service || fail "backbone unit inactive"
systemctl is-enabled --quiet wg-quick@wg-backbone.service || fail "backbone unit disabled"
wg_address_ok || fail "Kazakhstan backbone IPv4 mismatch"
ping -I "$WG_IF" -c 1 -W 2 "$MOSCOW_WG_IP" >/dev/null || fail "Moscow backbone peer unreachable"
ufw status | grep -x 'Status: active' >/dev/null || fail "UFW inactive"
port_in_use && fail "TCP port 18080 already in use"
python3 -c 'import socket,ssl; s=socket.create_connection(("api.telegram.org",443),8); t=ssl.create_default_context().wrap_socket(s,server_hostname="api.telegram.org"); assert t.version(); print("KZ_TELEGRAM_TLS=OK"); t.close()'

echo "PROJECT=MOEX_Bot"
echo "HOST=Kazakhstan"
echo "HOST_IPV4=$EXPECTED_IPV4"
echo "BACKBONE=active_enabled"
echo "BACKBONE_IPV4=$KZ_WG_IP"
echo "MOSCOW_PEER=reachable"
echo "UFW=active"
echo "PORT_18080=free"
echo "TARGET=$TARGET_HOST:$TARGET_PORT"
echo "DEFAULT_ROUTE_SHA256=$(ip -4 route show default | sha256sum | awk '{print $1}')"
echo "IP_RULE_SHA256=$(ip -4 rule show | sha256sum | awk '{print $1}')"
echo "SECRETS_PRINTED=no"

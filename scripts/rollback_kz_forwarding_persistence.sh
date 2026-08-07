#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_IPV4="194.32.142.88"
STATE_DIR="/var/lib/vps-tier/kz-forwarding-persistence"
STATE_FILE="$STATE_DIR/state.env"

fail() { echo "ERROR: $*" >&2; exit 1; }
[ "${EUID:-$(id -u)}" -eq 0 ] || fail "run as root"
[ -r "$STATE_FILE" ] || fail "managed forwarding-persistence state missing"
# shellcheck disable=SC1090
. "$STATE_FILE"
[ "$owner" = vps-tier ] || fail "state ownership mismatch"
ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fx "$EXPECTED_IPV4" >/dev/null || fail "host identity mismatch"
[ -r "$sysctl_file" ] || fail "managed sysctl file missing"
[ "$(sha256sum "$sysctl_file" | awk '{print $1}')" = "$sysctl_file_sha256" ] || fail "managed sysctl file diverged; rollback blocked"

rm -f "$sysctl_file"
sysctl -q -w net.ipv4.ip_forward="$ipv4_before"
sysctl -q -w net.ipv6.conf.all.forwarding="$ipv6_before"
[ "$(sysctl -n net.ipv4.ip_forward)" = "$ipv4_before" ] || fail "IPv4 forwarding restore failed"
[ "$(sysctl -n net.ipv6.conf.all.forwarding)" = "$ipv6_before" ] || fail "IPv6 forwarding restore failed"

ROLLBACK_EVIDENCE="$backup_set/rollback-evidence.md"
cat > "$ROLLBACK_EVIDENCE" <<EVIDENCE
# Kazakhstan Forwarding Persistence — Rollback Evidence

- Persistent sysctl file removed: yes
- IPv4 forwarding runtime restored: $ipv4_before
- IPv6 forwarding runtime restored: $ipv6_before
- Secrets recorded: no
EVIDENCE
rm -rf "$STATE_DIR"

echo "DONE: Kazakhstan forwarding persistence rollback complete"
echo "IPV4_FORWARD=$ipv4_before"
echo "IPV6_FORWARD=$ipv6_before"
echo "ROLLBACK_EVIDENCE=$ROLLBACK_EVIDENCE"
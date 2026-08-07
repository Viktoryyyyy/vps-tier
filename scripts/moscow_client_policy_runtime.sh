#!/usr/bin/env bash
set -Eeuo pipefail

ACTION="${1:-}"
TABLE_ID=1071
RULE_PRIORITY=10710
CLIENT_SUBNET="10.71.0.0/24"

fail() { echo "ERROR: $*" >&2; exit 1; }
rule_at_priority() { ip -4 rule show | awk -v p="${RULE_PRIORITY}:" '$1==p {print $1, $2, $3, $4, $5}'; }
exact_rule() { rule_at_priority | grep -Fx "${RULE_PRIORITY}: from ${CLIENT_SUBNET} lookup ${TABLE_ID}" >/dev/null; }

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "run as root"
command -v ip >/dev/null 2>&1 || fail "ip command missing"

case "$ACTION" in
  up)
    existing="$(rule_at_priority || true)"
    if [ -n "$existing" ] && ! exact_rule; then
      fail "policy priority ${RULE_PRIORITY} is occupied by a different rule"
    fi
    ip -4 route replace prohibit default table "$TABLE_ID" metric 32760
    exact_rule || ip -4 rule add priority "$RULE_PRIORITY" from "$CLIENT_SUBNET" lookup "$TABLE_ID"
    exact_rule || fail "managed policy rule missing after install"
    ip -4 route show table "$TABLE_ID" | grep -E '^prohibit default.*metric 32760([[:space:]]|$)' >/dev/null || \
      fail "fail-closed prohibit route missing"
    ;;
  down)
    while exact_rule; do
      ip -4 rule del priority "$RULE_PRIORITY" from "$CLIENT_SUBNET" lookup "$TABLE_ID"
    done
    ip -4 route del prohibit default table "$TABLE_ID" metric 32760 2>/dev/null || true
    ;;
  *)
    fail "usage: $0 up|down"
    ;;
esac

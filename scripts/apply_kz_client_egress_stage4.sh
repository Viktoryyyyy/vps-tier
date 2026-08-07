#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PERSIST_APPLY="$SCRIPT_DIR/apply_kz_forwarding_persistence.sh"
PERSIST_ROLLBACK="$SCRIPT_DIR/rollback_kz_forwarding_persistence.sh"
EGRESS_APPLY="$SCRIPT_DIR/apply_kz_client_egress.sh"
PERSIST_APPLIED=0

cleanup_on_error() {
  rc=$?
  trap - ERR
  if [ "$PERSIST_APPLIED" -eq 1 ] && [ -r /var/lib/vps-tier/kz-forwarding-persistence/state.env ]; then
    "$PERSIST_ROLLBACK" || true
  fi
  exit "$rc"
}

[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "ERROR: run as root" >&2; exit 1; }
for f in "$PERSIST_APPLY" "$PERSIST_ROLLBACK" "$EGRESS_APPLY"; do
  [ -x "$f" ] || { echo "ERROR: missing executable $f" >&2; exit 1; }
done

trap cleanup_on_error ERR
"$PERSIST_APPLY"
PERSIST_APPLIED=1
"$EGRESS_APPLY"
trap - ERR

echo "DONE: Kazakhstan client-egress Stage 4 applied"
echo "FORWARDING_PERSISTENCE=ready"
echo "CLIENT_EGRESS=ready"
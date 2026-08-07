#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
EGRESS_ROLLBACK="$SCRIPT_DIR/rollback_kz_client_egress.sh"
PERSIST_ROLLBACK="$SCRIPT_DIR/rollback_kz_forwarding_persistence.sh"

[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "ERROR: run as root" >&2; exit 1; }
for f in "$EGRESS_ROLLBACK" "$PERSIST_ROLLBACK"; do
  [ -x "$f" ] || { echo "ERROR: missing executable $f" >&2; exit 1; }
done

if [ -r /var/lib/vps-tier/kz-client-egress/state.env ]; then
  "$EGRESS_ROLLBACK"
fi
if [ -r /var/lib/vps-tier/kz-forwarding-persistence/state.env ]; then
  "$PERSIST_ROLLBACK"
fi

echo "DONE: Kazakhstan client-egress Stage 4 rollback complete"
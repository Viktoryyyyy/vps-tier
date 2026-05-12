#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

[ -d ".render" ] || { echo "ERROR: missing .render directory; run scripts/render.sh first" >&2; exit 1; }

if grep -R -n -E "\\{\\{[^}]+\\}\\}|__[A-Z0-9_]+__" ".render" >/tmp/vps-validate-placeholders.$$; then
  echo "ERROR: unresolved placeholders in .render" >&2
  sed -n "1,50p" /tmp/vps-validate-placeholders.$$ >&2
  rm -f /tmp/vps-validate-placeholders.$$
  exit 1
fi
rm -f /tmp/vps-validate-placeholders.$$

for f in .render/xray/*.json .render/xray/config.json; do
  [ -e "$f" ] || continue
  python3 -m json.tool "$f" >/dev/null
  echo "OK: json $f"
done

echo "DONE: repo-local validation completed"

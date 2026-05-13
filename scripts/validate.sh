#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

[ -d ".render" ] || { echo "ERROR: missing .render directory; run scripts/render.sh first" >&2; exit 1; }

if grep -R -n -E "\{\{[^}]+\}\}|__[A-Z0-9_]+__" ".render" >/tmp/vps-validate-placeholders.$$; then
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

[ -r .render/xray/config.json ] || { echo "ERROR: missing .render/xray/config.json" >&2; exit 1; }
python3 -c 'import json, sys
p = ".render/xray/config.json"
with open(p, "r", encoding="utf-8") as f:
    cfg = json.load(f)
inbounds = cfg.get("inbounds", [])
outbounds = cfg.get("outbounds", [])
if len(inbounds) != 1:
    raise SystemExit("ERROR: xray inbound_count expected 1 got " + str(len(inbounds)))
inbound = inbounds[0]
settings = inbound.get("settings", {})
clients = settings.get("clients", [])
stream = inbound.get("streamSettings", {})
reality = stream.get("realitySettings", {})
checks = [
    (inbound.get("port") == 443, "xray port must be 443"),
    (inbound.get("protocol") == "vless", "xray protocol must be vless"),
    (len(clients) == 2, "xray client_count must be 2"),
    (stream.get("network") == "tcp", "xray network must be tcp"),
    (stream.get("security") == "reality", "xray security must be reality"),
    (reality.get("dest") == "www.cloudflare.com:443", "xray reality dest mismatch"),
    (reality.get("serverNames") == ["www.cloudflare.com"], "xray reality serverNames mismatch"),
    (len(outbounds) == 1, "xray outbound_count must be 1"),
    (outbounds[0].get("protocol") == "freedom", "xray outbound protocol must be freedom"),
]
client_flow_indexes = [str(i) for i, client in enumerate(clients) if isinstance(client, dict) and "flow" in client]
if client_flow_indexes:
    raise SystemExit("ERROR: xray VLESS clients must not define client-level flow; indexes " + ",".join(client_flow_indexes))
for ok, msg in checks:
    if not ok:
        raise SystemExit("ERROR: " + msg)
print("OK: xray structural contract .render/xray/config.json")'

echo "DONE: repo-local validation completed"

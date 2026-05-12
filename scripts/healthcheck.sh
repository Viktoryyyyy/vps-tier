#!/usr/bin/env bash
set -euo pipefail

echo "UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "HOST: $(hostname)"

if command -v ss >/dev/null 2>&1; then
  echo "LISTENERS:"
  ss -lntp 2>/dev/null | awk "NR==1 || /:(22|80|443|8443)\b/" || true
else
  echo "WARN: ss not found"
fi

if command -v systemctl >/dev/null 2>&1; then
  for svc in xray nginx ssh sshd certbot hysteria-server hysteria2-server; do
    if systemctl list-unit-files "$svc.service" >/dev/null 2>&1 || systemctl status "$svc.service" >/dev/null 2>&1; then
      state="$(systemctl is-active "$svc.service" 2>/dev/null || true)"
      enabled="$(systemctl is-enabled "$svc.service" 2>/dev/null || true)"
      echo "SERVICE: $svc active=$state enabled=$enabled"
    fi
  done
else
  echo "WARN: systemctl not found"
fi

echo "DONE: read-only healthcheck completed"

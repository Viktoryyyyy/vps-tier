# Hysteria2 server configuration template
#
# Render target, later apply phase only:
#   .render/hysteria2/server.yaml -> /etc/hysteria/server.yaml
#
# This template is intentionally placeholder-only.
# Runtime values must come from /etc/vps-tier/runtime.env or another approved
# server-only secret source. Do not commit rendered secret-bearing output.

listen: ":${VPS_HYSTERIA2_PORT}"

# Authentication is server-only. The rendered password must never be committed,
# printed in logs, or included in observed evidence.
auth:
  type: "${VPS_HYSTERIA2_AUTH_MODE}"
  password: "${VPS_HYSTERIA2_AUTH_SECRET}"

# TLS material remains server-only. This design does not change certbot or nginx.
tls:
  cert: "${VPS_HYSTERIA2_CERT_PATH}"
  key: "${VPS_HYSTERIA2_KEY_PATH}"

# Optional obfuscation. Render/validate must fail closed if enabled=true and
# the password variable is absent. If disabled, render logic should omit this
# block rather than render an empty secret.
obfs:
  type: "salamander"
  salamander:
    password: "${VPS_HYSTERIA2_OBFS_PASSWORD}"

# Bandwidth hints are configuration values, not secrets.
bandwidth:
  up: "${VPS_HYSTERIA2_UP_Mbps} mbps"
  down: "${VPS_HYSTERIA2_DOWN_Mbps} mbps"

# Default masquerade target is documentation-only until validated against the
# selected Hysteria2 version during implementation. It must not point to local
# Xray/nginx/SSH services.
masquerade:
  type: "proxy"
  proxy:
    url: "${VPS_HYSTERIA2_MASQUERADE_URL}"
    rewriteHost: true

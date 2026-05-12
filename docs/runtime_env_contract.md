# Runtime Env Contract

Runtime values are server-only and loaded from /etc/vps-tier/runtime.env by scripts/render.sh.

Required Xray variables:
- XRAY_REALITY_PORT
- XRAY_CLIENT_UUID
- XRAY_CLIENT_LABEL
- XRAY_CLIENT_2_UUID
- XRAY_CLIENT_2_LABEL
- XRAY_REALITY_DEST_HOST
- XRAY_REALITY_DEST_PORT
- XRAY_REALITY_SERVER_NAME
- XRAY_REALITY_PRIVATE_KEY
- XRAY_REALITY_SHORT_ID

Required nginx variables:
- NGINX_SERVER_NAME
- NGINX_SSL_CERT_PATH
- NGINX_SSL_KEY_PATH

Rendered canonical semantics:
- Xray: one inbound, two clients, one freedom outbound, no blackhole outbound by default.
- nginx: renders both sub.conf and sub.stferry.com.conf.
- sub.conf intentionally has no server_name directive because observed live semantics for /etc/nginx/sites-enabled/sub do not define one.
- sub.stferry.com.conf retains explicit server_name placeholders.
- No subscription backend proxy is assumed by default.

Git must contain placeholders only. Do not commit real UUIDs, private keys, tokens, client links, certbot material, or rendered production configs.

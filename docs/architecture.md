# VPS Resilience Architecture

GitHub is the Source of Truth for desired state. The VPS server is applied runtime state only.

Canonical target layout:
- inventory/
- manifests/
- services/xray/
- services/nginx/
- services/hysteria2/
- services/ssh/
- services/firewall/
- runtime/templates/

Legacy/current-state paths retained but not canonical target layout:
- etc/
- opt/

This baseline does not generate production configs, install packages, change server runtime behavior, or add secrets.

Runtime render contract:
- Xray canonical rendered state models one VLESS Reality TCP inbound on tcp/443, two clients, Reality dest www.cloudflare.com:443, and one freedom outbound.
- nginx canonical rendered state models both active site configs: sub.conf and sub.stferry.com.conf.
- Rendered templates must not assume a subscription backend proxy unless live state and contract explicitly require it.

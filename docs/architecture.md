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

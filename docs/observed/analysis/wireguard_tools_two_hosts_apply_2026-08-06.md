# WireGuard Tools — Two-Host Apply Evidence

- Observation date: 2026-08-06
- Source Git HEAD: `f1ea38dedaba5e48ad2e015168b015be683be515`
- Runtime mutation scope: standard Ubuntu `wireguard-tools` package only
- Secrets recorded: no

## Moscow

```text
HOST_IPV4=147.45.184.140
ROLE=moscow
RESULT=success
EXEC_MAIN_STATUS=0
WIREGUARD_TOOLS_VERSION=1.0.20210914-1ubuntu4
WIREGUARD_MODULE_METADATA=present
WG_COMMAND=present
WG_QUICK_COMMAND=present
WIREGUARD_INTERFACE_CREATED=no
BACKBONE_ROUTE_CREATED=no
UDP_51820_CHANGED=no
FIREWALL_FORWARDING_ROUTES_CHANGED=no
STATE_FILE=/var/lib/vps-tier/wireguard-tools/moscow/state.env
BACKUP_SET=/var/backups/vps-tier/wireguard-tools/moscow/apply/20260806T154800Z
```

## Kazakhstan

```text
HOST_IPV4=194.32.142.88
ROLE=kazakhstan
RESULT=success
EXEC_MAIN_STATUS=0
WIREGUARD_TOOLS_VERSION=1.0.20210914-1ubuntu2
WIREGUARD_MODULE_METADATA=present
WG_COMMAND=present
WG_QUICK_COMMAND=present
WIREGUARD_INTERFACE_CREATED=no
BACKBONE_ROUTE_CREATED=no
UDP_51820_CHANGED=no
FIREWALL_FORWARDING_ROUTES_CHANGED=no
STATE_FILE=/var/lib/vps-tier/wireguard-tools/kazakhstan/state.env
BACKUP_SET=/var/backups/vps-tier/wireguard-tools/kazakhstan/apply/20260806T155051Z
```

## Result

```text
MOSCOW_TOOLCHAIN=ready
KAZAKHSTAN_TOOLCHAIN=ready
BACKBONE_RUNTIME=not_configured
NEXT_STAGE=Git_managed_standard_WireGuard_backbone
```

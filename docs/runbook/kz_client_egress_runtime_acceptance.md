# Kazakhstan Client Egress — Runtime Acceptance Checklist

After controlled apply, verify without printing private keys:

```text
wg-quick@wg-backbone=active_enabled
peer_allowed_ips_contains=10.70.0.1/32,10.71.0.0/24
route_10.71.0.0/24=dev_wg-backbone
ufw_marker=vps-tier-kz-client-egress-forward
snat_marker=vps-tier-kz-client-egress
snat_target=194.32.142.88
default_route=unchanged
ipv4_forward=1
ipv6_forward=0
backbone_ping=passed
backbone_handshake=present
protected_services=unchanged
end_to_end_client_egress=deferred
```

Do not claim end-to-end Internet egress until Moscow client termination and policy routing are present.

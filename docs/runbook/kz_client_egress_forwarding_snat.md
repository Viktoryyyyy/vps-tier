# Kazakhstan Client Egress Forwarding + SNAT

## Purpose

Prepares Kazakhstan to receive the approved client subnet `10.71.0.0/24` from Moscow over `wg-backbone` and send that traffic to the Internet with the Kazakhstan public IPv4 `194.32.142.88`.

This is Stage 4 of `contracts/two_hop_vpn/architecture_contract.md`.

## Observed Preconditions

Observed on Kazakhstan before implementation:

- `wg-backbone` is active and enabled at `10.70.0.2/30`;
- Moscow peer is `10.70.0.1/32`;
- `10.71.0.0/24` is absent from host addresses, routes, Docker networks, WireGuard AllowedIPs, UFW rules and NAT;
- Docker networks are `172.17.0.0/16`, `172.18.0.0/16`, and `172.19.0.0/16`;
- `net.ipv4.ip_forward=1` already in runtime;
- IPv6 forwarding remains `0` in runtime;
- no persistent `net.ipv4.ip_forward` assignment was observed in the checked sysctl sources;
- `rp_filter=2` on all, `enp3s0`, and `wg-backbone`;
- UFW is active and routed traffic defaults to deny;
- `ufw-before-forward` accepts `RELATED,ESTABLISHED` return traffic;
- existing NAT is Docker-only.

## Managed Changes

Stage 4 is executed through `scripts/apply_kz_client_egress_stage4.sh`, which composes two dependent changes.

First, `scripts/apply_kz_forwarding_persistence.sh`:

1. requires runtime IPv4 forwarding to already equal `1` and IPv6 forwarding to equal `0`;
2. fails closed if another persistent assignment for those keys already exists;
3. creates `/etc/sysctl.d/99-vps-tier-kz-client-egress.conf` with `net.ipv4.ip_forward=1` and `net.ipv6.conf.all.forwarding=0`;
4. applies only that file, so current runtime values remain unchanged while reboot persistence becomes explicit.

Second, `scripts/apply_kz_client_egress.sh`:

1. Extends the Moscow WireGuard peer AllowedIPs from `10.70.0.1/32` to `10.70.0.1/32, 10.71.0.0/24` in both runtime and `/etc/wireguard/wg-backbone.conf`.
2. Adds runtime return route `10.71.0.0/24 dev wg-backbone`; persistence comes from the WireGuard AllowedIPs configuration.
3. Adds one UFW routed allow from `10.71.0.0/24`, entering `wg-backbone`, exiting `enp3s0`.
4. Adds one explicit SNAT rule for `10.71.0.0/24` through `enp3s0` to `194.32.142.88`.
5. Adds `PostUp`/`PreDown` lines to the existing WireGuard config so the owned SNAT rule follows the backbone lifecycle.

No default route, DNS, Docker, Nginx, Xray, Hysteria2, n8n, Flowise, cloudflared, or SSH configuration is changed. IPv4 and IPv6 forwarding runtime values are preserved at `1` and `0`; Stage 4 adds only their explicit persistence.

## Safety Gates

Stage 4 stops before mutation unless:

- exact Kazakhstan host identity and Ubuntu Jammy are confirmed;
- the managed backbone state exists and `wg-quick@wg-backbone` is active/enabled;
- the current WireGuard config is still at the approved Stage-3 baseline;
- the complete runtime AllowedIPs set matches the approved baseline exactly;
- the client subnet has no overlap with current addresses, routes, or Docker networks;
- IPv4 forwarding is already `1` and IPv6 forwarding is `0`;
- no competing persistent forwarding assignment exists;
- rp_filter remains loose (`2`);
- UFW is active and its established-return rule is present;
- required protected services are active.

The client-egress apply captures the existing WireGuard config, NAT table, UFW status, default route, and protected-unit state before mutation. Any failure after mutation begins invokes task-owned rollback. The Stage-4 orchestrator also removes the forwarding-persistence file when the dependent egress apply fails.

## Persistence

The forwarding state is explicit in `/etc/sysctl.d/99-vps-tier-kz-client-egress.conf`:

```text
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 0
```

The client return route is reconstructed by `wg-quick` from the peer AllowedIPs on backbone startup.

The SNAT rule is reconstructed by the managed `PostUp` command and removed by the managed `PreDown` command. Both commands operate only on the exact rule carrying comment `vps-tier-kz-client-egress`.

The UFW routed allow persists through UFW's managed rule store.

## Apply Sequence

After the implementation PR is merged:

1. synchronize the Moscow working copy to the exact merged `main`;
2. copy the Stage-4 orchestrator, its rollback, both forwarding-persistence scripts, and both client-egress scripts to Kazakhstan `/tmp`;
3. verify transferred SHA-256 hashes against the exact merged Git files;
4. launch `apply_kz_client_egress_stage4.sh` through a detached transient systemd unit with `VPS_TIER_SOURCE_HEAD` equal to the merged Git SHA;
5. inspect unit result, journal, both managed states, sysctl persistence, route, WireGuard AllowedIPs, UFW rule and SNAT rule;
6. verify the Moscow↔Kazakhstan backbone still pings and handshakes;
7. record post-apply evidence in Git.

End-to-end Internet egress from `10.71.0.0/24` is intentionally deferred until Moscow client termination/policy routing exists.

## Rollback

Use `scripts/rollback_kz_client_egress_stage4.sh` on Kazakhstan.

Rollback first removes the task-owned client route, peer AllowedIPs extension, UFW routed allow and SNAT state, then removes the Stage-4 sysctl persistence file and restores the pre-apply runtime forwarding values. The client-egress rollback is fail-closed if the managed WireGuard config has diverged.

## Acceptance

Stage 4 is accepted when:

```text
KZ_CLIENT_SUBNET_ALLOWED_FROM_MOSCOW=yes
KZ_RETURN_ROUTE=10.71.0.0/24_via_wg-backbone
KZ_UFW_FORWARD=managed
KZ_SNAT=194.32.142.88
KZ_IPV4_FORWARDING=1_unchanged_and_persistent
KZ_IPV6_FORWARDING=0_unchanged_and_persistent
KZ_DEFAULT_ROUTE=unchanged
BACKBONE=healthy
PROTECTED_SERVICES=unchanged
END_TO_END_CLIENT_EGRESS=deferred
SECRETS_IN_GIT=none
```

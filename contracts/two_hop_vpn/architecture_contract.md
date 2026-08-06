# Two-Hop VPN Architecture Contract

## Status And Scope

This file defines the desired-state architecture for the client path:

```text
client -> Moscow VPN termination -> Moscow/Kazakhstan backbone -> Kazakhstan NAT -> Internet
```

Observed runtime facts are recorded separately in:

```text
docs/observed/analysis/two_hop_vpn_inventory_2026-08-06.md
```

This contract authorizes no runtime mutation by itself. Every implementation stage requires a separate reviewed Git change, explicit apply authorization, rollback procedure, and post-apply evidence.

## Architecture Boundaries

```text
CLIENT_INGRESS_HOST=Moscow
CLIENT_INGRESS_PROTOCOL=UDP
PREFERRED_CLIENT_PORT=443
BACKBONE=Moscow_to_Kazakhstan
EGRESS_HOST=Kazakhstan
DNS_PATH=through_Kazakhstan
IPV6_INITIAL_POLICY=fail_closed
MOSCOW_EGRESS_FALLBACK=forbidden
```

Required behavior:

- the access network sees the Moscow public endpoint only;
- the client VPN session terminates on Moscow;
- Moscow forwards client traffic only through the dedicated Kazakhstan backbone;
- Kazakhstan performs Internet egress and source NAT;
- public Internet services see the Kazakhstan egress address;
- client DNS follows the Kazakhstan path;
- no client traffic may fall back to Moscow public egress when the backbone is unavailable.

## Address Plan

Candidate values reserved for implementation planning:

```text
CLIENT_IPV4_SUBNET=10.71.0.0/24
BACKBONE_IPV4_SUBNET=10.70.0.0/30
MOSCOW_BACKBONE_IPV4=10.70.0.1
KAZAKHSTAN_BACKBONE_IPV4=10.70.0.2
```

These values are not runtime-approved until an implementation PR proves that they do not overlap host, Docker, provider, VPN, or application networks.

## Technology Boundaries

Server-to-server backbone:

```text
PREFERRED_BACKBONE_TECHNOLOGY=WireGuard
DEFAULT_ROUTE_CHANGE=forbidden
BACKBONE_SCOPE=only_contract_subnets_and_required_control_traffic
```

Client ingress:

```text
CLIENT_TERMINATION_REQUIRED=yes
CLIENT_TECHNOLOGY_SELECTION=pending_current_version_validation
PREFERRED_TRANSPORT=udp/443
```

The client technology must be selected in a separate design/implementation PR after current Ubuntu and iOS support is verified. The selection must not weaken the fail-closed, egress, DNS, or secret-handling requirements in this contract.

## Routing And Fail-Closed Contract

- Moscow must not use its normal Internet default route as fallback for the client subnet.
- Policy routing must direct the client subnet to the Kazakhstan backbone only.
- Backbone loss must make client Internet access fail closed.
- Initial implementation is IPv4-only.
- IPv6 forwarding for the client path remains disabled unless a later contract explicitly defines an end-to-end IPv6 path.
- Client-side and server-side controls must prevent unmanaged IPv6 escape.
- Neither host default route may be replaced during backbone-only stages.

## Firewall And NAT Contract

Moscow:

- allow only the approved client-ingress UDP port;
- allow only the approved backbone UDP port and peer;
- permit forwarding only between the client and backbone interfaces for the approved client subnet;
- do not SNAT client traffic to the Moscow public interface;
- preserve existing SSH, Nginx, PostgreSQL, MOEX Bot, Flowise compatibility, Mosh, and backup-relay behavior during backbone-only stages.

Kazakhstan:

- allow only the approved backbone UDP port and Moscow peer;
- permit forwarding only from the approved client subnet through the backbone;
- perform controlled SNAT/MASQUERADE through `enp3s0` for the approved client subnet;
- preserve Xray, Hysteria2, Nginx, Docker, n8n, Flowise, and cloudflared behavior.

Firewall and NAT changes must be explicit managed files or scripts in Git. Ad hoc server rules are forbidden.

## Application Access Boundary

Public application access is independent of the client VPN:

- `flowise.foods-tech.store` remains on its existing Cloudflare route;
- n8n public publication is a separate Cloudflare Tunnel task;
- the Moscow `flowise-api` compatibility route is not removed by VPN implementation;
- compatibility-route decommission requires separate dependency verification and a separate Git-managed task;
- the client VPN must not become a prerequisite for public n8n or Flowise availability.

## Protected Runtime Scope

Backbone-only stages must not modify or restart:

```text
ssh
nginx
postgresql
moex bot services and timers
xray
hysteria2
n8n containers
flowise containers
cloudflared
docker networking
vps-backup-relay
flowise compatibility proxy
```

A later stage may change only the explicitly approved VPN, forwarding, routing, firewall, and NAT components for that stage.

## Secret Contract

The following must remain outside Git, PR text, logs, and observed evidence:

- private keys;
- preshared keys;
- complete client profiles and QR payloads;
- Cloudflare tokens;
- UUIDs and credential-bearing URLs;
- authentication secrets.

Git may contain placeholders, public keys where operationally required, fingerprints, presence flags, hashes, and non-secret validation evidence.

## Staged Delivery Contract

Implementation order:

1. Validate current supported client-ingress technology and package sources.
2. Add the server-to-server backbone without changing default routes.
3. Prove backbone reachability, persistence, and rollback.
4. Add Kazakhstan forwarding and NAT for the approved client subnet.
5. Add Moscow client termination on the approved UDP port.
6. Add Moscow policy routing and fail-closed controls.
7. Generate the iPhone client profile outside Git.
8. Prove egress IP, DNS path, IPv6 fail-closed behavior, protected-service availability, and rollback.
9. Consider raw-relay retirement only in a later cleanup task.

Each stage is a separate reviewed route unless a later task contract explicitly combines them.

## Acceptance Criteria

Final acceptance requires all of the following:

```text
CLIENT_CONNECTS_TO=Moscow
CLIENT_PUBLIC_EGRESS=Kazakhstan
DNS_EGRESS=Kazakhstan_path
MOSCOW_FALLBACK_ON_BACKBONE_LOSS=blocked
IPV6_ESCAPE=blocked
PROTECTED_SERVICES=unchanged_and_healthy
PRIVATE_MATERIAL_IN_GIT=none
ROLLBACK=proven
POST_APPLY_EVIDENCE=committed
```

## Separate Tasks

The following are outside this architecture implementation and must not be bundled into VPN stages:

- PostgreSQL public-exposure remediation;
- Zabbix public-exposure remediation;
- Moscow reboot maintenance;
- MOEX futures refresh remediation;
- Flowise compatibility proxy decommission;
- n8n Cloudflare Tunnel publication;
- raw relay decommission.

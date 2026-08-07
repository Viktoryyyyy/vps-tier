# Moscow AmneziaWG Client Termination — Stage 5 Contract

## Scope

This contract implements Stage 5 of the two-hop VPN architecture: create the iPhone-facing AmneziaWG 2 termination on Moscow without yet enabling routed client traffic.

```text
HOST=Moscow
PUBLIC_IPV4=147.45.184.140
INTERFACE=awg-client
SERVER_IPV4=10.71.0.1/24
CLIENT_IPV4=10.71.0.2/32
TRANSPORT=udp/443
MTU=1280
CLIENT_TECHNOLOGY=AmneziaWG_2
```

## Required State

Stage 5 must:

- create one managed AmneziaWG interface `awg-client`;
- assign only `10.71.0.1/24` to that interface;
- listen on Moscow IPv4 UDP/443;
- create one managed UFW IPv4 ingress allow for UDP/443;
- create one server key pair and one first-client key pair at runtime only;
- configure the first client peer as `10.71.0.2/32`;
- generate AWG obfuscation parameters at runtime and store them only in protected server-local state;
- enable persistent startup through `awg-quick@awg-client.service`;
- preserve the standard WireGuard backbone;
- preserve the Moscow default route;
- preserve IPv4 forwarding at `0`;
- preserve IPv6 forwarding at `0`;
- leave client Internet forwarding, policy routing, DNS and egress validation for later stages.

## Secret Boundary

The following are runtime-only secret or profile-bearing material and must never appear in Git, PR text, shell output, journals, or observed evidence:

- AWG server private key;
- AWG client private key;
- any preshared key if introduced later;
- complete client configuration;
- QR payloads.

The selected AWG obfuscation parameter set is also kept server-local because it forms part of the future client profile, even though those values are not cryptographic private keys.

Public keys may be stored server-locally but are not required in Git evidence.

## Runtime Material Layout

Approved runtime paths:

```text
CONFIG=/etc/amnezia/amneziawg/awg-client.conf
MATERIAL_DIR=/etc/amnezia/amneziawg/vps-tier/awg-client
SERVER_PRIVATE_KEY=<material_dir>/server.key
SERVER_PUBLIC_KEY=<material_dir>/server.pub
CLIENT_PRIVATE_KEY=<material_dir>/iphone.key
CLIENT_PUBLIC_KEY=<material_dir>/iphone.pub
AWG_PARAMETERS=<material_dir>/params.env
STATE=/var/lib/vps-tier/moscow-awg-client-termination/state.env
EVIDENCE=/var/lib/vps-tier/moscow-awg-client-termination/evidence.md
```

Private/profile-bearing files must be root-owned and mode `0600`; their containing directories must be mode `0700`.

## AWG Parameter Contract

Stage 5 uses the compatibility-oriented parameter set supported by the current official Linux and iOS AWG 2 implementations:

```text
Jc
Jmin
Jmax
S1
S2
H1
H2
H3
H4
```

Generation constraints:

- `Jc`: random integer 4–12;
- `Jmin=8`;
- `Jmax=80`;
- `S1`: random integer 15–150;
- `S2`: random integer 15–150 and `S1 + 56 != S2`;
- `H1`–`H4`: four distinct random integers in 5–2147483647.

The same generated S1/S2/H1–H4 values are later used in the iPhone profile. Stage 5 deliberately omits `I1`–`I5` because current upstream tooling has unresolved empty-value compatibility issues and they are not required for this compatibility profile.

## Firewall Boundary

The only authorized Stage-5 firewall mutation is one IPv4 ingress allow:

```text
protocol=udp
port=443
destination=147.45.184.140
owner_comment=vps-tier-awg-client-ingress
```

No routed UFW rule is authorized in Stage 5.

## Routing Boundary

The interface-connected client subnet route created by assigning `10.71.0.1/24` is expected.

Stage 5 must not:

- enable `net.ipv4.ip_forward`;
- create a client-to-backbone forward rule;
- extend the Moscow standard-WireGuard peer to Internet prefixes;
- add a source-policy rule or dedicated routing table;
- add Moscow SNAT/MASQUERADE;
- replace or modify the Moscow default route.

Therefore a client may complete an AWG handshake after its profile is installed, but it must not obtain routed Internet access until Stage 6 is applied.

## Persistence Boundary

Persistence uses the package-managed `awg-quick@.service` template and `/etc/amnezia/amneziawg/awg-client.conf`.

The implementation must fail before mutation if `awg-quick`, its systemd template, or the expected AmneziaWG configuration directory is unavailable.

## Protected Runtime Scope

Stage 5 must preserve:

```text
ssh.socket
nginx.service
postgresql.service
flowise-proxy.service
vps-backup-relay.socket
wg-quick@wg-backbone.service
```

It must not modify Nginx TCP/443, PostgreSQL, MOEX Bot, Flowise proxy, relay, Kazakhstan, Docker, DNS, or unrelated services.

## Rollback

Rollback must remove only task-owned Stage-5 state:

- disable/stop `awg-quick@awg-client.service`;
- remove `awg-client` if still present;
- remove the task-owned UFW UDP/443 rule;
- remove the task-owned AWG config and runtime key/parameter directory;
- remove managed state after proving cleanup;
- preserve AWG packages/toolchain and the standard WireGuard backbone.

Rollback must remain usable when the AWG unit failed to start or is already inactive.

## Acceptance

```text
AWG_INTERFACE=active_enabled
AWG_ADDRESS=10.71.0.1/24
AWG_LISTEN_PORT=443
CLIENT_PEER=10.71.0.2/32
AWG_UFW_UDP443=present_managed
SERVER_AND_CLIENT_KEYS=runtime_only
AWG_PARAMETERS=runtime_only
DEFAULT_ROUTE_CHANGE=none
IPV4_FORWARDING=0_unchanged
IPV6_FORWARDING=0_unchanged
MOSCOW_NAT_CHANGE=none
BACKBONE=healthy
PROTECTED_SERVICES=unchanged
CLIENT_HANDSHAKE=deferred_until_profile
CLIENT_INTERNET_EGRESS=blocked_by_stage_boundary
SECRETS_IN_GIT=none
```

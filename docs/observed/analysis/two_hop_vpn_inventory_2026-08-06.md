# Two-Hop VPN — Observed Inventory

- Observation date: 2026-08-06
- Repository base SHA: `8179a8daf90c4a9ba774486fe17593a75b6f520c`
- Moscow public IPv4: `147.45.184.140`
- Kazakhstan public IPv4: `194.32.142.88`
- Runtime mutation in this task: none
- Secrets recorded: none

## Objective

Provide a client path where the access network sees only the Moscow VPS and public Internet services see Kazakhstan as the egress location:

```text
client -> Moscow VPN termination -> Moscow/Kazakhstan backbone -> Kazakhstan NAT -> Internet
```

The existing raw TCP relay was retained during observation but is not considered a sufficient final architecture because it does not terminate and re-originate the client session on Moscow.

## Existing Relay Evidence

Current Moscow relay path:

```text
client -> 147.45.184.140:8443/tcp -> 194.32.142.88:443/tcp
```

Implementation: `systemd-socket-proxyd`.

Observed:

- `vps-backup-relay.socket` active and enabled;
- Moscow listens on `tcp/8443`;
- Kazakhstan `tcp/443` is reachable from Moscow;
- synthetic Xray traffic through the relay succeeded;
- client authentication over the tested access network did not provide a reliable usable path;
- direct Kazakhstan traffic was independently observed to be cut by the access provider.

Conclusion: the target design must terminate the client VPN on Moscow and use a separate server-to-server tunnel to Kazakhstan.

## Moscow Host

```text
PUBLIC_IPV4=147.45.184.140
PRIMARY_INTERFACE=eth0
OS=Ubuntu 24.04.3 LTS
ROOT_DISK_SIZE=15G
ROOT_DISK_USED_AFTER_CLEANUP=75%
ROOT_DISK_AVAILABLE_AFTER_CLEANUP=3.8G
REBOOT_REQUIRED=yes
IPV4_FORWARDING=0
IPV6_FORWARDING=0
RP_FILTER=2
WIREGUARD_TOOLS=absent
UDP_443=free
```

System journal cleanup completed before this inventory:

```text
JOURNAL_BEFORE=1.4G
JOURNAL_AFTER=494.8M
DISK_USED_BEFORE=82%
DISK_USED_AFTER=75%
```

Relevant listeners and services:

- SSH: `tcp/22`, activated through `ssh.socket`;
- Nginx: `tcp/80`, `tcp/443`, local `tcp/8082`;
- backup relay: `tcp/8443`;
- PostgreSQL: `tcp/5432` on public interfaces;
- Zabbix agent: `tcp/10050` on a public interface;
- Flowise compatibility proxy: local `tcp/8081` and Nginx local `tcp/8082`;
- Mosh: UDP range `60000:61000`.

Relevant units:

```text
ssh.socket=active,enabled
nginx.service=active,enabled
vps-backup-relay.socket=active,enabled
flowise-proxy.service=active,enabled
postgresql.service=active,enabled
```

One unrelated failed unit was observed:

```text
moex-futures-daily-refresh.service
blocker=registry_refresh:component_returncode_nonzero
```

It is outside the VPN scope and was not changed.

### Moscow Firewall

UFW is active:

```text
DEFAULT_INCOMING=deny
DEFAULT_OUTGOING=allow
DEFAULT_ROUTED=disabled
FORWARD_POLICY=DROP
NAT_RULES=none
```

Existing allows include SSH, Mosh, `tcp/5432`, `tcp/80`, `tcp/443`, and `tcp/8443`.

Implication: the future design requires explicit IPv4 forwarding, routed UFW rules, and controlled forwarding between client and backbone interfaces. No firewall change was made during this inventory.

## Kazakhstan Host

```text
PUBLIC_IPV4=194.32.142.88
PRIMARY_INTERFACE=enp3s0
ROOT_DISK_SIZE=40G
ROOT_DISK_USED=55%
ROOT_DISK_AVAILABLE=18G
REBOOT_REQUIRED=no
IPV4_FORWARDING=1
IPV6_FORWARDING=0
RP_FILTER=2
WIREGUARD_TOOLS=absent
```

Relevant listeners and services:

- Xray Reality: `tcp/443`;
- Hysteria2: `udp/8443`;
- Nginx: `tcp/80`, `tcp/8443`;
- n8n Docker binding: `127.0.0.1:5678`;
- Flowise Docker binding: `127.0.0.1:3000`;
- cloudflared active with local management listener.

Containers:

```text
n8n-n8n-1=docker.n8n.io/n8nio/n8n:stable
flowiseai-flowise-1=flowiseai/flowise:latest
```

Docker networks observed:

```text
172.18.0.0/16
172.19.0.0/16
```

### Kazakhstan Firewall And NAT

UFW is active with incoming deny and routed deny. Existing allows include:

- `tcp/22`;
- `tcp/80`;
- `tcp/443`;
- `tcp/8443`;
- `udp/8443`.

The FORWARD policy is DROP. Existing NAT is limited to Docker subnet masquerading.

Implication: the future backbone requires an explicit WireGuard UDP listener, forward rules for the VPN client subnet, and controlled SNAT/MASQUERADE through `enp3s0`.

## Application Access

Observed Nginx routes on Kazakhstan:

```text
flowise.foods-tech.store -> 127.0.0.1:3000
flowise-api.foods-tech.store:8443 -> 127.0.0.1:3000
n8n.foods-tech.store -> 127.0.0.1:5678
```

Health checks:

```text
n8n /healthz=HTTP 200
Flowise /=HTTP 200
```

Public route observations:

- `flowise.foods-tech.store` resolves through Cloudflare and returns HTTPS 200;
- `flowise-api.foods-tech.store` resolves directly to Moscow and returns HTTPS 200 through the compatibility route;
- `n8n.foods-tech.store` did not have a working public DNS route during observation.

Moscow compatibility route:

```text
flowise-api.foods-tech.store /github-task -> 127.0.0.1:8081/github-task
other requests -> https://194.32.142.88:8443
```

The compatibility route is classified as legacy. It must not be removed as part of the VPN implementation. Decommission requires a separate Git-managed task after dependency verification.

Target application-access direction:

- retain `flowise.foods-tech.store` through Cloudflare;
- publish n8n through a distinct Cloudflare Tunnel hostname;
- retire the Moscow Flowise compatibility route in a separate task;
- do not make public n8n or Flowise availability depend on the client VPN.

## Target Architecture Constraints

The architecture contract must preserve these boundaries:

```text
CLIENT_INGRESS_HOST=Moscow
CLIENT_INGRESS_PROTOCOL=UDP
PREFERRED_CLIENT_PORT=443
BACKBONE=Moscow_to_Kazakhstan
EGRESS_HOST=Kazakhstan
CLIENT_IPV4_SUBNET=10.71.0.0/24_candidate
BACKBONE_IPV4_SUBNET=10.70.0.0/30_candidate
MOSCOW_BACKBONE_IPV4=10.70.0.1_candidate
KAZAKHSTAN_BACKBONE_IPV4=10.70.0.2_candidate
DNS_PATH=through_Kazakhstan
IPV6_INITIAL_POLICY=fail_closed
MOSCOW_EGRESS_FALLBACK=forbidden
```

Candidate implementation sequence:

1. Add server-to-server WireGuard backbone without changing either host's default route.
2. Validate backbone reachability and persistence.
3. Add Kazakhstan forwarding and NAT for the future client subnet.
4. Add Moscow client VPN termination on `udp/443`.
5. Add policy routing so client traffic can use only the Kazakhstan backbone.
6. Generate the iPhone client profile without committing private keys.
7. Prove public egress IP, DNS path, IPv6 fail-closed behavior, application availability, and rollback.
8. Retire the raw relay only in a later cleanup task.

## Fail-Closed Requirements

- Client traffic must not fall back to Moscow public egress when the backbone is unavailable.
- IPv6 must not escape outside the managed path during the initial IPv4-only implementation.
- SSH, Nginx, PostgreSQL, MOEX Bot, Xray, Hysteria2, n8n, Flowise, Docker networking, and the existing relay must remain unchanged during backbone-only stages.
- Private keys, preshared keys, client profiles, Cloudflare tokens, UUIDs, and credential-bearing URLs must remain outside Git and evidence output.
- Every runtime apply must have an explicit backup set, rollback procedure, and post-apply evidence.

## Separate Findings Outside Current Scope

The following require separate security or maintenance tasks and must not be bundled with the VPN implementation:

- public exposure of PostgreSQL on `tcp/5432`;
- public exposure of Zabbix agent on `tcp/10050`;
- pending Moscow reboot requirement;
- repeated MOEX futures refresh failure;
- Flowise compatibility proxy decommission;
- n8n Cloudflare Tunnel publication;
- raw relay decommission.

## Inventory Verdict

```text
OBSERVED_INVENTORY=complete
RUNTIME_MUTATION=none
TARGET_ARCHITECTURE=client_termination_on_Moscow_plus_dedicated_backbone
BACKBONE_IMPLEMENTATION_STATUS=not_started
CLIENT_INGRESS_IMPLEMENTATION_STATUS=not_started
APPLICATION_ACCESS_CHANGES=not_started
```

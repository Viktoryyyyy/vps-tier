# Two-Hop VPN — Observed Inventory

- Observation date: 2026-08-06
- Repository base SHA: `8179a8daf90c4a9ba774486fe17593a75b6f520c`
- Moscow public IPv4: `147.45.184.140`
- Kazakhstan public IPv4: `194.32.142.88`
- Runtime mutation in this task: none
- Secrets recorded: none

This file records informational observed state only. Desired-state architecture and mandatory implementation boundaries are defined in:

```text
contracts/two_hop_vpn/architecture_contract.md
```

## Investigation Context

The required user outcome was a path where the access network reaches Moscow while Internet traffic exits through Kazakhstan:

```text
client -> Moscow -> Kazakhstan -> Internet
```

The investigation compared that requirement with the existing raw TCP relay and current host/network state. No VPN, routing, forwarding, NAT, firewall, DNS, or application configuration was changed.

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

Investigation finding: the raw relay did not provide a reliable client path on the tested access network. The resulting desired-state decision is maintained in the architecture contract, not in this observed file.

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

The unit was not changed during this inventory.

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

Analysis finding: any routed client-to-backbone implementation would require explicit IPv4 forwarding and routed firewall rules. No firewall or forwarding change was made during this inventory.

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
- cloudflared active with a local management listener.

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

Analysis finding: a future routed backbone would require an explicit UDP listener, forward rules for its approved client subnet, and controlled source NAT through `enp3s0`. No firewall, forwarding, or NAT change was made during this inventory.

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

- `flowise.foods-tech.store` resolved through Cloudflare and returned HTTPS 200;
- `flowise-api.foods-tech.store` resolved directly to Moscow and returned HTTPS 200 through the compatibility route;
- `n8n.foods-tech.store` did not have a working public DNS route during observation.

Moscow compatibility route:

```text
flowise-api.foods-tech.store /github-task -> 127.0.0.1:8081/github-task
other requests -> https://194.32.142.88:8443
```

The route was identified as a legacy compatibility dependency. It remained active and unchanged during the inventory. Desired-state preservation and decommission boundaries are defined in the architecture contract.

## Additional Observed Findings

The following conditions were observed but not changed:

- PostgreSQL exposed on `tcp/5432`;
- Zabbix agent exposed on `tcp/10050`;
- Moscow restart requirement pending;
- repeated MOEX futures refresh failure;
- Flowise compatibility proxy still active;
- n8n public DNS route absent;
- raw relay still active.

These findings do not authorize remediation in this task.

## Desired-State Reference

Authoritative architecture, fail-closed behavior, protected-service scope, address candidates, secret handling, staged delivery, and acceptance criteria are defined in:

```text
contracts/two_hop_vpn/architecture_contract.md
```

## Inventory Verdict

```text
OBSERVED_INVENTORY=complete
RUNTIME_MUTATION=none
RAW_RELAY_TESTED=yes
RAW_RELAY_RELIABLE_FOR_TESTED_CLIENT_PATH=no
BACKBONE_IMPLEMENTATION_STATUS=not_started
CLIENT_INGRESS_IMPLEMENTATION_STATUS=not_started
APPLICATION_ACCESS_CHANGES=not_started
DESIRED_STATE_SOURCE=contracts/two_hop_vpn/architecture_contract.md
```

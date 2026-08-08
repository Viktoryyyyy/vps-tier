# Two-Hop VPN Master Operations Handover

## Purpose

This is the primary handover document for the working two-hop VPN deployed across the Moscow and Kazakhstan VPS hosts.

Read this file first when taking over the system. It explains the topology, routing, fail-closed behavior, current client allocations, runtime paths, profile-generation rules, device onboarding, verification, troubleshooting, and rollback ownership.

This document is descriptive and operational. GitHub remains the source of truth. It does not authorize ad hoc server changes.

## 1. Architecture At A Glance

```text
Phone / Windows / TV
        |
        | AmneziaWG 2, UDP/443
        v
Moscow VPS
public: 147.45.184.140
awg-client: 10.71.0.1/24
        |
        | source policy routing only
        v
wg-backbone
Moscow: 10.70.0.1/30
        |
        | standard WireGuard, UDP/51820
        v
Kazakhstan VPS
public: 194.32.142.88
wg-backbone: 10.70.0.2/30
        |
        | IPv4 forwarding + SNAT
        v
Internet
public IPv4 seen by destinations: 194.32.142.88
```

Security properties:

```text
CLIENT_CONNECTS_TO=Moscow
CLIENT_PUBLIC_EGRESS=Kazakhstan
MOSCOW_PUBLIC_EGRESS_FALLBACK=forbidden
MOSCOW_CLIENT_SNAT=none
KAZAKHSTAN_CLIENT_SNAT=required
DNS=inside_full_tunnel
IPV6_POLICY=fail_closed
```

The access ISP sees a VPN connection to Moscow. Internet destinations should see the Kazakhstan public IPv4.

## 2. Host Roles

### Moscow VPS

```text
public_ipv4=147.45.184.140
client_vpn_interface=awg-client
client_vpn_protocol=AmneziaWG 2
client_vpn_port=443/udp
client_vpn_subnet=10.71.0.0/24
client_vpn_server_address=10.71.0.1/24
backbone_interface=wg-backbone
backbone_address=10.70.0.1/30
backbone_protocol=standard WireGuard
backbone_port=51820/udp
public_interface=eth0
```

Responsibilities:

- terminate AmneziaWG sessions from user devices;
- assign one unique keypair and one unique `/32` to each device;
- source-policy-route `10.71.0.0/24` only to Kazakhstan;
- explicitly deny client forwarding to Moscow `eth0`;
- perform no SNAT for the client subnet;
- keep IPv6 forwarding disabled.

TCP/443 used by Nginx is independent from UDP/443 used by AmneziaWG.

### Kazakhstan VPS

```text
public_ipv4=194.32.142.88
backbone_interface=wg-backbone
backbone_address=10.70.0.2/30
public_interface=enp3s0
client_subnet=10.71.0.0/24
client_public_snat=194.32.142.88
```

Responsibilities:

- accept the client subnet from the Moscow WireGuard peer;
- forward client IPv4 traffic from `wg-backbone` to `enp3s0`;
- SNAT `10.71.0.0/24` to `194.32.142.88`;
- return client traffic through `wg-backbone`;
- keep IPv6 forwarding disabled;
- preserve unrelated production services such as n8n, Flowise, Xray, Hysteria2, Nginx, Docker and cloudflared.

## 3. Address Plan

### Infrastructure

```text
10.70.0.0/30   Moscow-Kazakhstan backbone
10.70.0.1/30   Moscow wg-backbone
10.70.0.2/30   Kazakhstan wg-backbone

10.71.0.0/24   AmneziaWG client subnet
10.71.0.1/24   Moscow awg-client server
```

### Current clients

```text
10.71.0.2/32   iPhone
10.71.0.3/32   Windows
10.71.0.4/32   Sber TV / SberBox
```

Rendered profile fingerprints:

```text
iPhone  sha256=bd69cc20bb39e44cabc052e0bea2b5dd209c8142744f2d48da8745b4f895ba7c
Windows sha256=b1ba3e7262ab090836d61f4416ed3599aa30b24e4e036e2d78c85d646a4909c7
Sber TV sha256=5bffddfc7c27e653c7660bbc09759f37946a7d31a0279338b66f585ae2c14eef
```

The next candidate is `10.71.0.5/32`, but always inspect live and persistent peer state before allocating it.

Never reuse one client profile on two simultaneously active devices. Reusing a private key and `/32` causes peer endpoint/handshake conflicts.

## 4. Packet Flow

For a packet from iPhone `10.71.0.2`:

1. The device sends an AmneziaWG-encrypted datagram to `147.45.184.140:443/udp`.
2. Moscow decrypts it on `awg-client`.
3. Policy rule priority `10710` matches source `10.71.0.0/24` and selects routing table `1071`.
4. Table `1071` sends it only to `wg-backbone`.
5. Standard WireGuard carries it from Moscow `10.70.0.1` to Kazakhstan `10.70.0.2`.
6. Kazakhstan forwards the original client packet to `enp3s0`.
7. Kazakhstan SNAT changes the source to `194.32.142.88`.
8. Return traffic is de-NATed on Kazakhstan and routed back through the backbone and Moscow AWG tunnel.

Windows and TV use the same path with sources `10.71.0.3` and `10.71.0.4`.

Current client DNS is `1.1.1.1`. Because profiles use `AllowedIPs = 0.0.0.0/0, ::/0`, DNS is carried through the VPN path rather than sent directly by the client.

## 5. Moscow Fail-Closed Routing

The client subnet must never fall back to Moscow public Internet if Kazakhstan is unavailable.

### Source policy rule

```text
priority=10710
from=10.71.0.0/24
lookup=1071
```

### Dedicated table 1071

Healthy state:

```text
default dev wg-backbone metric 10
prohibit default metric 32760
```

When the backbone disappears, the usable default disappears but `prohibit default` remains.

### UFW forwarding boundary

```text
DENY  awg-client -> eth0        from 10.71.0.0/24
ALLOW awg-client -> wg-backbone from 10.71.0.0/24
```

There is no authorized Moscow SNAT/MASQUERADE for `10.71.0.0/24`.

### Forwarding persistence

```text
/etc/sysctl.d/99-vps-tier-moscow-client-routing.conf
```

Expected values:

```text
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=0
```

### Boot barrier

The managed AWG systemd drop-in requires the fail-closed policy service to be active before AWG startup is accepted.

Relevant services:

```text
awg-quick@awg-client.service
wg-quick@wg-backbone.service
vps-tier-moscow-client-policy.service
ufw.service
```

## 6. Kazakhstan Egress

Expected managed state:

```text
10.71.0.0/24 route -> wg-backbone
UFW routed allow: wg-backbone -> enp3s0 for 10.71.0.0/24
SNAT: 10.71.0.0/24 out enp3s0 -> 194.32.142.88
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=0
```

Persistent forwarding file:

```text
/etc/sysctl.d/99-vps-tier-kz-client-egress.conf
```

The managed SNAT rule is identifiable by:

```text
vps-tier-kz-client-egress
```

Kazakhstan's Moscow WireGuard peer includes `10.71.0.0/24` in AllowedIPs so return routing follows the backbone.

## 7. Managed Runtime Paths

### Moscow backbone

```text
/etc/wireguard/wg-backbone.conf
/etc/wireguard/vps-tier/backbone.key
/etc/wireguard/vps-tier/backbone.pub
```

### Moscow AmneziaWG server

```text
/etc/amnezia/amneziawg/awg-client.conf
/etc/amnezia/amneziawg/vps-tier/awg-client/server.key
/etc/amnezia/amneziawg/vps-tier/awg-client/server.pub
/etc/amnezia/amneziawg/vps-tier/awg-client/params.env
```

### iPhone key material

```text
/etc/amnezia/amneziawg/vps-tier/awg-client/iphone.key
/etc/amnezia/amneziawg/vps-tier/awg-client/iphone.pub
```

### Windows and TV key material

```text
/etc/amnezia/amneziawg/vps-tier/awg-client/additional-clients/windows.key
/etc/amnezia/amneziawg/vps-tier/awg-client/additional-clients/windows.pub
/etc/amnezia/amneziawg/vps-tier/awg-client/additional-clients/sber-tv.key
/etc/amnezia/amneziawg/vps-tier/awg-client/additional-clients/sber-tv.pub
```

### Rendered profiles

```text
/var/lib/vps-tier/iphone-awg-profile/iphone-awg.conf
/var/lib/vps-tier/additional-awg-clients/windows.conf
/var/lib/vps-tier/additional-awg-clients/sber-tv.conf
```

These profiles contain private material and are mode `0600`.

Temporary transfer copies were created under `/home/trader/` during onboarding. Treat those as sensitive temporary artifacts and remove them after confirming successful imports.

## 8. Secret Boundary

Never commit or print:

- server/client private keys;
- complete `.conf` profiles;
- QR payloads;
- AWG J/S/H parameter values from `params.env`;
- tokens or credential-bearing URLs.

Do not `cat`:

```text
/etc/amnezia/amneziawg/awg-client.conf
/etc/amnezia/amneziawg/vps-tier/awg-client/params.env
/var/lib/vps-tier/iphone-awg-profile/iphone-awg.conf
/var/lib/vps-tier/additional-awg-clients/windows.conf
/var/lib/vps-tier/additional-awg-clients/sber-tv.conf
```

Safe evidence includes service state, routing rules, allocated `/32`, SHA-256 fingerprints, handshake timestamps and transfer counters.

## 9. Client Profile Contract

Every device gets a unique keypair and `/32`.

Logical client profile:

```text
[Interface]
PrivateKey = <unique runtime-only client private key>
Address = 10.71.0.N/32
DNS = 1.1.1.1
MTU = 1280
Jc = <protected runtime value>
Jmin = <protected runtime value>
Jmax = <protected runtime value>
S1 = <protected runtime value>
S2 = <protected runtime value>
H1 = <protected runtime value>
H2 = <protected runtime value>
H3 = <protected runtime value>
H4 = <protected runtime value>

[Peer]
PublicKey = <Moscow AWG server public key>
Endpoint = 147.45.184.140:443
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

Matching Moscow peer:

```text
[Peer]
PublicKey = <client public key>
AllowedIPs = 10.71.0.N/32
```

Never assemble the final secret-bearing profile in chat. A Git-managed server script must read the protected runtime values locally and write the profile mode `0600`.

## 10. How To Add Another Device

### Step 1 - Inspect peer allocation

Safe read-only check on Moscow:

```bash
sudo awg show awg-client allowed-ips
```

Confirm the candidate `/32` is unused.

### Step 2 - Create a Git-managed task

Do not add the peer manually with an untracked server command.

Create a branch from current `main` with:

- a task/stage contract or clear runbook scope;
- an apply script;
- a rollback script;
- non-secret validation output.

The existing `scripts/apply_additional_awg_clients.sh` is specific to the Windows + Sber TV batch and intentionally refuses unsafe reruns. Do not use it blindly for future devices.

### Step 3 - New provisioning script requirements

The managed script should:

1. verify the exact Moscow host identity;
2. require AWG, backbone and fail-closed services to be healthy;
3. verify the candidate `/32` is free;
4. snapshot/hash the current persistent AWG config;
5. generate a new keypair locally with `awg genkey` and `awg pubkey`;
6. keep private material root-only;
7. append only the new public-key peer and `/32` to a temporary server config;
8. validate the temporary config before replacement;
9. atomically install the persistent config;
10. apply the peer live with `awg set` without restarting existing clients;
11. render the new profile using the protected server AWG parameters;
12. save it mode `0600` under `/var/lib/vps-tier/...`;
13. save state with source Git SHA, backup path, hashes, public key, client address and profile SHA;
14. print only bounded non-secret output;
15. automatically roll back task-owned changes on failure.

### Step 4 - Git flow

```text
GitHub main
 -> feature branch
 -> full approved scope
 -> PR
 -> review
 -> correct blockers
 -> merge
 -> exact merged SHA
 -> server apply
 -> runtime verification
 -> evidence PR
```

No server hotfix is an acceptable substitute.

### Step 5 - Apply from merged main

Moscow repository working copy:

```text
/home/trader/vps-backup-relay
```

Synchronize to the exact approved merge SHA before apply. Pass the full SHA through `VPS_TIER_SOURCE_HEAD` when required by the script.

### Step 6 - Secure profile transfer

Preferred transfer:

- create a temporary mode-`0600` user-owned copy only when needed;
- SCP/SFTP it to a trusted local device;
- import it into the VPN client;
- remove temporary transfer copies after import.

Never use GitHub, public web hosting, paste services, chat, or a public Nginx location to distribute a profile.

### Step 7 - Verify

Required per-device acceptance:

```text
AWG handshake present
public IPv4 = 194.32.142.88
IPv6 public escape = absent
DNS works through tunnel
existing peers continue working
Moscow fallback remains impossible
```

Then add non-secret evidence under `docs/observed/analysis/`.

## 11. Device Notes

### iPhone / iOS

Client address:

```text
10.71.0.2/32
```

Use AmneziaWG for iOS and import the dedicated profile.

The iPhone is the architecture-level accepted client: Kazakhstan egress, IPv6 fail-closed and backbone-loss behavior were directly tested.

### Windows

Client address:

```text
10.71.0.3/32
```

Use AmneziaWG for Windows and import the dedicated `windows.conf` profile.

The profile is full-tunnel. During SberBox file transfer, Windows attempted to reach the LAN TV address with source `10.71.0.3` and timed out. After disabling AmneziaWG on Windows, the local X-plore web interface became reachable.

Operational consequence: temporarily disable the Windows tunnel for local-LAN-only file transfer unless a later managed LAN-bypass design is added.

### Sber TV / SberBox

Client address:

```text
10.71.0.4/32
```

Use the Android build of AmneziaWG with the dedicated `sber-tv.conf` profile.

What is proven from the current setup:

- AmneziaWG Android was successfully sideloaded on the Sber device;
- X-plore Wi-Fi file manager successfully transferred `sber-tv.conf` to the TV `Download` directory;
- X-plore did not itself satisfy AmneziaWG's system file-picker requirement;
- Total Commander was installed during troubleshooting, but AmneziaWG still showed the file-management-utility prompt in at least one attempt;
- the profile was eventually imported successfully and YouTube worked through the active TV tunnel;
- the exact final file-picker action that succeeded was not captured in the chat transcript.

Therefore, do not document Total Commander as a guaranteed fix. For a future Sber/Android TV reinstall, first transfer the profile to local storage, then use a current Android file-picker/file-manager implementation that actually registers for the file-selection intent used by AmneziaWG. If import UI remains blocked, investigate the current AmneziaWG Android TV import path rather than changing the VPN servers.

Known LAN transfer method:

1. install X-plore on the TV;
2. start X-plore Wi-Fi file manager;
3. note its displayed address such as `http://<TV-LAN-IP>:1111`;
4. ensure the Windows AmneziaWG tunnel is disabled so the PC can reach the local LAN;
5. open the X-plore address from Windows;
6. upload `sber-tv.conf` into the TV `Download` directory.

The transfer step is independent from the Android file-picker/import step.

## 12. Safe Health Checks

### Moscow service state

```bash
sudo systemctl is-active awg-quick@awg-client.service wg-quick@wg-backbone.service vps-tier-moscow-client-policy.service
```

### Moscow AWG peers

```bash
sudo awg show awg-client
```

This shows public peer state, handshakes and counters; it does not require printing private keys.

### Moscow backbone

```bash
sudo wg show wg-backbone
```

### Moscow policy routing

```bash
ip -4 rule show
ip -4 route show table 1071
```

Expected critical rule/table state:

```text
10710: from 10.71.0.0/24 lookup 1071
default dev wg-backbone metric 10
prohibit default metric 32760
```

### Moscow forwarding/firewall

```bash
sysctl net.ipv4.ip_forward net.ipv6.conf.all.forwarding
sudo ufw status numbered
```

### Moscow source route test

```bash
ip -4 route get 1.1.1.1 from 10.71.0.2 iif awg-client
```

Expected route uses table `1071` and `wg-backbone`.

### Kazakhstan checks

```bash
sudo systemctl is-active wg-quick@wg-backbone.service
sudo wg show wg-backbone
ip -4 route show 10.71.0.0/24
sysctl net.ipv4.ip_forward net.ipv6.conf.all.forwarding
sudo ufw status numbered
sudo iptables -t nat -S POSTROUTING | grep vps-tier-kz-client-egress
```

Expected public SNAT target is `194.32.142.88`.

## 13. End-To-End Client Checks

With a client tunnel enabled:

1. confirm normal Internet access;
2. confirm public IPv4 is exactly `194.32.142.88`;
3. attempt an IPv6-only destination; no public IPv6 path should escape;
4. confirm a current AWG handshake/traffic counter for that peer on Moscow;
5. after material routing changes, repeat the controlled backbone-loss test.

Do not accept the system merely because a website opens. The critical property is Kazakhstan egress with no Moscow fallback.

## 14. Controlled Backbone-Loss Test

This is intentionally disruptive to client Internet, so always schedule automatic restoration first.

Proven procedure concept:

1. schedule a transient systemd timer that starts `wg-quick@wg-backbone.service` after a short interval;
2. stop `wg-quick@wg-backbone.service` on Moscow;
3. leave the client AmneziaWG tunnel enabled;
4. confirm client Internet disappears;
5. confirm no Moscow public fallback is obtained;
6. confirm the backbone service auto-restores;
7. confirm client Internet returns.

Expected fail-closed state while backbone is down:

```text
client Internet=blocked
policy rule 10710=present
prohibit default=present
Moscow eth0 fallback=blocked
```

Never perform an uncontrolled backbone stop without an automatic recovery path.

## 15. Git-Managed Implementation Map

### Architecture

```text
contracts/two_hop_vpn/architecture_contract.md
```

### Backbone

```text
docs/runbook/wireguard_backbone.md
scripts/apply_wireguard_backbone_host.sh
scripts/rollback_wireguard_backbone_host.sh
```

### Kazakhstan forwarding/SNAT

```text
contracts/two_hop_vpn/kz_client_egress_stage_contract.md
docs/runbook/kz_client_egress_forwarding_snat.md
scripts/apply_kz_client_egress_stage4.sh
scripts/rollback_kz_client_egress_stage4.sh
```

### Moscow AWG termination

```text
contracts/two_hop_vpn/moscow_awg_client_termination_stage_contract.md
docs/runbook/moscow_awg_client_termination.md
scripts/apply_moscow_awg_client_termination.sh
scripts/rollback_moscow_awg_client_termination.sh
```

### Moscow fail-closed routing

```text
contracts/two_hop_vpn/moscow_fail_closed_routing_stage_contract.md
docs/runbook/moscow_fail_closed_routing.md
scripts/apply_moscow_fail_closed_routing.sh
scripts/moscow_client_policy_runtime.sh
scripts/rollback_moscow_fail_closed_routing.sh
templates/systemd/vps-tier-moscow-client-policy.service
templates/systemd/awg-client-fail-closed.conf
```

### iPhone profile

```text
contracts/two_hop_vpn/iphone_awg_profile_stage_contract.md
docs/runbook/iphone_awg_profile.md
scripts/render_iphone_awg_profile.sh
scripts/rollback_iphone_awg_profile.sh
```

### Windows and Sber TV profiles

```text
contracts/two_hop_vpn/additional_awg_clients_stage7b_contract.md
docs/runbook/additional_awg_clients.md
scripts/apply_additional_awg_clients.sh
scripts/rollback_additional_awg_clients.sh
```

## 16. Acceptance Evidence Map

```text
docs/observed/analysis/wireguard_backbone_two_hosts_acceptance_2026-08-07.md
docs/observed/analysis/kz_client_egress_stage4_acceptance_2026-08-07.md
docs/observed/analysis/moscow_awg_client_termination_stage5_acceptance_2026-08-07.md
docs/observed/analysis/moscow_fail_closed_routing_stage6_acceptance_2026-08-07.md
docs/observed/analysis/iphone_awg_profile_stage7_acceptance_2026-08-08.md
docs/observed/analysis/two_hop_vpn_stage8_live_acceptance_2026-08-08.md
```

## 17. Rollback Ownership

Use only stage-owned rollback; do not perform a broad manual teardown.

```text
Additional Windows/TV peers:
  scripts/rollback_additional_awg_clients.sh

iPhone rendered profile:
  scripts/rollback_iphone_awg_profile.sh

Moscow fail-closed routing:
  scripts/rollback_moscow_fail_closed_routing.sh

Moscow AWG termination:
  scripts/rollback_moscow_awg_client_termination.sh

Kazakhstan egress:
  scripts/rollback_kz_client_egress_stage4.sh

Backbone:
  scripts/rollback_wireguard_backbone_host.sh
  rollback Moscow first, then Kazakhstan
```

Read the relevant runbook before rollback. Hash guards intentionally stop rollback if managed state has diverged.

## 18. Troubleshooting Decision Tree

### No client handshake

Check in order:

1. correct dedicated profile is imported;
2. `awg-quick@awg-client` is active;
3. UDP/443 ingress is present;
4. Moscow contains the client's public key and unique `/32`;
5. no other active device is using the same client profile.

### Handshake exists but no Internet

Check:

1. `vps-tier-moscow-client-policy.service`;
2. rule `10710`;
3. table `1071` usable default via `wg-backbone`;
4. Moscow-Kazakhstan WireGuard handshake;
5. Kazakhstan route for `10.71.0.0/24`;
6. Kazakhstan UFW routed allow;
7. Kazakhstan SNAT marker.

### Internet works but public IP is Moscow

Treat as a security failure. Stop acceptance. The design forbids Moscow fallback.

### Local LAN inaccessible from Windows while VPN is on

Expected with the current full-tunnel profile. Disable the tunnel temporarily for LAN file transfer unless a future managed LAN-bypass design is approved.

### Public IPv6 works directly

Treat as a leak/security failure. The current architecture has no authorized IPv6 egress path.

## 19. Current Operational Status

As of 2026-08-08:

```text
Moscow-Kazakhstan backbone=active and accepted
Kazakhstan forwarding+SNAT=accepted
Moscow AmneziaWG termination=accepted
Moscow fail-closed routing=accepted
iPhone=imported and architecture-level end-to-end accepted
Windows=profile provisioned; tunnel observed active
Sber TV=profile imported; YouTube/Internet observed working
```

The iPhone directly proved:

```text
public IPv4=194.32.142.88
IPv6 escape=blocked
backbone loss -> client Internet blocked
backbone restore -> client Internet recovered
```

Windows and TV should still receive strict per-device public-IP and IPv6 checks if formal per-device acceptance is required.

The VPN runtime was last extended for Windows and Sber TV from merged Git main SHA:

```text
48dd64145cc1cd0173ecb841da740d139ec265df
```

This handover is documentation-only and requires no server apply.

## 20. Non-Negotiable Rules For Future Operators

1. GitHub is source of truth; servers are applied/observed state.
2. Every device gets one unique private key and one unique `/32`.
3. Do not reuse a client profile across simultaneously active devices.
4. Never print or commit private profiles or AWG protected parameter values.
5. Never add Moscow SNAT for `10.71.0.0/24`.
6. Never allow client fallback from `awg-client` to Moscow `eth0`.
7. Never replace either host's ordinary default route for this VPN architecture.
8. Keep IPv6 fail-closed until a separately reviewed end-to-end IPv6 design exists.
9. Provision future clients through reviewed Git-managed apply/rollback scripts.
10. Verify Kazakhstan egress and fail-closed behavior after material routing changes.
11. Preserve unrelated production services on both hosts.
12. If runtime ownership or hashes are ambiguous, stop and inspect before mutation.

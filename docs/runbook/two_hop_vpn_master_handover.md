# Two-Hop VPN Master Operations Handover

## Purpose

This is the primary handover document for the working two-hop personal VPN deployed across the Moscow and Kazakhstan VPS hosts.

Read this file first when taking over the system. It explains:

- what the topology is and why it exists;
- which host terminates client VPN sessions;
- how client traffic is forced through Kazakhstan;
- how fail-closed behavior is implemented;
- the current address plan and client allocation;
- where managed runtime files live;
- how device profiles are generated and transferred;
- how to add another phone, PC, tablet, or TV safely;
- how to verify and troubleshoot the path without exposing secrets;
- which scripts own rollback.

This document is descriptive and operational. Git remains the source of truth. It does not authorize ad hoc server changes.

## 1. Desired Result

The user-visible path is:

```text
Phone / Windows / TV
        |
        | AmneziaWG 2, UDP/443
        v
Moscow VPS
147.45.184.140
awg-client: 10.71.0.1/24
        |
        | policy routing only
        v
wg-backbone
Moscow 10.70.0.1/30
        |
        | standard WireGuard, UDP/51820
        v
Kazakhstan VPS
194.32.142.88
wg-backbone: 10.70.0.2/30
        |
        | forwarding + SNAT
        v
Internet
public IPv4 seen by destinations: 194.32.142.88
```

Required security behavior:

```text
CLIENT_CONNECTS_TO=Moscow
CLIENT_PUBLIC_EGRESS=Kazakhstan
MOSCOW_PUBLIC_EGRESS_FALLBACK=forbidden
IPV6_POLICY=fail_closed
DNS=inside_the_client_tunnel
MOSCOW_SNAT=none
KAZAKHSTAN_SNAT=required
```

The access ISP sees the client connecting to Moscow. Internet destinations see the Kazakhstan public IPv4.

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
- keep each client on a unique `/32` address and keypair;
- source-policy-route `10.71.0.0/24` only to the Kazakhstan backbone;
- explicitly deny client forwarding to the Moscow public interface;
- perform no client SNAT;
- keep IPv6 forwarding disabled.

TCP/443 used by Nginx is independent from UDP/443 used by AmneziaWG.

### Kazakhstan VPS

```text
public_ipv4=194.32.142.88
backbone_interface=wg-backbone
backbone_address=10.70.0.2/30
public_interface=enp3s0
client_subnet_return_route=10.71.0.0/24 via wg-backbone
client_public_snat=194.32.142.88
```

Responsibilities:

- accept `10.71.0.0/24` only from the Moscow WireGuard peer;
- forward client IPv4 traffic from `wg-backbone` to `enp3s0`;
- SNAT that subnet to `194.32.142.88`;
- return traffic through `wg-backbone` to Moscow;
- keep IPv6 forwarding disabled;
- preserve existing n8n, Flowise, Xray, Hysteria2, Nginx, Docker and cloudflared services.

## 3. Address Plan

### Infrastructure

```text
10.70.0.0/30   Moscow-Kazakhstan backbone
10.70.0.1/30   Moscow wg-backbone
10.70.0.2/30   Kazakhstan wg-backbone

10.71.0.0/24   AmneziaWG client subnet
10.71.0.1/24   Moscow awg-client server
```

### Current client allocation

```text
10.71.0.2/32   iPhone
10.71.0.3/32   Windows
10.71.0.4/32   Sber TV / SberBox
```

Current rendered profile fingerprints:

```text
iPhone  sha256=bd69cc20bb39e44cabc052e0bea2b5dd209c8142744f2d48da8745b4f895ba7c
Windows sha256=b1ba3e7262ab090836d61f4416ed3599aa30b24e4e036e2d78c85d646a4909c7
Sber TV sha256=5bffddfc7c27e653c7660bbc09759f37946a7d31a0279338b66f585ae2c14eef
```

The fingerprints identify the files without exposing their contents.

For the next client, `10.71.0.5/32` is the first candidate, but it is not automatically reserved. Always verify the live and persistent peer sets before allocating any address.

Never use the same `/32` or the same client private key on two simultaneously active devices.

## 4. Packet Flow

For an iPhone packet sourced from `10.71.0.2`:

1. The device encrypts the packet in AmneziaWG and sends it to `147.45.184.140:443/udp`.
2. Moscow decrypts it on `awg-client`.
3. Policy rule priority `10710` matches source `10.71.0.0/24` and selects routing table `1071`.
4. Table `1071` sends the packet to `wg-backbone`.
5. Standard WireGuard carries it from Moscow `10.70.0.1` to Kazakhstan `10.70.0.2`.
6. Kazakhstan forwards the original client packet toward `enp3s0`.
7. Kazakhstan SNAT changes the source to `194.32.142.88`.
8. Internet replies return to Kazakhstan, are de-NATed, routed back through `wg-backbone`, then returned by Moscow through `awg-client` to the device.

Windows and TV follow the same path with source addresses `10.71.0.3` and `10.71.0.4` respectively.

DNS in current profiles is `1.1.1.1`. Because the profiles are full-tunnel, DNS traffic follows the same Moscow -> Kazakhstan path.

## 5. Moscow Fail-Closed Design

The system must never silently fall back to Moscow Internet egress when Kazakhstan is unavailable.

Three independent barriers enforce this.

### 5.1 Source policy rule

```text
priority=10710
from=10.71.0.0/24
lookup=1071
```

Client packets do not use the Moscow main routing table for Internet destinations.

### 5.2 Dedicated policy table

Expected table `1071` state while the backbone is healthy:

```text
default dev wg-backbone metric 10
prohibit default metric 32760
```

When `wg-backbone` disappears, the usable default disappears with it but `prohibit default` remains. The resulting behavior is failure, not fallback.

### 5.3 UFW forwarding boundary

Moscow owns two Stage-6 routed rules for the client subnet:

```text
DENY  awg-client -> eth0        from 10.71.0.0/24
ALLOW awg-client -> wg-backbone from 10.71.0.0/24
```

There is no Moscow SNAT/MASQUERADE rule for `10.71.0.0/24`.

### 5.4 Forwarding state

Moscow persistent state:

```text
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=0
```

Managed file:

```text
/etc/sysctl.d/99-vps-tier-moscow-client-routing.conf
```

## 6. Kazakhstan Egress Design

Kazakhstan owns the Internet egress function.

Expected state:

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

The managed SNAT rule carries the marker:

```text
vps-tier-kz-client-egress
```

The Kazakhstan WireGuard peer for Moscow includes `10.71.0.0/24` in AllowedIPs so return routing is reconstructed with the backbone.

## 7. Managed Interfaces And Services

### Moscow

```text
awg-quick@awg-client.service
wg-quick@wg-backbone.service
vps-tier-moscow-client-policy.service
ufw.service
```

### Kazakhstan

```text
wg-quick@wg-backbone.service
ufw.service
```

Do not change default routes on either server as part of client provisioning.

## 8. Important Runtime Paths

### Moscow standard WireGuard backbone

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

### Original iPhone identity

```text
/etc/amnezia/amneziawg/vps-tier/awg-client/iphone.key
/etc/amnezia/amneziawg/vps-tier/awg-client/iphone.pub
```

### Additional Windows and TV identities

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

These files contain private key material. They are root-only and must never be printed or committed.

Temporary user-owned transfer copies were created under `/home/trader/` during device setup. Treat them as sensitive temporary artifacts. Verify and remove them after confirming that the corresponding device import is complete.

## 9. Secret Boundary

Never put any of the following in Git, PR text, issue text, chat, terminal transcripts or observed evidence:

- client or server private keys;
- full client `.conf` files;
- QR payloads;
- values from `params.env` such as J/S/H obfuscation parameters;
- complete credential-bearing URLs or tokens.

Allowed evidence includes:

- public IP addresses already part of the architecture;
- client `/32` allocation;
- public keys when operationally required;
- SHA-256 fingerprints;
- service states;
- route/rule presence;
- handshake timestamps and transfer counters.

Do not run `cat` against `awg-client.conf`, client profiles, key files, or `params.env` during troubleshooting.

## 10. Client Profile Structure

Every user device must have a unique client private/public keypair and a unique `/32` inside `10.71.0.0/24`.

The logical client profile is:

```text
[Interface]
PrivateKey = <unique runtime-only client private key>
Address = 10.71.0.N/32
DNS = 1.1.1.1
MTU = 1280
Jc = <read from protected server runtime parameters>
Jmin = <read from protected server runtime parameters>
Jmax = <read from protected server runtime parameters>
S1 = <read from protected server runtime parameters>
S2 = <read from protected server runtime parameters>
H1 = <read from protected server runtime parameters>
H2 = <read from protected server runtime parameters>
H3 = <read from protected server runtime parameters>
H4 = <read from protected server runtime parameters>

[Peer]
PublicKey = <Moscow AWG server public key>
Endpoint = 147.45.184.140:443
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

The matching Moscow server peer is logically:

```text
[Peer]
PublicKey = <that client's public key>
AllowedIPs = 10.71.0.N/32
```

Do not manually assemble this profile in chat. A Git-managed server script should read the sensitive runtime values locally and write the profile with mode `0600`.

## 11. How To Add A New Device

This is the canonical procedure for another phone, computer, tablet or TV.

### Step 1 - Inspect before allocating

On Moscow, read only safe state:

```bash
sudo awg show awg-client allowed-ips
```

Confirm the candidate `/32` is unused. Also inspect the persistent managed server configuration without printing secret-bearing content; use a purpose-built parser/validator in the task rather than `cat`.

### Step 2 - Allocate one new `/32`

Use the next free address from `10.71.0.0/24`. Current assignments end at `10.71.0.4/32`, so `10.71.0.5/32` is only a candidate until checked.

Record the allocation in the implementation contract/runbook.

### Step 3 - Make a Git task first

Do not create the peer manually on the server.

Create a dedicated Git branch and managed apply/rollback script for the new client or for the explicitly approved batch of new clients.

The existing `scripts/apply_additional_awg_clients.sh` was written specifically for the Windows and Sber TV batch and is intentionally guarded against rerun. Do not reuse it blindly to create arbitrary future clients.

A new managed client-provisioning script should:

1. bind to the exact Moscow host identity;
2. require the accepted AWG, backbone and fail-closed services to be active;
3. verify the new `/32` is not already present;
4. snapshot and hash the current persistent AWG server config;
5. generate a new client keypair locally with `awg genkey` / `awg pubkey` under a root-only directory;
6. append only the new public-key peer and `/32` to a temporary server config;
7. validate the temporary config before replacement;
8. atomically install the updated persistent config;
9. apply the new peer live with `awg set`, avoiding disruption of existing clients;
10. render the client profile from the local private key, server public key and protected AWG parameters;
11. save the profile mode `0600` under `/var/lib/vps-tier/...`;
12. save a state file containing source Git SHA, backup location, config hashes, client public key, address and profile SHA-256;
13. print only bounded non-secret output;
14. automatically roll back task-owned changes on failure.

### Step 4 - Review and merge before runtime apply

Canonical flow:

```text
GitHub main
 -> feature branch
 -> implementation + rollback + runbook
 -> PR review
 -> fix blocking review findings
 -> merge
 -> exact merged main SHA
 -> server apply
 -> runtime verification
 -> observed evidence PR
```

No server hotfix is an acceptable substitute.

### Step 5 - Apply from exact merged SHA

The server working copy is:

```text
/home/trader/vps-backup-relay
```

Synchronize it to the exact approved `main`, then execute the merged managed script with `VPS_TIER_SOURCE_HEAD=<full merged SHA>`.

### Step 6 - Transfer the rendered profile securely

Preferred method:

- create a temporary user-owned mode-`0600` copy only for transfer;
- use SCP/SFTP to a trusted local device;
- import into the VPN application;
- remove temporary transfer copies after successful import.

Never expose a profile through Nginx, a public temporary URL, GitHub, chat or paste services.

### Step 7 - Verify the new device

Required checks:

```text
AWG tunnel connects
unique client handshake present
public IPv4 = 194.32.142.88
IPv6 does not escape
DNS works through the tunnel
existing clients still work
Moscow fallback remains impossible
```

Then commit non-secret acceptance evidence under `docs/observed/analysis/`.

## 12. Device-Specific Import Notes

### iPhone / iOS

Use the AmneziaWG iOS client and import the dedicated `.conf` file.

Current dedicated identity:

```text
10.71.0.2/32
```

Do not reuse the iPhone profile on another active device.

### Windows

Use the AmneziaWG Windows client and import `windows.conf`.

Current dedicated identity:

```text
10.71.0.3/32
```

The current profile is full-tunnel. While it is enabled, local LAN access can be captured by the VPN route. This was observed when Windows attempted to reach the SberBox LAN address: the connection used source `10.71.0.3` and timed out. For local file transfer to the TV, temporarily disable the Windows tunnel unless a separate, explicitly designed LAN-bypass policy is introduced later.

### Sber TV / SberBox

Use the Android build of AmneziaWG with the dedicated `sber-tv.conf` profile.

Current dedicated identity:

```text
10.71.0.4/32
```

Practical installation/import procedure proven during setup:

1. sideload the AmneziaWG Android APK through the Sber-supported APK installation mechanism;
2. install X-plore File Manager for easy LAN file transfer;
3. start X-plore Wi-Fi file manager on the TV;
4. with the Windows AmneziaWG tunnel disabled, open X-plore's displayed `http://<TV-LAN-IP>:1111` address from Windows on the same LAN;
5. upload `sber-tv.conf` into the TV `Download` directory;
6. if AmneziaWG reports that a file-management utility is required, install Total Commander for Android as a system file-selection helper;
7. import the dedicated profile into AmneziaWG;
8. enable the tunnel and verify Internet access and egress.

X-plore itself may transfer files successfully while still not satisfying the Android file-picker intent required by AmneziaWG; the extra file-management utility solved that import path during the current deployment.

## 13. Safe Health Checks

### Moscow

Service health:

```bash
sudo systemctl is-active awg-quick@awg-client.service wg-quick@wg-backbone.service vps-tier-moscow-client-policy.service
```

AWG peer state without private keys:

```bash
sudo awg show awg-client
```

Backbone state:

```bash
sudo wg show wg-backbone
```

Policy routing:

```bash
ip -4 rule show
ip -4 route show table 1071
```

Forwarding policy:

```bash
sysctl net.ipv4.ip_forward net.ipv6.conf.all.forwarding
sudo ufw status numbered
```

Source route check for a client address:

```bash
ip -4 route get 1.1.1.1 from 10.71.0.2 iif awg-client
```

Expected result uses table `1071` and `wg-backbone`.

### Kazakhstan

```bash
sudo systemctl is-active wg-quick@wg-backbone.service
sudo wg show wg-backbone
ip -4 route show 10.71.0.0/24
sysctl net.ipv4.ip_forward net.ipv6.conf.all.forwarding
sudo ufw status numbered
sudo iptables -t nat -S POSTROUTING | grep vps-tier-kz-client-egress
```

Expected public SNAT target is `194.32.142.88`.

## 14. End-To-End Checks From A Client

With the client tunnel enabled:

1. verify ordinary Internet access;
2. verify public IPv4 is exactly `194.32.142.88`;
3. test an IPv6-only destination; it must not expose a public IPv6 path;
4. verify the Moscow AWG peer shows a current handshake/transfer counter;
5. if doing formal acceptance, perform the controlled backbone-loss test described in the Stage-8 evidence file.

Do not accept the system merely because a website opens. The critical property is Kazakhstan egress with no Moscow fallback.

## 15. Controlled Backbone-Loss Test

This is a disruptive acceptance test. It intentionally interrupts client Internet for a short period while preserving SSH access to Moscow.

Before stopping the backbone, schedule automatic restoration, for example with a transient systemd timer. Then stop only `wg-quick@wg-backbone.service`.

Expected behavior:

```text
client AWG remains configured
client Internet stops
client does not obtain Moscow public egress
policy table retains prohibit default
backbone auto-restores
client Internet returns
public egress returns to 194.32.142.88
```

Do not run an uncontrolled backbone stop without an automatic restore path.

## 16. Existing Git-Managed Implementation

Primary architecture:

```text
contracts/two_hop_vpn/architecture_contract.md
```

Backbone:

```text
docs/runbook/wireguard_backbone.md
scripts/apply_wireguard_backbone_host.sh
scripts/rollback_wireguard_backbone_host.sh
```

Kazakhstan forwarding/SNAT:

```text
contracts/two_hop_vpn/kz_client_egress_stage_contract.md
docs/runbook/kz_client_egress_forwarding_snat.md
scripts/apply_kz_client_egress_stage4.sh
scripts/rollback_kz_client_egress_stage4.sh
```

Moscow AmneziaWG termination:

```text
contracts/two_hop_vpn/moscow_awg_client_termination_stage_contract.md
docs/runbook/moscow_awg_client_termination.md
scripts/apply_moscow_awg_client_termination.sh
scripts/rollback_moscow_awg_client_termination.sh
```

Moscow policy routing/fail-closed:

```text
contracts/two_hop_vpn/moscow_fail_closed_routing_stage_contract.md
docs/runbook/moscow_fail_closed_routing.md
scripts/apply_moscow_fail_closed_routing.sh
scripts/moscow_client_policy_runtime.sh
scripts/rollback_moscow_fail_closed_routing.sh
templates/systemd/vps-tier-moscow-client-policy.service
templates/systemd/awg-client-fail-closed.conf
```

iPhone profile:

```text
contracts/two_hop_vpn/iphone_awg_profile_stage_contract.md
docs/runbook/iphone_awg_profile.md
scripts/render_iphone_awg_profile.sh
scripts/rollback_iphone_awg_profile.sh
```

Windows and Sber TV profiles:

```text
contracts/two_hop_vpn/additional_awg_clients_stage7b_contract.md
docs/runbook/additional_awg_clients.md
scripts/apply_additional_awg_clients.sh
scripts/rollback_additional_awg_clients.sh
```

## 17. Existing Acceptance Evidence

```text
docs/observed/analysis/wireguard_backbone_two_hosts_acceptance_2026-08-07.md
docs/observed/analysis/kz_client_egress_stage4_acceptance_2026-08-07.md
docs/observed/analysis/moscow_awg_client_termination_stage5_acceptance_2026-08-07.md
docs/observed/analysis/moscow_fail_closed_routing_stage6_acceptance_2026-08-07.md
docs/observed/analysis/iphone_awg_profile_stage7_acceptance_2026-08-08.md
docs/observed/analysis/two_hop_vpn_stage8_live_acceptance_2026-08-08.md
```

The Stage-8 file records the user-visible end-to-end tests performed after client import.

## 18. Rollback Ownership

Rollback is stage-owned. Do not improvise a broad teardown.

- Additional Windows/TV peers only: `scripts/rollback_additional_awg_clients.sh`.
- iPhone rendered profile only: `scripts/rollback_iphone_awg_profile.sh`.
- Moscow fail-closed routing: `scripts/rollback_moscow_fail_closed_routing.sh`.
- Moscow AWG termination: `scripts/rollback_moscow_awg_client_termination.sh`.
- Kazakhstan egress: `scripts/rollback_kz_client_egress_stage4.sh`.
- Backbone: rollback Moscow first, then Kazakhstan using `scripts/rollback_wireguard_backbone_host.sh` and the approved transferred Kazakhstan copy.

Before rollback, read the relevant runbook and state guards. The rollback scripts intentionally refuse destructive recovery when managed hashes or ownership no longer match.

## 19. Troubleshooting Logic

### Tunnel does not handshake

Check in this order:

1. device profile is the dedicated profile for that device;
2. Moscow `awg-quick@awg-client` is active;
3. UDP/443 is listening/allowed;
4. server has the client's public key and unique `/32`;
5. no second simultaneously active device is using the same client profile.

### Handshake exists but no Internet

Check:

1. `vps-tier-moscow-client-policy.service` active;
2. policy rule `10710` present;
3. table `1071` has usable `wg-backbone` default;
4. `wg-backbone` handshake is healthy;
5. Kazakhstan has route for `10.71.0.0/24`;
6. Kazakhstan UFW forwarding rule is present;
7. Kazakhstan SNAT marker is present.

### Internet works but public IP is Moscow

Treat this as a security failure. Stop acceptance immediately. The design forbids Moscow fallback. Inspect policy routing, Moscow UFW forwarding and NAT state before further use.

### Client cannot reach local LAN while VPN is on

This is expected with the current full-tunnel profile because `AllowedIPs` contains both `0.0.0.0/0` and `::/0`. Temporarily disable the client tunnel for LAN-only file transfer unless a later managed design explicitly adds LAN bypass.

### IPv6 works directly outside the tunnel

Treat as a leak/security failure. Current design requires IPv6 fail-closed and has no authorized end-to-end IPv6 path.

## 20. Current Operational Status At Handover

As of 2026-08-08:

```text
backbone=Moscow-Kazakhstan active and accepted
Kazakhstan forwarding+SNAT=accepted
Moscow AmneziaWG termination=accepted
Moscow fail-closed routing=accepted
iPhone profile=imported and end-to-end tested
Windows profile=provisioned and tunnel observed active
Sber TV profile=imported; Internet/YouTube observed working
```

The exact iPhone egress and backbone-loss behavior were directly verified. Windows and TV were functionally brought online, but their exact public-IP/IPv6 checks should be repeated and recorded if strict per-device acceptance is required.

The VPN runtime was last extended for Windows and Sber TV from merged Git main SHA:

```text
48dd64145cc1cd0173ecb841da740d139ec265df
```

This handover documentation itself is a documentation-only Git change and does not require server apply.

## 21. Non-Negotiable Rules For Future Operators

1. GitHub is source of truth; servers are applied/observed state.
2. One device gets one client keypair and one unique `/32`.
3. Never copy one active client profile to another simultaneously used device.
4. Never print private profiles or AWG parameter values.
5. Never add Moscow SNAT for `10.71.0.0/24`.
6. Never allow fallback from `awg-client` to Moscow `eth0`.
7. Never replace either server's normal default route for this architecture.
8. Keep IPv6 fail-closed until a separately designed end-to-end IPv6 architecture exists.
9. Create new clients through reviewed Git-managed apply/rollback scripts, not shell hotfixes.
10. Verify Kazakhstan egress and fail-closed behavior after material routing changes.
11. Preserve unrelated production services on both hosts.
12. If state is ambiguous, stop and inspect before mutation.

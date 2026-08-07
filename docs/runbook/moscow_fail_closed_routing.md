# Moscow Fail-Closed Client Routing — Stage 6 Runbook

## Purpose

Stage 6 enables IPv4 forwarding for the accepted AmneziaWG client subnet only after installing a fail-closed source-policy path to Kazakhstan.

```text
10.71.0.0/24 -> awg-client -> table 1071 -> wg-backbone -> Kazakhstan
```

Moscow public egress through `eth0` is not an authorized fallback.

## Managed Runtime State

Stage 6 manages:

```text
policy table=1071
policy priority=10710
client subnet=10.71.0.0/24
usable default=dev wg-backbone metric 10
fail-closed default=prohibit default metric 32760
```

The Moscow backbone peer is widened to `AllowedIPs=0.0.0.0/0`, while `Table=off` prevents `wg-quick` from adding a host default route.

The usable policy-table default follows the backbone lifecycle. The policy rule and `prohibit default` are installed by a separate persistent systemd barrier, so they remain the fail-closed result when the backbone route disappears.

## Boot Ordering

The managed AWG systemd drop-in uses:

```text
Requires=ufw.service
Wants=vps-tier-moscow-client-policy.service
After=ufw.service vps-tier-moscow-client-policy.service
ExecStartPre=systemctl is-active --quiet vps-tier-moscow-client-policy.service
```

This keeps UFW as a strong service dependency and prevents AWG startup unless the fail-closed policy barrier is active. The policy service is intentionally a startup gate rather than a stop-propagating `Requires=` dependency, so controlled Stage-6 rollback does not tear down the accepted Stage-5 AWG interface when the policy unit is stopped.

## Firewall

Exactly two Stage-6 routed rules are added:

```text
DENY  awg-client -> eth0        from 10.71.0.0/24
ALLOW awg-client -> wg-backbone from 10.71.0.0/24
```

Return traffic continues to rely on the existing `RELATED,ESTABLISHED` UFW forward rule.

## Forwarding

The managed sysctl file is:

```text
/etc/sysctl.d/99-vps-tier-moscow-client-routing.conf
```

It persists:

```text
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=0
```

IPv4 forwarding is set to `1` only after the policy barrier and UFW controls are installed.

## Moscow NAT

No Moscow SNAT/MASQUERADE rule is authorized. Client source NAT remains exclusively on Kazakhstan.

## Apply

After the implementation PR is merged:

1. synchronize the Moscow repository to the exact merged `main` SHA;
2. prove a clean working tree;
3. run `scripts/apply_moscow_fail_closed_routing.sh` through a unique detached systemd unit with `VPS_TIER_SOURCE_HEAD=<merged-main-sha>`;
4. do not rerun after terminal disconnect; inspect the existing transient unit first;
5. accept only from runtime evidence.

The apply script snapshots the existing WireGuard configuration, main routing table, policy rules, NAT table, UFW status and protected services before mutation.

## Runtime Acceptance

Required post-apply state:

```text
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=0
rule 10710 from 10.71.0.0/24 lookup 1071
table 1071 default dev wg-backbone metric 10
table 1071 prohibit default metric 32760
wg-backbone peer AllowedIPs=0.0.0.0/0
UFW client->wg-backbone allow present
UFW client->eth0 deny present
Moscow default route unchanged
Moscow main table unchanged
Moscow client NAT absent
backbone healthy
AWG termination healthy
protected services healthy
```

A route lookup for an Internet address using source `10.71.0.2` and input interface `awg-client` must resolve to `wg-backbone` in table `1071`.

## Fail-Closed Interpretation

There are three independent barriers against Moscow fallback:

1. the source-policy rule sends the client subnet to table `1071` instead of the host main table;
2. table `1071` retains a terminal `prohibit default` when the usable backbone route is absent;
3. UFW explicitly denies `awg-client -> eth0`, while routed default remains deny for other unapproved paths.

End-to-end backbone-loss behavior is proven later with the imported client profile; Stage 6 establishes and validates the server-side barriers.

## Rollback

Use:

```text
scripts/rollback_moscow_fail_closed_routing.sh
```

Rollback first sets Moscow IPv4 forwarding back to `0`. It then removes Stage-6 routed UFW rules, policy routes/rule and persistence files, restores the Stage-5 WireGuard configuration and `10.70.0.2/32` peer AllowedIPs, and preserves both the AWG termination and backbone.

The AWG policy relationship is startup-gated rather than stop-propagating, so stopping the Stage-6 policy unit during rollback must not stop `awg-quick@awg-client.service`.

Rollback refuses to overwrite a WireGuard configuration that has diverged from both the recorded Stage-5 baseline and Stage-6 applied hash.

## Secret Boundary

The existing WireGuard configuration contains a private key and must never be printed or committed. Apply/rollback may copy and hash it locally but evidence contains no private key, complete VPN profile or AWG parameter values.

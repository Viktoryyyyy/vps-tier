# Stage 6 Runtime Acceptance

Date: 2026-08-07
Applied source: `07f5785db7e12fa82f4705d78b8d175fd4361c10`

Observed acceptance checks passed:

- Controlled Stage-6 apply completed with `Result=success` and `ExecMainStatus=0`.
- `awg-quick@awg-client`, `wg-quick@wg-backbone`, and `vps-tier-moscow-client-policy.service` are active.
- Moscow IPv4 forwarding is enabled: `net.ipv4.ip_forward=1`.
- IPv6 forwarding remains disabled: `net.ipv6.conf.all.forwarding=0`.
- Source policy rule is present: priority `10710`, source `10.71.0.0/24`, lookup table `1071`.
- Table `1071` contains a usable default through `wg-backbone` with metric `10`.
- Table `1071` contains terminal `prohibit default` with metric `32760`.
- Policy lookup for `1.1.1.1` from `10.71.0.2` arriving on `awg-client` resolves through `wg-backbone` in table `1071`.
- UFW explicitly denies `awg-client -> eth0` forwarding for `10.71.0.0/24` with marker `vps-tier-moscow-client-no-fallback`.
- UFW explicitly allows `awg-client -> wg-backbone` forwarding for `10.71.0.0/24` with marker `vps-tier-moscow-client-forward`.
- Apply evidence reports Moscow client NAT absent.
- End-to-end iPhone egress remains deferred until the client profile stage.
- No private key, AWG parameter values, complete client profile, or other secret material is included in this evidence.

Verdict: `STAGE6_STATUS=ACCEPTED`

Next stage: generate the iPhone AmneziaWG client profile outside Git, then perform end-to-end egress, DNS, IPv6 fail-closed, protected-service, and backbone-loss validation.

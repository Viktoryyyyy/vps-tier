# iPhone AmneziaWG Profile — Stage 7 Runtime Acceptance

Date: 2026-08-08
Applied source: `81046417b7328e36c5a3b1f80021c351160233fe`

Observed renderer output:

- profile rendered successfully on the Moscow VPS;
- managed profile path: `/var/lib/vps-tier/iphone-awg-profile/iphone-awg.conf`;
- profile mode: `600`;
- profile SHA-256: `bd69cc20bb39e44cabc052e0bea2b5dd209c8142744f2d48da8745b4f895ba7c`;
- DNS resolver: `1.1.1.1`;
- IPv4 full tunnel: enabled;
- IPv6 default captured by tunnel for fail-closed validation: enabled;
- renderer reported that no complete profile or secret material was printed;
- Stage-5 client identity and AWG parameters were reused by the managed renderer;
- complete profile contents, private key and AWG parameter values are not included in this evidence.

Stage boundary:

- secure transfer/import to the iPhone is not yet accepted;
- live client handshake, Kazakhstan public egress, DNS path, IPv6 escape prevention and backbone-loss fail-closed behavior remain Stage 8 acceptance items.

Verdict: `STAGE7_STATUS=ACCEPTED_RENDER_ONLY`

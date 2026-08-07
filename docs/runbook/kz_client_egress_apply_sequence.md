# Kazakhstan Client Egress — Controlled Execution Sequence

The runtime apply must use the exact merged Git `main` SHA.

1. Synchronize the clean Moscow repository to merged `main`.
2. Copy only `scripts/apply_kz_client_egress.sh` and `scripts/rollback_kz_client_egress.sh` to Kazakhstan `/tmp`.
3. Verify transferred SHA-256 hashes against the local Git files.
4. Launch the apply through a unique detached transient systemd unit with `VPS_TIER_SOURCE_HEAD=<merged-main-sha>`.
5. Do not rerun the apply after an SSH disconnect; inspect the existing unit and journal first.
6. Accept only after runtime state, route, UFW, SNAT, backbone health, sysctls, default route, and protected service state are observed.
7. Commit non-secret apply evidence to Git in a separate evidence PR.

Rollback uses the corresponding Git-managed rollback script and is blocked if the managed WireGuard config has diverged after Stage 4.

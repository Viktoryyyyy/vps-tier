# iPhone AmneziaWG Profile — Stage 7 Runbook

## Purpose

Render the iPhone AmneziaWG profile on Moscow without exposing private material in Git, terminal output, chat, or evidence.

## Apply

After the Stage-7 implementation PR is merged:

1. synchronize Moscow `main` to the exact merged SHA;
2. prove a clean working tree;
3. execute `scripts/render_iphone_awg_profile.sh` as root with `VPS_TIER_SOURCE_HEAD=<merged-main-sha>`;
4. accept only the bounded non-secret output;
5. never `cat` the generated profile into chat or logs.

Expected bounded output:

```text
DONE: iPhone AmneziaWG profile rendered
PROFILE_FILE=/var/lib/vps-tier/iphone-awg-profile/iphone-awg.conf
PROFILE_MODE=600
PROFILE_SHA256=<sha256>
DNS=1.1.1.1
IPV4_FULL_TUNNEL=yes
IPV6_FAIL_CLOSED_CAPTURE=yes
SECRETS_PRINTED=no
```

## Secure Transfer

Preferred transfer is direct SFTP/SCP from the Moscow VPS to a trusted local device or an SSH client that exposes its SFTP file browser, then import the `.conf` file into the AmneziaWG iOS app.

Do not publish the profile through Nginx, a temporary public HTTP endpoint, paste service, cloud note, GitHub issue/PR, or chat.

After import, the server-side profile file may remain temporarily for Stage-8 troubleshooting or be removed with the managed rollback after successful end-to-end acceptance.

## Rollback

Use `scripts/rollback_iphone_awg_profile.sh`.

Rollback removes only the rendered Stage-7 output after verifying its recorded SHA-256. It preserves Stage-5 key material, the running AWG interface, and Stage-6 routing/firewall state.

## Stage 8

After iPhone import, validate:

- AWG handshake;
- public IPv4 egress equals Kazakhstan `194.32.142.88`;
- DNS follows the Kazakhstan path;
- IPv6 does not escape;
- Moscow fallback remains blocked if the backbone is unavailable;
- protected services remain healthy.

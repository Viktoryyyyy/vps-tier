# Additional AmneziaWG Clients — Stage 7B Runbook

## Apply

After merge, synchronize Moscow `main` to the exact merge SHA and run `scripts/apply_additional_awg_clients.sh` as root with `VPS_TIER_SOURCE_HEAD=<merge-sha>`.

The apply generates independent Windows and Sber TV keypairs, appends two peer entries to the persistent Moscow AWG server config, applies the peers live without restarting the active interface, and renders two root-only profiles.

Expected bounded output includes only profile paths, addresses, SHA-256 values, iPhone preservation and `SECRETS_PRINTED=no`.

Never `cat` the profiles into terminal/chat.

## Transfer

For each profile, create a temporary user-owned mode-600 copy only when transferring it via SCP/SFTP. Remove that transfer copy after successful import.

### Windows

Install the official AmneziaWG Windows client and import the dedicated `windows.conf` profile.

### Sber TV / SberBox

Install the official AmneziaWG Android APK on the Sber device using the supported Sber APK upload/install flow, then import the dedicated `sber-tv.conf` profile.

Do not reuse the iPhone or Windows profile on the TV.

## Verification

For each device:

- connect the tunnel;
- confirm public IPv4 is `194.32.142.88`;
- confirm IPv6 does not escape;
- confirm the device has its own current AWG handshake;
- confirm the iPhone peer continues to operate independently.

## Rollback

`scripts/rollback_additional_awg_clients.sh` removes only the Windows and TV peers/material/profiles after hash guards pass. It restores the prior persistent server config and preserves the iPhone peer and Stage-6 routing.
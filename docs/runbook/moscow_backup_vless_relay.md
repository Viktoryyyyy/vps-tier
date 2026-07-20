# Moscow Backup VLESS Relay

## Purpose

Provide an optional backup path for the existing Kazakhstan VLESS Reality service without changing the Kazakhstan server, the primary client profile, Nginx, or Flowise.

```text
Primary profile:
client -> Kazakhstan:443 -> Internet

Backup profile, enabled only when needed:
client -> Moscow:8443 -> Kazakhstan:443 -> Internet
```

## Fixed scope

- Moscow host IPv4: `147.45.184.140`
- Moscow listener: `tcp/8443`
- Kazakhstan upstream: `194.32.142.88:443`
- Transport: raw bidirectional TCP relay
- Relay implementation: `systemd-socket-proxyd`
- No TLS termination on Moscow
- No Xray installation on Moscow
- No Nginx or Flowise configuration change
- No Kazakhstan configuration change
- No DNS change required

The apply script fails closed unless it confirms the Moscow host identity, active and valid Nginx, an existing `tcp/443` listener, a free or already-managed `tcp/8443`, and upstream reachability.

## Managed files

```text
hosts/moscow/etc/systemd/system/vps-backup-relay.socket
hosts/moscow/etc/systemd/system/vps-backup-relay.service
scripts/apply_moscow_backup_relay.sh
scripts/rollback_moscow_backup_relay.sh
```

Runtime targets on Moscow:

```text
/etc/systemd/system/vps-backup-relay.socket
/etc/systemd/system/vps-backup-relay.service
```

## Firewall boundary

The apply script does not modify UFW, nftables, iptables, or provider firewall settings.

If UFW is active, the script requires an existing allow rule for `tcp/8443` and stops before mutation when that rule is not proven. Any firewall change must be separately reviewed and committed.

## Controlled apply

Run only on the Moscow host, from the repository root, with a clean working tree and the approved Git HEAD:

```bash
sudo bash scripts/apply_moscow_backup_relay.sh
```

The script:

1. verifies host identity and prerequisites;
2. validates the two systemd units;
3. records a backup set;
4. installs only the relay units;
5. enables and starts only the socket unit;
6. checks local activation and Kazakhstan TCP reachability;
7. proves Nginx remained active, valid, listening on `443`, and kept the same MainPID;
8. writes non-secret observed evidence under `docs/observed/analysis/`.

After successful apply, Server / Apply must commit and push the evidence file.

## External verification

From outside the Moscow server, verify:

```text
147.45.184.140:8443 is reachable over TCP
```

Then duplicate the existing working VLESS Reality client profile and change only:

```text
Address: 147.45.184.140
Port: 8443
```

Keep the existing UUID, Reality public key, short ID, SNI/server name, fingerprint, and other VLESS parameters unchanged. Do not replace the primary profile. Label the duplicate as the Moscow backup and enable it only when needed.

## Rollback

Run from the repository root on Moscow:

```bash
sudo bash scripts/rollback_moscow_backup_relay.sh
```

The rollback restores the latest relay backup set, restores the previous enabled/active state, leaves Nginx untouched, and writes non-secret rollback evidence.

An explicit backup path may be supplied:

```bash
sudo bash scripts/rollback_moscow_backup_relay.sh /var/backups/vps-tier/moscow-backup-relay/apply/<UTC_ID>
```

## Acceptance criteria

- `vps-backup-relay.socket` is active and enabled.
- `tcp/8443` is listening on Moscow.
- Moscow can reach `194.32.142.88:443`.
- The backup client profile connects and exits through Kazakhstan.
- Existing Flowise HTTPS remains available.
- Existing primary Kazakhstan VPN profile remains unchanged and operational.
- Apply evidence is committed to GitHub.

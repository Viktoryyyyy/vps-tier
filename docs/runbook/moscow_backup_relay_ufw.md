# Moscow Backup Relay — Managed UFW Apply

## Purpose

Apply the Moscow backup VLESS TCP relay when UFW is active and `tcp/8443` is not yet allowed.

The wrapper manages one firewall rule only:

```text
allow 8443/tcp comment "vps-backup-relay"
```

It then calls the existing fail-closed relay apply script.

## Safety boundaries

- Hard-bound to Moscow IPv4 `147.45.184.140`.
- Does not modify Nginx, Flowise, Xray, Hysteria2, SSH, PostgreSQL, or Kazakhstan.
- Stops when any unmanaged UFW rule already references `8443/tcp`.
- Removes the newly added UFW rule automatically if relay apply fails.
- Records managed-rule ownership under `/var/lib/vps-tier/moscow-backup-relay/ufw-8443.created`.
- Rollback removes the UFW rule only when that ownership marker exists.

## Controlled apply

Run from the clean repository root on the Moscow server at the approved Git HEAD:

```bash
sudo bash scripts/apply_moscow_backup_relay_with_ufw.sh
```

Successful apply requires:

- UFW allows `8443/tcp`;
- `vps-backup-relay.socket` is enabled and active;
- Moscow listens on `tcp/8443`;
- Kazakhstan `194.32.142.88:443` is reachable;
- Nginx remains active and keeps the same MainPID.

## Controlled rollback

```bash
sudo bash scripts/rollback_moscow_backup_relay_with_ufw.sh
```

An explicit relay backup set may be passed as the first argument.

## Client profile

Duplicate the existing VLESS Reality profile and change only:

```text
Address: 147.45.184.140
Port: 8443
```

Keep the existing UUID, Reality public key, short ID, SNI/server name, fingerprint, and other VLESS parameters unchanged. The original Kazakhstan profile remains the primary profile.

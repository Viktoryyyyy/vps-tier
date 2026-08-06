# Moscow AmneziaWG Toolchain Installation

## Scope

This stage installs and validates the AmneziaWG 2 server toolchain on the Moscow VPS.

```text
HOST=147.45.184.140
OS=Ubuntu_24.04_Noble
PACKAGES=dkms,amneziawg,amneziawg-dkms
CLIENT_INTERFACE_CREATION=no
FIREWALL_CHANGE=no
FORWARDING_CHANGE=no
ROUTING_CHANGE=no
KAZAKHSTAN_CHANGE=no
```

The stage does not create an AWG interface, keys, client profile, UFW rule, policy route, NAT rule, or server-to-server backbone.

## Managed Artifacts

```text
scripts/apply_moscow_awg_toolchain.sh
scripts/rollback_moscow_awg_toolchain.sh
```

Runtime-owned artifacts after successful apply:

```text
/usr/share/keyrings/vps-tier-amnezia-archive-keyring.gpg
/etc/apt/sources.list.d/vps-tier-amnezia.sources
/var/lib/vps-tier/moscow-awg-toolchain/state.env
/var/lib/vps-tier/moscow-awg-toolchain/new-packages.txt
/var/backups/vps-tier/moscow-awg-toolchain/apply/<UTC_ID>
```

## Apply

Run only from a clean, synchronized `main` on the Moscow host:

```bash
sudo bash scripts/apply_moscow_awg_toolchain.sh
```

The script:

1. verifies Moscow host identity, Ubuntu Noble, amd64, running-kernel headers, clean Git state, protected services, and free `udp/443`;
2. runs the isolated package metadata probe;
3. verifies the approved Launchpad signing-key fingerprint;
4. adds a dedicated `signed-by` keyring and Deb822 APT source;
5. installs only task-owned packages without upgrading existing packages;
6. proves DKMS installation for the running kernel;
7. loads and unloads the `amneziawg` module without creating an interface;
8. proves firewall, forwarding, route state, protected services, and `udp/443` remain unchanged;
9. writes non-secret evidence under `docs/observed/analysis/`.

Any failure after mutation begins triggers automatic removal of task-created packages, source, keyring, and state files.

## Successful Output

Required terminal markers:

```text
DONE: Moscow AWG toolchain installed and validated
EVIDENCE_FILE=<path>
BACKUP_SET=<path>
AMNEZIAWG_VERSION=<version>
AMNEZIAWG_DKMS_VERSION=<version>
```

The generated evidence file must be committed through a separate evidence-only Git route.

## Rollback

Rollback is permitted only before an AWG interface is created:

```bash
sudo bash scripts/rollback_moscow_awg_toolchain.sh
```

Rollback removes exactly the package set absent before apply and created by the install transaction, then removes the managed APT source, keyring, and ownership state. It refuses to proceed while an AWG interface exists.

## Acceptance

```text
AWG_COMMAND=present
AWG_QUICK_COMMAND=present
AMNEZIAWG_MODULE=present_on_disk
DKMS_RUNNING_KERNEL=installed
MODULE_LOAD_UNLOAD_TEST=passed
AWG_INTERFACE=absent
UDP_443=unchanged_and_free
FIREWALL_FORWARDING_ROUTES=unchanged
PROTECTED_UNITS=active
SECRETS_IN_GIT=none
```

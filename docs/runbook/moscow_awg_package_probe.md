# Moscow AmneziaWG Package Metadata Probe

## Purpose

Inspect the approved Amnezia Launchpad PPA from the Moscow VPS before any package installation.

The probe verifies signing trust, package candidates, binary package identities, dependencies, DKMS source-tree presence, and package hashes. It does not install packages or create persistent APT configuration.

## Managed Artifact

```text
scripts/probe_moscow_awg_package_source.sh
```

Contract:

```text
contracts/two_hop_vpn/awg_package_probe_contract.md
```

## Safety Boundary

The script:

- is hard-bound to Moscow IPv4 `147.45.184.140`;
- requires Ubuntu Noble on `amd64`;
- requires a clean `main` checkout;
- uses a temporary GPG home, keyring, source list, APT lists, cache, and downloaded package directory;
- removes the temporary tree on exit;
- verifies that persistent `/etc/apt` source files remain unchanged;
- stops if Amnezia packages or a persistent Amnezia source already exist;
- does not run `apt install`, `dpkg -i`, `modprobe`, `awg`, `awg-quick`, `ip link`, `ufw`, `iptables`, `nft`, or routing commands.

## Controlled Execution

After the probe PR is merged and the local repository is synchronized to its approved `main` HEAD:

```bash
cd /home/trader/vps-backup-relay
sudo bash scripts/probe_moscow_awg_package_source.sh
```

The command uses network reads and temporary files only. It performs no package or network apply.

## Required Output

```text
SIGNING_KEY_FINGERPRINT=<exact approved fingerprint>
AMNEZIAWG_CANDIDATE=<version>
AMNEZIAWG_DKMS_CANDIDATE=<version>
AMNEZIAWG_SHA256=<sha256>
AMNEZIAWG_DKMS_SHA256=<sha256>
DEPENDENCY_REFERENCES_MODULE_PACKAGE=yes
DKMS_SOURCE_TREE_PRESENT=yes
PERSISTENT_APT_SOURCE_CHANGE=none
PACKAGE_INSTALLATION=none
MODULE_LOAD=none
INTERFACE_CREATION=none
FIREWALL_CHANGE=none
ROUTING_CHANGE=none
DONE: Moscow AWG package metadata probe completed
```

## Interpretation

A successful probe authorizes no installation. The returned candidate versions and hashes must be reviewed first.

A failed probe leaves the server package and network state unchanged. The failure must be investigated before any package installation task is created.

## Next Gate

Only after the exact candidates are reviewed may a separate Git-managed toolchain installation PR be prepared. That later stage must include:

- explicit package versions or reviewed candidate resolution;
- package-source backup and ownership tracking;
- DKMS build validation for the running kernel;
- module load test without interface creation;
- automatic rollback on package or DKMS failure;
- protected-service preservation checks;
- post-apply evidence.

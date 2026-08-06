# Moscow AmneziaWG Toolchain Preflight — Observed State

- Observation date: 2026-08-06
- Host role: planned client VPN termination
- Host public IPv4: `147.45.184.140`
- Runtime mutation in this preflight: none
- Package installation in this preflight: none
- Secrets recorded: none

## Host Baseline

```text
OS=ubuntu 24.04 noble
KERNEL=6.8.0-85-generic
ARCH=amd64
ROOT_DISK_SIZE=15G
ROOT_DISK_USED=75%
ROOT_DISK_AVAILABLE=3.8G
```

## Kernel Build Prerequisites

```text
HEADER_PACKAGE=linux-headers-6.8.0-85-generic
HEADERS_INSTALLED=yes
HEADER_VERSION=6.8.0-85.85
DKMS_INSTALLED=no
DKMS_APT_CANDIDATE=3.0.11-1ubuntu13
```

## AmneziaWG State

```text
AWG_COMMAND=absent
AWG_QUICK_COMMAND=absent
AWG_MODULE=absent
AMNEZIA_APT_SOURCE=absent
UDP_443_LISTENER=absent
```

## Interpretation

- The running kernel has matching headers installed.
- DKMS and AmneziaWG are not installed.
- No existing Amnezia package source was found.
- `udp/443` was free at observation time.
- The host has sufficient free disk for a controlled package-build attempt, subject to a separate apply gate.
- No conclusion about a successful DKMS module build is claimed until package installation and module validation are performed.

## Desired-State Reference

Client-ingress technology selection and package trust requirements are defined separately in:

```text
contracts/two_hop_vpn/client_ingress_technology_decision.md
```

This observed file is informational only and authorizes no runtime change.

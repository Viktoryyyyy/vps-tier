# Moscow AmneziaWG Package Metadata Probe Contract

## Purpose

Before any AmneziaWG package installation on the Moscow VPS, perform an isolated metadata probe against the approved Amnezia Launchpad PPA.

The probe exists because package publication does not prove that a DKMS build will succeed on the currently running kernel. Upstream issue history includes DKMS failures on Ubuntu 24.04 and modern kernels, including failures involving kernel `6.8.0-85-generic` in older package generations.

This stage therefore verifies package identity, signing trust, candidate versions, dependency linkage, and package contents without installing or loading anything.

## Scope

```text
HOST=Moscow
HOST_IPV4=147.45.184.140
OS=Ubuntu_24.04_Noble
ARCH=amd64
RUNNING_KERNEL=observed_at_execution
SOURCE_TYPE=temporary_isolated_APT_configuration
PERSISTENT_APT_CHANGE=forbidden
PACKAGE_INSTALLATION=forbidden
MODULE_LOAD=forbidden
INTERFACE_CREATION=forbidden
FIREWALL_CHANGE=forbidden
ROUTING_CHANGE=forbidden
NAT_CHANGE=forbidden
```

## Approved Source

```text
PPA_URI=https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu
PPA_SUITE=noble
PPA_COMPONENT=main
SIGNING_KEY_FINGERPRINT=75C9DD72C799870E310542E24166F2C257290828
KEY_LOOKUP=https://keyserver.ubuntu.com/
```

The probe must use an ephemeral keyring and an ephemeral APT state/cache tree. It must not add files under `/etc/apt`, import a key into a persistent system keyring, run `add-apt-repository`, or use `apt-key`.

## Package Identity

Required installable binary packages:

```text
amneziawg
amneziawg-dkms
```

Source-package distinction:

```text
SOURCE_PACKAGE_FOR_KERNEL_MODULE=amneziawg-linux-kmod
INSTALLABLE_BINARY_DKMS_PACKAGE=amneziawg-dkms
```

The source-package name must never be passed to `apt install`.

## Required Probe Checks

The probe must fail closed unless all of the following are true:

- execution occurs from a clean `main` checkout of the repository;
- the host owns public IPv4 `147.45.184.140`;
- OS ID is `ubuntu`, suite is `noble`, and architecture is `amd64`;
- matching headers for the running kernel are installed;
- no persistent Amnezia PPA source exists;
- `amneziawg` and `amneziawg-dkms` are not already installed;
- the retrieved signing key has exactly the approved fingerprint;
- the isolated PPA metadata publishes installable candidates for both binary packages;
- downloaded package identities match their expected names;
- the `amneziawg` package depends on `amneziawg-dkms` or a supported prebuilt module package;
- the DKMS package contains an expected `/usr/src/amneziawg-*` source tree;
- SHA-256 hashes of both downloaded packages are reported;
- persistent APT source files are byte-identical before and after the probe;
- package, module, interface, firewall, routing, and NAT state remain unchanged.

## Evidence Boundary

Allowed output:

- host identity, OS, suite, architecture, kernel, and headers package name;
- signing-key fingerprint;
- PPA URI, suite, and component;
- package candidate versions and architectures;
- SHA-256 package hashes;
- boolean dependency/source-tree checks;
- explicit `none` markers for mutations.

Forbidden output:

- private keys;
- client profiles;
- credential-bearing URLs;
- full GPG key material;
- system secrets;
- package payload contents beyond non-secret package metadata.

## Non-Guarantee

Successful metadata probing does not prove:

- DKMS compilation success;
- module load success;
- AWG 2 runtime compatibility;
- iPhone handshake success;
- routing or fail-closed correctness.

Those require later separately reviewed and authorized stages.

## Acceptance

```text
SIGNING_KEY_FINGERPRINT=exact_match
AMNEZIAWG_CANDIDATE=present
AMNEZIAWG_DKMS_CANDIDATE=present
PACKAGE_IDENTITIES=verified
DEPENDENCY_REFERENCES_MODULE_PACKAGE=yes
DKMS_SOURCE_TREE_PRESENT=yes
PACKAGE_HASHES=recorded
PERSISTENT_APT_SOURCE_CHANGE=none
PACKAGE_INSTALLATION=none
MODULE_LOAD=none
NETWORK_MUTATION=none
NEXT_STAGE=review_actual_candidates_before_toolchain_install
```

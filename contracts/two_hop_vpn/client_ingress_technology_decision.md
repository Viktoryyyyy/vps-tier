# Two-Hop VPN Client Ingress Technology Decision

## Status

```text
DECISION=accepted_for_implementation_planning
DECISION_DATE=2026-08-06
CLIENT_INGRESS_HOST=Moscow
CLIENT_INGRESS_TECHNOLOGY=AmneziaWG_2
CLIENT_INGRESS_TRANSPORT=udp/443
BACKBONE_TECHNOLOGY=standard_WireGuard
RUNTIME_APPLY_AUTHORIZED=no
```

This decision refines `contracts/two_hop_vpn/architecture_contract.md`. It authorizes planning and Git-managed implementation artifacts only. Package installation, kernel-module loading, interface creation, firewall changes, routing changes, key generation, and client-profile generation require later reviewed stages and explicit apply authority.

## Decision

Use AmneziaWG 2 for the iPhone-facing VPN endpoint on the Moscow VPS.

Use standard WireGuard for the dedicated Moscow-to-Kazakhstan backbone.

The two technologies have separate roles:

```text
iPhone -> AmneziaWG 2 on Moscow udp/443
Moscow -> standard WireGuard backbone -> Kazakhstan
Kazakhstan -> controlled NAT -> Internet
```

AmneziaWG is selected only for the access-network-facing client leg. The backbone remains standard WireGuard to minimize moving parts and keep server-to-server routing independent of client obfuscation parameters.

## Verified Upstream Support

Verification performed on 2026-08-06 against upstream project sources:

- the official `amneziawg-tools` repository publishes release `v1.0.20260223` and identifies it as the latest release;
- the release history includes AWG 2 support and later AWG 2 parameter fixes;
- the official Amnezia Launchpad PPA publishes Noble source packages `amneziawg` and `amneziawg-linux-kmod`;
- the installable binary package produced from `amneziawg-linux-kmod` is `amneziawg-dkms`;
- the `amneziawg` binary package depends on `amneziawg-dkms` or a compatible prebuilt module package;
- the official AmneziaWG iOS application reports AWG 2 support in the 2.x release line;
- the iOS application is available for iPhone and iPad.

Reference sources:

```text
https://github.com/amnezia-vpn/amneziawg-tools/releases
https://github.com/amnezia-vpn/amneziawg-tools
https://github.com/amnezia-vpn/amneziawg-linux-kernel-module
https://launchpad.net/~amnezia/+archive/ubuntu/ppa
https://launchpad.net/~amnezia/+ppa-packages
https://apps.apple.com/app/amneziawg/id6478942365
```

These are time-sensitive upstream facts. The implementation apply must re-check current package candidates and client compatibility before mutation.

## Moscow Preflight Result

Observed host prerequisites are recorded in:

```text
docs/observed/analysis/moscow_awg_toolchain_preflight_2026-08-06.md
```

Current planning inputs:

```text
OS=Ubuntu_24.04_Noble
KERNEL=6.8.0-85-generic
ARCH=amd64
MATCHING_KERNEL_HEADERS=installed
DKMS=absent
AMNEZIAWG_TOOLS=absent
AMNEZIAWG_KERNEL_MODULE=absent
AMNEZIA_PPA=absent
UDP_443=free_at_preflight
```

## Package Source Trust Contract

Approved upstream package source for the Moscow client-ingress implementation:

```text
SOURCE_TYPE=Launchpad_PPA
PPA=ppa:amnezia/ppa
DEB_URI=https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu
SUITE=noble
COMPONENT=main
SIGNING_KEY_FINGERPRINT=75C9DD72C799870E310542E24166F2C257290828
```

Planned installable binary packages:

```text
dkms
amneziawg
amneziawg-dkms
```

Package identity distinction:

```text
SOURCE_PACKAGE_FOR_KERNEL_MODULE=amneziawg-linux-kmod
INSTALLABLE_BINARY_DKMS_PACKAGE=amneziawg-dkms
```

The source-package name `amneziawg-linux-kmod` must not be passed to `apt install`.

The PPA is a third-party software source, not an Ubuntu archive component. The implementation must therefore fail closed unless it proves all of the following before installation:

- host identity is Moscow `147.45.184.140`;
- OS suite is exactly `noble` and architecture is `amd64`;
- running-kernel headers are installed;
- the imported signing key fingerprint exactly matches the approved fingerprint;
- the configured source URI, suite, and component exactly match this contract;
- `apt-cache policy` shows installable candidates for `amneziawg` and `amneziawg-dkms` from the approved source;
- package names and candidate versions are captured in non-secret pre-apply evidence;
- package metadata proves that the selected `amneziawg` package is compatible with the selected DKMS or module package;
- no existing Amnezia source or package ownership conflict exists.

Do not use `apt-key`. The later implementation must use a dedicated keyring and a source entry bound with `signed-by`.

## Version Policy

The planning baseline observed upstream on 2026-08-06 includes:

```text
AMNEZIAWG_TOOLS_RELEASE=v1.0.20260223
NOBLE_AMNEZIAWG_BUILD=20260223_generation
NOBLE_DKMS_SOURCE_BUILD=20260210_generation
IOS_APP_LINE=2.x_with_AWG2_support
```

Exact Debian package versions are not permanently pinned by this decision because the PPA may publish security or compatibility updates before apply. The implementation must record and review the actual candidate versions at execution time.

Automatic upgrades of the Amnezia packages must not be enabled implicitly. Upgrade policy requires a later explicit decision after initial stability is proven.

## Installation Boundary

The package-install stage may install and validate the toolchain only. It must not yet:

- create an AWG interface;
- write a private key or client profile;
- open `udp/443` in UFW;
- enable IPv4 forwarding;
- change policy routing;
- add NAT;
- alter a default route;
- restart SSH, Nginx, PostgreSQL, MOEX Bot, Flowise proxy, or the existing relay;
- change the Kazakhstan host.

The package stage must validate:

```text
DKMS_BUILD=current_kernel_pass
AMNEZIAWG_MODULE=present
AWG_COMMAND=present
AWG_QUICK_COMMAND=present
MODULE_LOAD_TEST=pass
UDP_443=still_free
PROTECTED_SERVICES=unchanged
REBOOT=not_required_by_task
```

Loading the module for validation is permitted only in the later explicitly authorized package apply. Creating a network interface is not permitted in that stage.

## Client Configuration Boundary

AWG 2 obfuscation parameters are not fixed in this decision.

They must be selected in a later client-ingress configuration PR and proven through an end-to-end iPhone-to-Moscow handshake before final acceptance. The configuration must remain compatible with the official AmneziaWG iOS client version used during acceptance.

Private keys, preshared keys, complete client profiles, and QR payloads remain outside Git and all evidence output.

## Rejected Alternatives

### Raw TCP relay

Rejected as the target client ingress because it does not terminate and re-originate the client VPN session on Moscow and did not provide a reliable usable path from the tested access network.

### Standard WireGuard on the client-facing leg

Not selected as the primary client ingress because the access-network requirement includes resistance to WireGuard traffic identification. Standard WireGuard remains appropriate for the controlled server-to-server backbone.

### Automatic server installation through the Amnezia application

Rejected for this project because it would not provide the required Git source of truth, reviewed diff, narrowly scoped apply, deterministic rollback, and post-apply evidence.

### Containerized all-in-one installation

Not selected because the project requires explicit host routing, fail-closed policy routing, UFW integration, and separation between client ingress and backbone stages.

## Rollback Contract For Package Stage

The later package-stage rollback must:

- remove only package-source and package artifacts created by that task;
- unload the module only when it was loaded by that task and no interface uses it;
- remove the dedicated keyring and source entry only when task ownership is proven;
- restore the prior package state from recorded evidence;
- leave all network interfaces, firewall rules, routes, NAT, and protected services unchanged;
- produce non-secret rollback evidence.

## Acceptance For This Decision Stage

```text
HOST_PREFLIGHT=recorded
UPSTREAM_SUPPORT=verified_as_of_2026-08-06
CLIENT_INGRESS_TECHNOLOGY=AmneziaWG_2
BACKBONE_TECHNOLOGY=standard_WireGuard
PACKAGE_SOURCE_TRUST_BOUNDARY=defined
INSTALLABLE_DKMS_PACKAGE=amneziawg-dkms
PACKAGE_APPLY_SCOPE=toolchain_only
RUNTIME_MUTATION=none
SECRETS_IN_GIT=none
NEXT_STAGE=Git_managed_Moscow_AWG_toolchain_install_and_rollback_artifacts
```

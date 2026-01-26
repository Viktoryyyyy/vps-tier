# Observed Snapshot Checklist v1

## 1. Purpose & Scope

This document defines the **canonical observed-state snapshot** for the VPS Tier-1 project.

The observed snapshot is:
- **read-only**
- **fact-based**
- **non-authoritative**

Its sole purpose is to capture a reproducible snapshot of the *actual server state*
at a given point in time for:
- debugging
- audits
- regression comparison

This document defines **what must be captured**, **how it is classified**, and
**how it is stored in GitHub**.

---

## 2. Non-Goals (Explicit)

The observed snapshot:
- does NOT define desired state
- does NOT replace Git-managed configuration
- does NOT apply changes
- does NOT perform tuning or debugging
- does NOT collect secrets, private keys, or credentials

---

## 3. Definitions

### Managed
State that is **explicitly controlled and versioned in GitHub**.
Examples: systemd unit files, scripts, repository files.

### Observed-only
State that is **read from the server** for informational purposes only.
It never overrides or defines managed state.

### Classification

- **static** — expected to remain stable until an intentional change
- **runtime** — reflects current live state at capture time
- **counters** — expected to change continuously (uptime, load, traffic)

---

## 4. Observed Snapshot Checklist v1

### A. Identity & Time Baseline (observed-only)

| Item | Description | Rationale | Classification |
|-----|------------|-----------|----------------|
| OS / Kernel | OS name, version, kernel, architecture | Reproducible platform baseline | static |
| Time config | Timezone, NTP sync, current UTC time | Correct interpretation of logs & timers | runtime |

---

### B. Service Control Plane (systemd)

| Item | Description | Rationale | Classification | State |
|-----|------------|-----------|----------------|-------|
| Unit enablement | enabled/disabled for core services & timers | Detect boot/start regressions | runtime | observed-only |
| Unit status | active/inactive, last start | First-order failure evidence | runtime | observed-only |
| Unit inventory | List of Git-tracked unit files | Bind runtime to managed config | static | managed |
| Recent logs | Tail of unit journals (bounded) | Baseline error/regression context | runtime | observed-only |

---

### C. Processes & Ports (observed-only)

| Item | Description | Rationale | Classification |
|-----|------------|-----------|----------------|
| Listening sockets | TCP/UDP listeners with process names | Validate exposed services | runtime |
| Process snapshot | PID, uptime, resource usage for key daemons | Detect zombie / duplicate processes | runtime |

---

### D. Networking Baseline (observed-only)

| Item | Description | Rationale | Classification |
|-----|------------|-----------|----------------|
| Interfaces | Addresses, MTU, link state | Explain reachability issues | runtime |
| Routes | Default + main routes | Connectivity sanity check | runtime |
| DNS | Resolver configuration & status | Domain resolution issues | runtime |
| Public IP | Observed external IP | Client-facing baseline | runtime |

---

### E. Firewall / Packet Filter Posture (observed-only)

| Item | Description | Rationale | Classification |
|-----|------------|-----------|----------------|
| Firewall status | ufw / iptables / nft summary | Port reachability context | runtime |

---

### F. TLS / Certificates (metadata only)

| Item | Description | Rationale | Classification |
|-----|------------|-----------|----------------|
| Cert metadata | Domains & expiry dates only | Prevent silent expiration | counters |

---

### G. Resources & Storage (observed-only)

| Item | Description | Rationale | Classification |
|-----|------------|-----------|----------------|
| Disk usage | Space & inode usage | Detect capacity regressions | counters |
| Memory & load | Load, RAM, swap | Performance baseline | counters |

---

### H. Monitoring Layer Evidence

| Item | Description | Rationale | Classification | State |
|-----|------------|-----------|----------------|-------|
| Managed scripts | Presence of monitoring scripts in Git | Bind alerts to versioned logic | static | managed |
| Timer cadence | Last / next run times | Validate monitoring loop | runtime | observed-only |

---

## 5. Snapshot Artifact Layout

All observed snapshots are committed under:

docs/observed/snapshots/<YYYY-MM-DD>/<HHMMSSZ>/

Required files:
meta.md
identity.txt
time.txt
systemd_units.txt
systemd_timers.txt
journals_xray_tail.txt
journals_nginx_tail.txt
journals_tg_bot_tail.txt
sockets.txt
processes.txt
net_ifaces.txt
net_routes.txt
dns.txt
firewall_summary.txt
disk.txt
resources.txt
certs_metadata.txt

---

## 6. Read-only Command Set (DRAFT)

Commands listed here are **not approved for execution by default**.

uname -a
lsb_release -a
cat /etc/os-release
timedatectl status
date -u

systemctl is-enabled xray nginx tg-bot tier1-health.timer tier1-alert.timer
systemctl status xray nginx tg-bot tier1-health.timer tier1-alert.timer --no-pager
systemctl list-timers --all --no-pager

journalctl -u xray -n 200 --no-pager
journalctl -u nginx -n 200 --no-pager
journalctl -u tg-bot -n 200 --no-pager

ss -lntup
ps -eo pid,ppid,cmd,etimes,%cpu,%mem

ip addr
ip route
resolvectl status

ufw status verbose
iptables -S
nft list ruleset

df -h
df -i
free -h
uptime

certbot certificates
curl -4 -s ifconfig.me

---

## 7. Explicit Restrictions

- No secrets or private material may be captured
- No configuration dumps unless explicitly approved
- nginx -T is forbidden by default
- Observed artifacts never redefine managed state

End of document.

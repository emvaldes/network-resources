# Installation and Quick Start Guide

Welcome to the IP Address Inventory & Classification Tool.
This guide walks you through cloning, setting up, and running the project for the first time.

---

## Prerequisites

Ensure the following are available on your system:

- **bash** (POSIX-compliant Shell)
- **jq** (for JSON parsing and formatting)

### Install `jq` if missing:

**Ubuntu/Debian:**
```bash
> sudo apt update --yes ;
> sudo apt install jq --yes ;
```

**MacOS (with Homebrew):**
```bash
> brew install jq ;
```

---

## Clone the Repository

```bash
> git clone https://github.com/emvaldes/network-resources.git ;
> cd network-resources ;
```

---

## Prepare Directory Structure

Ensure the following folders/files exist:

```text
configs/        # Vendor configs to parse
scripts/        # All Shell scripts
ips.list        # List of target IP addresses
matrix.json     # Business unit classification rules
```

**Note:**
The `reports/` folder and `reports.json` will be automatically generated during execution.

---

## Quick Start - Parsing and Reporting

**Parse all IPs in parallel:**

```bash
> ./scripts/parse-listing.shell ips.list "conf config cnf" matrix.json 10
```

- 10 = number of concurrent threads (can adjust based on system).

---

## Outputs

| File | Description |
|:---|:---|
| reports/ | Per-IP JSON reports |
| reports/reports.json | Unified master report |
| reports/reports.csv | CSV for management review |

---

## Troubleshooting

| Issue | Solution |
|:---|:---|
| jq not found | Install jq using package manager (see prerequisites) |
| Permission denied on scripts | Run `> chmod +x scripts/*.shell ;` |
| Unexpected parsing errors | Validate that configs follow structured syntax (blocks or objects) |

---

## Further Reading

- [README.md](./docs/README.md) — Full detailed documentation
- [LICENSE](./docs/LICENSE) — License terms (if applicable)

---

Your environment is now ready.
Happy inventorying!

---

# This `INSTALL.md` is clean, simple, professional, and GitHub-ready.
It complements the `README.md` and makes onboarding much faster.

---

# With This:

| Document | Status |
|:---|:---|
| `README.md` | Full technical guide |
| `./docs/INSTALL.md` | Quick setup guide |
| `.gitignore` | Clean repository management |

---

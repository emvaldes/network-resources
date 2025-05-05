# IP Address Inventory & Classification Tool

A scalable, shell-based solution to parse, classify, and report on IP addresses found inside multi-vendor network configuration files.
Designed for flexibility, parallel execution, structured output, and ease of management reporting.

---

## Table of Contents

* [1. Introduction](#1-introduction)
* [2. Architecture Overview](#2-architecture-overview)
* [3. Components](#3-components)
* [4. Workflow Overview](#4-workflow-overview)
* [5. Preparing Inputs](#5-preparing-inputs)
* [6. Parsing a Single IP Address (parse-configs.shell)](#6-parsing-a-single-ip-address-parse-configsshell)
* [7. Parsing All IPs in Parallel (parse-listings.shell)](#7-parsing-all-ips-in-parallel-parse-listingsshell)
* [8. Outputs and Reports](#8-outputs-and-reports)
* [9. Source of Truth: reports.json](#9-source-of-truth-reportsjson)
* [10. Error Handling and Best Practices](#10-error-handling-and-best-practices)
* [11. Extensibility and Future Enhancements](#11-extensibility-and-future-enhancements)
* [12. Limitations and Assumptions](#12-limitations-and-assumptions)
* [13. Conclusion](#14-conclusion)
* [14. Folder Layout](#15-folder-layout)
* [15. Execution Flow Overview](#16-execution-flow-overview)
* [16. Failure Handling Overview](#17-failure-handling-overview)
* [17. Operator Post-Run Checklist](#18-operator-post-run-checklist)
* [18. Example JSON Object for Parsed IP](#19-example-json-object-for-parsed-ip)
* [19. Example JSON Object for Fallback-Only Match](#20-example-json-object-for-fallback-only-match)

---

## 1. Introduction

Managing IP address space across diverse network infrastructures is critical for operations, asset tracking, and cost optimization.
This tool automates the inventory of IP addresses from raw configuration files, associates them with business units via a dynamic classification matrix, and produces structured reports.

**Features:**

* Full Shell implementation (POSIX-compliant)
* Vendor-agnostic (Cisco, Fortinet, Palo Alto, Juniper, F5, etc.)
* Parallel processing for large datasets
* Structured outputs in JSON and CSV formats
* Easy integration into reporting workflows

---

## 2. Architecture Overview

The system is modular and separated into logical stages:

* **Parsing Layer**: Reads configs, collapses structured blocks, matches IPs.
* **Classification Layer**: Associates blocks with business units using a translation matrix.
* **Reporting Layer**: Generates per-IP JSON files and aggregates into `reports.json`.
* **Exporting Layer**: Automatically produces a final CSV file (`reports.csv`) for business usage.

**Design Principles:**

* **Atomicity**: Each IP generates its own isolated result file.
* **Parallelization**: Each IP is processed independently and concurrently.
* **Single Source of Truth**: `reports.json` is the only master file after parsing.

---

## 3. Components

| Component              | Purpose                                                                            |
| :--------------------- | :--------------------------------------------------------------------------------- |
| `parse-configs.shell`  | Parses a single IP address, generates `reports/<ip>.json`.                         |
| `parse-listings.shell` | Parses all IPs in parallel, aggregates into `reports.json`, exports `reports.csv`. |
| `matrix.json`          | User-defined classification rules.                                                 |
| `ips.list`             | List of IP addresses to find.                                                      |
| `configs/`             | Raw network configuration files.                                                   |
| `reports/`             | Output folder for per-IP JSON files, aggregated reports.                           |

---

## 4. Workflow Overview

```text
./scripts/parse-listings.shell -> ./scripts/parse-configs.shell --> reports/*.json
                                  \
                                   --> aggregation --> reports/reports.json
                                   --> export CSV --> reports/reports.csv
```

### CSV Report Summary (tabulated):

| target | config | object | entry | description | caption |
| :- | :- | :- | :- | :- | :- |
| 10.0.0.1 | cisco/fw1.cfg | object-group network BU1-NETWORK | network-object host 10.0.0.1 | Corporate HQ Subnets | Identified Matching Entries |
| 10.0.0.1 | cisco/fw1.cfg | access-list OUTSIDE extended permit ip host 10.0.0.1 any | none | none | cisco/fw1.cfg |
| 10.0.0.1 | misc/switch.conf | object-group network SOME-THING | network-object host 10.0.0.1 | Local Office Subnets | Identified Matching Entries |
| 10.0.1.2 | cisco/fw1.cfg | object-group network BU1-NETWORK | network-object host 10.0.1.2 | Corporate HQ Subnets | Identified Matching Entries |
| 10.0.1.2 | misc/switch.conf | interface Vlan2 | ip address 10.0.1.2 255.255.255.0 | none | Business-Unit-Networks |
| 172.31.255.254 | misc/switch.conf | interface Vlan1 | ip address 172.31.255.254 255.255.255.0 | none | Business-Unit-Networks |
| 192.168.1.10 | cisco/fw1.cfg | object network Server-192-168-1-10 | host 192.168.1.10 | Main Application Server | Business-Unit-HQ |
| 203.0.113.25 | cisco/fw1.cfg | object network External-203-0-113-25 | host 203.0.113.25 | none | Business-Unit-External |

Data flows from configuration parsing into structured reports automatically.

---

## 5. Preparing Inputs

### 5.1 IP Address List (`ips.list`)

Example:

```
10.0.0.1
10.0.1.2
10.0.2.3
192.168.1.10
192.168.1.11
192.168.2.12
172.16.0.5
172.16.1.6
192.0.2.50
203.0.113.25
198.51.100.75
172.18.1.20
10.10.10.10
192.168.100.100
172.31.255.254
```

---

### 5.2 Translation Matrix (`matrix.json`)

Example:

```json
[
    {
        "match": ["BU1-NETWORK", "SOME-THING"],
        "caption": "Identified Matching Entries"
    },
    {
        "match": ["BU1-NETWORK", "Corporate HQ Subnets"],
        "caption": "Business-Unit-HQ"
    },
    {
        "match": ["Remote-Site-Office", "All-Offices"],
        "caption": "Business-Unit-Remote"
    }
]
```

* `match[]`: List of object names or descriptions to match.
* `caption`: Business unit identifier.

If a block's `name` or `description` matches a string from `match[]`, the IP is classified accordingly.

---

## 6. Parsing a Single IP Address (`parse-configs.shell`)

Command:

```bash
> ./scripts/parse-configs.shell --configs="configs" \
                                --file-ext="cfg" \
                                --index="  --> " \
                                --ip-addr="10.0.0.1" \
                                --matrix="matrix.json" \
                                --reports="reports" \
  ;
```

Behavior:

* Parses all configs for a given IP.
* Extracts block metadata (name, description).
* Matches against classification matrix.
* Falls back to using file path if no matrix match exists.
* Outputs a prettified, structured JSON file: `reports/10.0.0.1.json`.

---

## 7. Parsing All IPs in Parallel (`parse-listings.shell`)

Command:

```bash
# Step 1: Parse all IPs in parallel
> ./scripts/parse-listings.shell --configs="configs" \
                                 --file-ext="cfg, conf, cnf" \
                                 --interval=0.05
                                 --ips-list="ips.list" \
                                 --jobs=10 ;
                                 --matrix="matrix.json" \
                                 --reports="reports" \
  ;
```

Results:

* `reports/reports.json` → Master data aggregation
* `reports/reports.csv` → Final CSV export for business reporting

No further manual steps required.

Behavior:

* Parses all IPs in parallel (default 10 workers).
* Each IP generates `reports/<ip>.json`.
* After parsing all IPs:

  * Merges results into `reports/reports.json`.
  * Exports final `reports/reports.csv`.

---

## 8. Outputs and Reports

| Output                 | Purpose                                              |
| :--------------------- | :--------------------------------------------------- |
| `reports/<ip>.json`    | Individual structured results per IP address.        |
| `reports/reports.json` | Aggregated master dataset (Source of Truth).         |
| `reports/reports.csv`  | Final CSV export ready for Excel or reporting tools. |

No unnecessary `.txt` files.
No split exports.

---

## 9. Source of Truth: `reports.json`

* Aggregated from all per-IP JSON files.
* Single source for downstream reporting.
* Structured, prettified JSON array of IP match objects.

Maintaining `reports.json` integrity is critical for the reliability of the final CSV export.

---

## 10. Error Handling and Best Practices

* Always ensure `jq` is installed (`sudo apt install jq` or `brew install jq`).
* Always clean up old `reports/*.json` and `reports/*.csv` before new batch runs (optional but recommended).
* Monitor system limits (`ulimit -n`) if processing very large IP lists.
* Watch parallelism settings (10 workers is a safe default for normal environments).

---

## 11. Extensibility and Future Enhancements

| Feature                               | Benefit                                               |
| :------------------------------------ | :---------------------------------------------------- |
| Regex matching for translation matrix | Match more flexible patterns beyond exact strings.    |
| Native XLSX export                    | Produce true Excel files directly.                    |
| Web-based visualization dashboard     | Real-time visibility into parsing and classification. |
| CLI flag enhancements                 | Advanced filtering or target selection.               |

---

## 12. Limitations and Assumptions

| Limitation                             | Note                                                                 |
| :------------------------------------- | :------------------------------------------------------------------- |
| Very large configuration files (>20MB) | May require increasing available system resources.                   |
| Matrix maintenance                     | End-users must keep `matrix.json` updated with relevant mappings.    |
| Syntax expectations                    | Config files must retain some block/object structure.                |
| Flat entries                           | IPs not inside blocks are supported, but will have limited metadata. |

---

## 13. Conclusion

This tool provides a **professional**, **extensible**, and **production-ready** method for:

* IP address discovery across mixed-vendor infrastructures
* Business unit classification
* Automated reporting

Built with a focus on **portability**, **scalability**, and **traceability**,
it is ideal for **infrastructure audits**, **decommissioning projects**, and **cost-optimization initiatives**.

---

## 14. Folder Layout

```text
project-root/
├── .gitignore
├── configs/
│   ├── cisco/
│   │   └── fw1.cfg
│   ├── f5/
│   │   └── bigip1.ignore
│   ├── fortinet/
│   │   └── fw2.ignore
│   ├── juniper/
│   │   └── srx1.ignore
│   ├── misc/
│   │   └── switch.conf
│   └── paloalto/
│       └── pa1.ignore
├── docs/
│   ├── CONTRIBUTING.md
│   └── INSTALL.md
├── ips.list
├── LICENSE
├── matrix.json
├── random.list
├── README.md
├── reports/
│   ├── json/
│   │   ├── 10.0.0.1.json
│   │   ├── 10.0.1.2.json
│   │   ├── 172.31.255.254.json
│   │   ├── 192.168.1.10.json
│   │   └── 203.0.113.25.json
│   ├── lists/
│   │   ├── 10.0.0.1.list
│   │   ├── 10.0.1.2.list
│   │   ├── 172.31.255.254.list
│   │   ├── 192.168.1.10.list
│   │   └── 203.0.113.25.list
│   ├── reports.csv
│   ├── reports.json
│   └── reports.log
└── scripts/
    ├── devops-tools.shell*
    ├── parse-configs.shell*
    └── parse-listings.shell*

13 directories, 30 files
```

---

## 15. Execution Flow Overview

1. Load IPs from `ips.list`.
2. Load configurations from `configs/`.
3. Parse all IPs in parallel using `parse-listings.shell`.
4. Aggregate per-IP JSON files into `reports/reports.json`.
5. Export final structured CSV file `reports/reports.csv`.
6. Deliver outputs for business reporting.

---

## 16. Failure Handling Overview

* Missing input files → Immediate error and stop.
* No configs found → Warning; continue.
* IP not found → Empty result file created.
* Partial configs → Attempt partial parsing; proceed.
* Aggregation failure → Stop and alert.
* Export failure → Leave `reports.json` intact.

---

## 17. Operator Post-Run Checklist

* Confirm successful parsing (no critical errors).
* Validate that `reports/reports.json` and `reports/reports.csv` exist.
* Open `reports/reports.csv` and verify basic content structure.
* Sanity-check a few sample IPs and classifications.
* Archive execution logs if needed.

---

## 18. Example JSON Object for Parsed IP

```bash
Source Configuration files:
  - configs/cisco/fw1.cfg
  - configs/misc/switch.conf

(01) Valid IP Address: 10.0.0.1

Config: configs/cisco/fw1.cfg

object-group network BU1-NETWORK
 description Corporate HQ Subnets
 network-object host 10.0.0.1
 network-object host 10.0.1.2
 network-object 192.168.1.0 255.255.255.0

access-list OUTSIDE extended permit ip host 10.0.0.1 any

Config: configs/misc/switch.conf

object-group network SOME-THING
  description Local Office Subnets
  network-object host 10.0.0.1
  network-object 192.168.12.0 255.255.255.0
```

```json
{
  "target": "10.0.0.1",
  "configs": [
    {
      "config": "configs/cisco/fw1.cfg",
      "objects": [
        {
          "object": "object-group network BU1-NETWORK",
          "entry": "network-object host 10.0.0.1",
          "description": "Corporate HQ Subnets",
          "caption": "Identified Matching Entries"
        },
        {
          "object": "access-list OUTSIDE extended permit ip host 10.0.0.1 any",
          "entry": false,
          "description": false,
          "caption": "cisco/fw1.cfg"
        }
      ]
    },
    {
      "config": "configs/misc/switch.conf",
      "objects": [
        {
          "object": "object-group network SOME-THING",
          "entry": "network-object host 10.0.0.1",
          "description": "Local Office Subnets",
          "caption": "Identified Matching Entries"
        }
      ]
    }
  ]
}
```

### Field Definitions

| Field         | Description                                                                               |
| :------------ | :---------------------------------------------------------------------------------------- |
| `target`      | The IP address being analyzed.                                                            |
| `configs`     | List of configuration files where this IP was found.                                      |
| `config`      | The path to the specific configuration file.                                              |
| `objects`     | List of matched blocks/objects inside the config.                                         |
| `type`        | Type of network object (e.g., `object network`, `object-group network`, `address`, etc.). |
| `name`        | Name of the object (false if missing).                                                    |
| `description` | Description attached to the object (false if missing).                                    |
| `caption`     | Business classification according to the translation matrix or file-path fallback.        |

---

## 19. Example JSON Object for Fallback-Only Match

```bash
Source Configuration files:
  - configs/cisco/fw1.cfg
  - configs/misc/switch.conf

(02) Valid IP Address: 10.0.1.2

Config: configs/cisco/fw1.cfg

object-group network BU1-NETWORK
 description Corporate HQ Subnets
 network-object host 10.0.0.1
 network-object host 10.0.1.2
 network-object 192.168.1.0 255.255.255.0

Config: configs/misc/switch.conf

interface Vlan2
 ip address 10.0.1.2 255.255.255.0
```

```json
{
  "target": "10.0.1.2",
  "configs": [
    {
      "config": "configs/cisco/fw1.cfg",
      "objects": [
        {
          "object": "object-group network BU1-NETWORK",
          "entry": "network-object host 10.0.1.2",
          "description": "Corporate HQ Subnets",
          "caption": "Identified Matching Entries"
        }
      ]
    },
    {
      "config": "configs/misc/switch.conf",
      "objects": [
        {
          "object": "interface Vlan2",
          "entry": "ip address 10.0.1.2 255.255.255.0",
          "description": false,
          "caption": "Business-Unit-Networks"
        }
      ]
    }
  ]
}
```

### Field Definitions for Fallback Match

| Field         | Description                                                         |
| :------------ | :------------------------------------------------------------------ |
| `target`      | The IP address that was found.                                      |
| `configs`     | List of configuration files where this IP was detected.             |
| `config`      | Path to the config file that matched the IP.                        |
| `objects`     | Minimal metadata block.                                             |
| `type`        | Set to `"raw match"` to indicate no structured block was available. |
| `name`        | `false`, meaning no object name was detected.                       |
| `description` | `false`, meaning no description was detected.                       |
| `caption`     | Set to the file path where the IP was found, serving as fallback.   |

---

### Important Notes

* Fallback matches ensure **no IP is lost** even when minimal information is available.
* This allows post-processing or manual classification based on file structure later.
* Maintains consistency by ensuring every IP listed always generates a valid JSON object.

Even minimal matches are **tracked, reported, and available** for future decision-making.

---

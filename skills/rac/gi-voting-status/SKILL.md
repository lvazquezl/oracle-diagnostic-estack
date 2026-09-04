---
name: gi-voting-status
id: rac/gi-voting-status
version: 1.0.0
domain: rac
status: active
---

# Purpose

Visibilidad y placement de voting disks (`crsctl query css votedisk`) — sólo status/placement/basic health; nunca add/remove/replace (`# 37` del prompt de Fase 4).

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

Ninguno.

# Required evidence

- collector `get_voting_status` (`crsctl query css votedisk`)

# Optional evidence

Ninguna.

# Read-only operations

Ejecución allowlisted de `crsctl query css votedisk`.

# Forbidden operations

No agrega/quita/reemplaza voting disks. `INSUFFICIENT_PRIVILEGES` + `MANUAL COLLECTION INSTRUCTION` si el privilegio no está disponible.

# Decision logic

1. Leer número y ubicación de voting disks, y su estado reportado.
2. Menos voting disks de los esperados por la redundancia declarada (quorum en riesgo) → `CRITICAL`, correlacionar con `rac/instance-eviction` (voting disk I/O es una causa conocida de eviction).

# Confidence model

`FACT` para el estado leído directamente.

# Output schema

```yaml
findings:
  - voting_status: KNOWN|UNKNOWN|INSUFFICIENT_PRIVILEGES
    voting_disks: [{location: string, status: string}]|null
    quorum_at_risk: bool
    evidence_refs: [EVD-...]
```

# Related skills

`rac/gi-ocr-status`, `rac/instance-eviction`.

# Escalation

Quorum en riesgo → `incident-root-cause-analyst`, severity `CRITICAL`, inmediato.

# Data sensitivity

Media — paths enmascarados por defecto.

# Context budget

Bajo.

# Tests

`tests/test_voting_parser.sh`, `tests/test_no_voting_change.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `rac-topology.md`.

# Evolution via `/change`

N/A — comando estable desde 11gR2.

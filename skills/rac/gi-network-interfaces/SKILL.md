---
name: gi-network-interfaces
id: rac/gi-network-interfaces
version: 1.0.0
domain: rac
status: active
---

# Purpose

Leer la clasificación de interfaces de red declarada a GI (`oifcfg getif`: pública/privada/ASM) — base de configuración para `rac/interconnect`.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

Ninguno.

# Required evidence

- collector `get_network_configuration` (`oifcfg getif`)

# Optional evidence

Ninguna.

# Read-only operations

Ejecución allowlisted de `oifcfg getif`.

# Forbidden operations

No modifica configuración de interfaz (`oifcfg setif`/`delif` prohibidos).

# Decision logic

1. Listar interfaces declaradas con su clasificación (`public`/`cluster_interconnect`/`asm`).
2. Publicar esta clasificación para que `rac/interconnect` la cruce contra `GV$CLUSTER_INTERCONNECTS`.

# Confidence model

`FACT` para la configuración declarada leída directamente.

# Output schema

```yaml
findings:
  - interface: string
    subnet: string
    classification: public|cluster_interconnect|asm
    evidence_refs: [EVD-...]
```

# Related skills

`rac/interconnect`, `rac/gi-vip`.

# Escalation

Ninguna propia — alimenta `rac/interconnect`.

# Data sensitivity

Alta — subnets/interfaces se enmascaran por defecto.

# Context budget

Bajo.

# Tests

`tests/test_no_network_change.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `rac-topology.md`.

# Evolution via `/change`

N/A — comando estable desde 11gR2.

---
name: healthcheck
id: asm/healthcheck
version: 1.0.0
domain: asm
status: active
---

# Purpose

Orquestar `/healthcheck asm` (`# 40` del prompt de Fase 4): estado ASM, diskgroups, capacidad, redundancia, discos, operaciones, rebalance y warnings.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

Standalone y RAC.

# Prerequisites

Target Profile con `storage_mode = asm`.

# Required evidence

- Evidencia agregada de `asm/instances`, `asm/diskgroups`, `asm/capacity`, `asm/redundancy`, `asm/disks`, `asm/rebalance`.

# Optional evidence

Ninguna adicional.

# Read-only operations

Orquesta lecturas ya cubiertas por los skills subordinados.

# Forbidden operations

No ejecuta ninguna acción correctiva.

# Decision logic

1. Ejecutar cada skill subordinado en secuencia.
2. Consolidar en un `ASM HEALTH` único (`HEALTHY|DEGRADED|WARNING|CRITICAL|UNKNOWN`) para que `rac/healthcheck` lo consuma por referencia cuando se invoca desde el healthcheck de cluster completo.

# Confidence model

Hereda el `confidence` de cada skill subordinado.

# Output schema

```yaml
findings:
  - dimension: TOPOLOGY|CAPACITY|REDUNDANCY|DISKS|REBALANCE
    status: HEALTHY|DEGRADED|WARNING|CRITICAL|UNKNOWN
    evidence_refs: [EVD-...]
```

# Related skills

`asm/diskgroups`, `asm/capacity`, `asm/redundancy`, `asm/disks`, `asm/rebalance`, `rac/healthcheck`.

# Escalation

Cualquier dimensión `CRITICAL` → `incident-root-cause-analyst`.

# Data sensitivity

Media.

# Context budget

Alta — se resume por dimensión.

# Tests

`tests/test_asm_healthcheck.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Genera el healthcheck en Markdown vía `technical-documentation-manager`.

# Evolution via `/change`

Nuevas dimensiones vía `/change workflow`.

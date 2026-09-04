---
name: failure-groups
id: asm/failure-groups
version: 1.0.0
domain: asm
status: active
---

# Purpose

Agrupar discos por `FAILGROUP` y validar que la distribución sea consistente con la redundancia declarada (ej. `NORMAL` requiere ≥2 failure groups con capacidad equivalente).

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

Standalone y RAC.

# Prerequisites

`asm/disks` y `asm/redundancy` resueltos.

# Required evidence

- `Q-ASM-DISKS-001` (`V$ASM_DISK.FAILGROUP`)

# Optional evidence

Ninguna.

# Read-only operations

Lectura de `V$ASM_DISK`.

# Forbidden operations

No modifica failure groups.

# Decision logic

1. Agrupar discos por `FAILGROUP` dentro de cada disk group.
2. Failure groups con capacidad significativamente desigual → observación de imbalance (candidato a `asm/rebalance` si ASM ya lo está corrigiendo).
3. Menos failure groups de los que la redundancia declarada requiere → `HIGH` (riesgo de pérdida de redundancia real).

# Confidence model

`FACT` para la agrupación leída directamente. `OBSERVATION` para imbalance entre failure groups.

# Output schema

```yaml
findings:
  - diskgroup: string
    failgroup: string
    disk_count: number
    total_mb: number
    evidence_refs: [EVD-...]
```

# Related skills

`asm/disks`, `asm/redundancy`.

# Escalation

Failure groups insuficientes para la redundancia declarada → `change-advisor`.

# Data sensitivity

Media.

# Context budget

Bajo.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `asm-analysis.md`.

# Evolution via `/change`

N/A — vista estable desde 11gR2.

---
name: operations
id: asm/operations
version: 1.0.0
domain: asm
status: active
---

# Purpose

Visibilidad de cualquier operación ASM en curso (`REBAL`, `COMPACT`, `RESYNC`), no sólo rebalance — `asm/rebalance` es el caso específico más común; este skill cubre el resto de tipos de `V$ASM_OPERATION.OPERATION`.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

Standalone y RAC.

# Prerequisites

`asm/diskgroups` resuelto.

# Required evidence

- `Q-ASM-REBALANCE-001` (mismo origen que `asm/rebalance`, sin filtrar por tipo de operación).

# Optional evidence

Ninguna.

# Read-only operations

Lectura de `V$ASM_OPERATION`/`GV$ASM_OPERATION`.

# Forbidden operations

No inicia ninguna operación ASM.

# Decision logic

1. Listar todas las operaciones activas por tipo (`REBAL`/`COMPACT`/`RESYNC`).
2. `RESYNC` activo sin evento de disco reincorporado conocido → observación, correlacionar con `asm/disks`.

# Confidence model

`FACT` para el tipo/progreso leído directamente.

# Output schema

```yaml
findings:
  - diskgroup: string
    operation_type: string
    state: string
    evidence_refs: [EVD-...]
```

# Related skills

`asm/rebalance`, `asm/diskgroups`.

# Escalation

`RESYNC` inesperado → correlacionar con `asm/disks` antes de escalar.

# Data sensitivity

Baja.

# Context budget

Bajo.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `asm-analysis.md`.

# Evolution via `/change`

N/A — vista estable desde 11gR2.

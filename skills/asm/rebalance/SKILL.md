---
name: rebalance
id: asm/rebalance
version: 1.0.0
domain: asm
status: active
---

# Purpose

Visibilidad de operaciones de rebalance en curso vía `V$ASM_OPERATION`/`GV$ASM_OPERATION` — extrae `operation`, `state`, `power`, `actual`, `sofar`, `est_work`, `est_rate`, `est_minutes` (`# 27` del prompt de Fase 4). Nunca cambia `POWER`.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

Standalone y RAC (en RAC, rebalance puede reportarse por instancia ASM).

# Prerequisites

`asm/diskgroups` resuelto.

# Required evidence

- `Q-ASM-REBALANCE-001` (`V$ASM_OPERATION`/`GV$ASM_OPERATION`)

# Optional evidence

Ninguna — para correlacionar impacto en I/O de producción, delegar a `performance/io` vía `oracle-performance-analyst`.

# Read-only operations

Lectura de `V$ASM_OPERATION`/`GV$ASM_OPERATION`.

# Forbidden operations

No inicia/detiene rebalance, no cambia `POWER`.

# Decision logic

1. Si no hay operación activa, reportar `no_active_rebalance: true` — no es un finding, es el estado normal.
2. Si hay rebalance activo, extraer progreso (`sofar`/`est_work`) y tiempo estimado restante (`est_minutes`).
3. Informar impacto potencial en I/O — nunca asumir causa de degradación de performance sin correlación con evidencia de `oracle-performance-analyst` (`# 27`).

# Confidence model

`FACT` para el progreso leído directamente. `HYPOTHESIS` para "el rebalance explica la degradación observada" sin correlación de `performance/io`.

# Output schema

```yaml
findings:
  - diskgroup: string
    operation: string
    state: string
    power: number
    actual: number
    sofar: number
    est_work: number
    est_minutes: number|null
    evidence_refs: [EVD-...]
```

# Related skills

`asm/operations`, `performance/io` (vía `oracle-performance-analyst`, correlación por evidence_refs).

# Escalation

Rebalance con impacto de I/O confirmado y sin ventana de mantenimiento conocida → informar al DBA, nunca cambiar `POWER` automáticamente.

# Data sensitivity

Baja — progreso agregado, no datos de aplicación.

# Context budget

Bajo — sólo se incluye si hay rebalance activo.

# Tests

`tests/test_asm_rebalance.sh`, `tests/test_asm_no_rebalance_execution.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `asm-analysis.md`.

# Evolution via `/change`

N/A — vista estable desde 11gR2.

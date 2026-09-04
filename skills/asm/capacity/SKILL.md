---
name: capacity
id: asm/capacity
version: 2.0.0
domain: asm
status: active
---

# Purpose

Calcular capacidad **real** de cada disk group usando `USABLE_FILE_MB`/`REQUIRED_MIRROR_FREE_MB` — nunca un cálculo tipo filesystem (`# 24` del prompt de Fase 4). No se alerta sólo por `FREE_MB` bajo (`# 54`).

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

Standalone y RAC.

# Prerequisites

`asm/diskgroups` y `asm/redundancy` resueltos.

# Required evidence

- `Q-ASM-TOPOLOGY-001` (`V$ASM_DISKGROUP_STAT` — `TOTAL_MB`, `FREE_MB`, `USABLE_FILE_MB`, `REQUIRED_MIRROR_FREE_MB`)

# Optional evidence

Ninguna.

# Read-only operations

Lectura de `V$ASM_DISKGROUP_STAT`.

# Forbidden operations

No amplía/reduce disk groups.

# Decision logic

1. Calcular `usable_pct = USABLE_FILE_MB / TOTAL_MB`, considerando `REDUNDANCY` (de `asm/redundancy`) — nunca una fórmula universal sin conocer la redundancia real.
2. Clasificar `headroom`: `HEALTHY` (usable_pct sobre umbral de política), `WARNING`, `CRITICAL` (por debajo del umbral crítico considerando `REQUIRED_MIRROR_FREE_MB`).
3. El finding se basa siempre en el conjunto `TOTAL_MB + FREE_MB + USABLE_FILE_MB + REQUIRED_MIRROR_FREE_MB + REDUNDANCY` — nunca en `FREE_MB` aislado.

# Confidence model

`FACT` para todas las métricas leídas directamente — la clasificación de headroom es determinística, no requiere niveles de confianza probabilísticos.

# Output schema

```yaml
findings:
  - diskgroup: string
    redundancy: string
    total_mb: number
    free_mb: number
    usable_file_mb: number
    required_mirror_free_mb: number
    usable_pct: number
    headroom_classification: HEALTHY|WARNING|CRITICAL
    evidence_refs: [EVD-...]
```

# Related skills

`asm/diskgroups`, `asm/redundancy`, `capacity-analyst` (forecast a mediano plazo).

# Escalation

`CRITICAL` → escala a `change-advisor` para propuesta de ampliación (ejecución manual).

# Data sensitivity

Media — nombres de disk group.

# Context budget

Bajo — capacidad es compacta, un valor por disk group.

# Tests

`tests/test_asm_capacity_usable_file.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `asm-analysis.md`.

# Evolution via `/change`

Umbrales de headroom vía `/change policy`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Foundation | Skill plano `skills/asm/capacity.md`. |
| 2.0.0 | Fase 4 (RAC/GI/ASM/Network) | Reescrito bajo el modelo `USABLE_FILE_MB`/`REQUIRED_MIRROR_FREE_MB`/`REDUNDANCY`, nunca `FREE_MB` aislado. |

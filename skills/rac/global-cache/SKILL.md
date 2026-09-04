---
name: global-cache
id: rac/global-cache
version: 1.0.0
domain: rac
status: active
---

# Purpose

Reconocer indicadores de actividad de Global Cache Service/Global Enqueue Service (`gc current`, `gc cr`, estadísticas GES/GCS) desde la óptica de **topología/cluster context** — sin reconstruir el análisis de impacto en DB Time de `performance/wait-events` (`# 53` del prompt de Fase 4: "Performance analiza impacto. RAC analiza topología/cluster context").

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC exclusivamente (Cache Fusion no aplica a RAC One Node con una sola instancia activa).

# Prerequisites

`rac/topology` resuelto.

# Required evidence

- `Q-RAC-GES-GCS-001` (`GV$GES_STATISTICS`, `GV$GCS_STATISTICS`, `GV$INSTANCE_CACHE_TRANSFER`)

# Optional evidence

Ninguna propia — para cuantificar impacto en DB Time, delegar a `performance/wait-events` vía `oracle-performance-analyst`.

# Read-only operations

Lectura de `GV$GES_STATISTICS`/`GV$GCS_STATISTICS`/`GV$INSTANCE_CACHE_TRANSFER`.

# Forbidden operations

No modifica parámetros de Cache Fusion (`_gc_*` u otros ocultos) — ni siquiera visibilidad de esos parámetros ocultos está en alcance.

# Decision logic

1. Leer contadores GES/GCS e `INSTANCE_CACHE_TRANSFER` por instancia.
2. Correlacionar con `rac/interconnect` — un contador elevado sin discrepancia de interconnect no se atribuye automáticamente a la red.
3. Si el DBA necesita cuantificar el impacto en DB Time, este skill entrega `evidence_refs` a `oracle-performance-analyst` — nunca calcula ese impacto por sí mismo.

# Confidence model

`FACT` para contadores leídos directamente. `OBSERVATION` para "actividad GES/GCS elevada" sin cuantificar impacto.

# Output schema

```yaml
findings:
  - instance: string
    gcs_indicator: string
    value: number
    evidence_refs: [EVD-...]
```

# Related skills

`rac/interconnect`, `performance/wait-events` (vía `oracle-performance-analyst`, correlación por evidence_refs, nunca reconstrucción).

# Escalation

Impacto en DB Time requerido → delega a `oracle-performance-analyst` con evidence_refs de topología ya determinada.

# Data sensitivity

Baja — contadores agregados, no datos de aplicación.

# Context budget

Media.

# Tests

`tests/test_no_write_operations.sh`, `tests/test_rac_interconnect.sh`.

# Documentation requirements

Alimenta `rac-topology.md` cuando el análisis lo requiere.

# Evolution via `/change`

Vistas GES/GCS adicionales vía `/change query`.

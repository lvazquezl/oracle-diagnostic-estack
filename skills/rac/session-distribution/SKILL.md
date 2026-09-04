---
name: session-distribution
id: rac/session-distribution
version: 2.0.0
domain: rac
status: active
---

# Purpose

Evaluar cómo se distribuyen las sesiones activas/inactivas entre instancias y servicios de un cluster RAC, y calcular el ratio de desbalance — sin asumir que distribución uniforme es siempre correcta (`# 14` del prompt de Fase 4).

# Supported Oracle versions

11gR2–23ai (CLB/RLB con comportamiento estable desde 11gR2).

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node. NON-CDB y CDB. Primary y Physical Standby (en standby con Active Data Guard, aplica a sesiones de sólo lectura).

# Prerequisites

`rac/topology` y `rac/services` resueltos en la misma sesión.

# Required evidence

- `Q-RAC-SESSION-DIST-001` (`GV$SESSION`, `GV$SERVICES` — sesiones activas/inactivas por instancia/servicio)

# Optional evidence

- `Q-RAC-SERVICES-001` (placement/goal de servicio, para correlacionar desbalance con configuración)

# Read-only operations

Lectura de `GV$SESSION`, `GV$SERVICES`.

# Forbidden operations

No relocaliza sesiones, no modifica `CLB_GOAL`/`RLB_GOAL`, no desconecta sesiones (`ALTER SYSTEM KILL SESSION` prohibido).

# Decision logic

1. Contar sesiones activas e inactivas por instancia y servicio.
2. Calcular `imbalance_ratio` respecto a una distribución uniforme esperada (`100/N_instancias`) — **nunca concluir por sí solo**: `Node 1 = 2x sessions` no es automáticamente `load balancing failure`.
3. Correlacionar obligatoriamente antes de clasificar: `service preferred/available instances` (`rac/service-placement`), `CLB_GOAL`/`RLB_GOAL` (`rac/services`), workload conocido (batch vs. OLTP, si el DBA lo declaró), connection pooling del lado aplicación (si es evidencia disponible), service affinity, historial de failover reciente (`rac/failover`).
4. Clasificar la causa probable: `CONFIGURATION|CLIENT_BEHAVIOR|POOLING|SERVICE_AFFINITY|WORKLOAD|FAILOVER_HISTORY|INSUFFICIENT_EVIDENCE` — `INSUFFICIENT_EVIDENCE` se reporta explícitamente en vez de omitir la clasificación cuando no hay suficiente correlación.

# Confidence model

`FACT` para el conteo de sesiones por instancia. `HYPOTHESIS` para una clasificación con 1 señal de correlación. `PROBABLE_CAUSE` con 2+ señales correlacionadas (ej. `CLB_GOAL: NONE` + ausencia de pooling declarado).

# Output schema

```yaml
findings:
  - service: string
    instance: string
    active_sessions: number
    inactive_sessions: number
    pct_of_total: number
    imbalance_ratio: number
    classification: CONFIGURATION|CLIENT_BEHAVIOR|POOLING|SERVICE_AFFINITY|WORKLOAD|FAILOVER_HISTORY|INSUFFICIENT_EVIDENCE
    severity: LOW|MEDIUM|HIGH
    confidence: FACT|HYPOTHESIS|PROBABLE_CAUSE
    evidence_refs: [EVD-...]
```

# Related skills

`rac/load-balancing`, `rac/clb`, `rac/rlb`, `rac/service-placement`, `rac/services`, `os/*/cpu` (vía `os-platform-analyst`).

# Escalation

Desbalance que coincide con saturación de CPU en una instancia → escala a `os-platform-analyst` para confirmar impacto; causa raíz de configuración corregible → `change-advisor`.

# Data sensitivity

Media — `service_name` enmascarado por defecto (puede revelar nombre de aplicación).

# Context budget

Bajo-medio: conteo agregado por instancia/servicio, no el detalle de cada sesión individual salvo que se pida explícitamente.

# Tests

`tests/test_rac_session_distribution.sh`, `tests/test_rac_imbalance_not_automatically_error.sh`, `tests/test_no_write_operations.sh`, `tests/test_no_kill_session.sh`.

# Documentation requirements

Alimenta `service-analysis.md` con la tabla de distribución por servicio/instancia y su clasificación.

# Evolution via `/change`

Umbral de desviación vía `/change policy`; nuevas señales de correlación vía `/change query`.

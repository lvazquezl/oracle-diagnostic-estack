---
name: service-session-distribution
id: rac/service-session-distribution
version: 1.0.0
domain: rac
status: active
---

# Purpose

Vista de distribución de sesiones acotada a **un servicio específico** (en vez de la vista cluster-wide de `rac/session-distribution`) — responde "¿está balanceado ESTE servicio en particular?" sin reordenar todo el cluster.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`rac/services` resuelto; requiere `service_name` como parámetro del Task Package.

# Required evidence

- `Q-RAC-SESSION-DIST-001` (misma query que `rac/session-distribution`, filtrada/agrupada por el `service_name` solicitado — sin query propia, sólo reordenamiento, igual patrón que `performance/sql-cpu` sobre `top-sql` en Fase 3).

# Optional evidence

Ninguna.

# Read-only operations

Lectura de `GV$SESSION`/`GV$SERVICES` ya cubierta por `Q-RAC-SESSION-DIST-001`.

# Forbidden operations

No relocaliza sesiones ni modifica el servicio.

# Decision logic

1. Filtrar la evidencia ya recolectada de `Q-RAC-SESSION-DIST-001` al `service_name` solicitado.
2. Aplicar la misma lógica de `imbalance_ratio` y clasificación que `rac/session-distribution`, pero reportando sólo ese servicio.

# Confidence model

Idéntico a `rac/session-distribution` — `FACT` para el conteo, `HYPOTHESIS`/`PROBABLE_CAUSE` para la clasificación de causa.

# Output schema

```yaml
findings:
  - service: string
    instance: string
    active_sessions: number
    inactive_sessions: number
    imbalance_ratio: number
    classification: CONFIGURATION|CLIENT_BEHAVIOR|POOLING|SERVICE_AFFINITY|WORKLOAD|FAILOVER_HISTORY|INSUFFICIENT_EVIDENCE
    evidence_refs: [EVD-...]
```

# Related skills

`rac/session-distribution`, `rac/services`, `rac/service-placement`.

# Escalation

Igual que `rac/session-distribution`, acotado al servicio solicitado.

# Data sensitivity

Media — `service_name` enmascarado salvo que sea el parámetro explícito de la solicitud.

# Context budget

Bajo — un único servicio, no el cluster completo.

# Tests

`tests/test_rac_session_distribution.sh` (cubre ambos skills — misma evidencia subyacente), `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `service-analysis.md` cuando el análisis es específico de un servicio.

# Evolution via `/change`

Ninguna evolución propia — hereda la de `rac/session-distribution`.

---
name: rlb
id: rac/rlb
version: 1.0.0
domain: rac
status: active
---

# Purpose

Evaluar Runtime Load Balancing: cómo el cliente (con FAN/FCF) redistribuye trabajo entre conexiones ya existentes según el `goal`/`RLB_GOAL` del servicio (`SERVICE_TIME`/`THROUGHPUT`/`NONE`). Distinto de CLB (`rac/clb`), que sólo afecta nuevas conexiones.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`rac/services` resuelto.

# Required evidence

- `Q-RAC-SERVICES-001` (`GOAL`/`RLB_GOAL` por servicio)

# Optional evidence

- `Q-RAC-SESSION-DIST-001` para correlacionar el goal declarado con la distribución observada.

# Read-only operations

Lectura de `GV$SERVICES` (goal RLB).

# Forbidden operations

No modifica el goal RLB.

# Decision logic

1. `goal: NONE` → RLB desactivado, cualquier desbalance de sesiones activas NO se explica por RLB (esperado, no requiere FAN).
2. `goal: SERVICE_TIME`/`THROUGHPUT` → RLB activo; requiere que el cliente use FAN/FCF (connection pool consciente de eventos) para tener efecto — un cliente sin FAN configurado explica un desbalance pese a `goal` activo (correlacionar con evidencia de `pooling`, si el DBA la declara).

# Confidence model

`FACT` para el goal leído directamente. `HYPOTHESIS` para "desbalance por falta de FAN del lado cliente" sin evidencia directa de configuración del pool.

# Output schema

```yaml
findings:
  - service: string
    rlb_goal: string
    evidence_refs: [EVD-...]
```

# Related skills

`rac/load-balancing`, `rac/clb`, `rac/session-distribution`.

# Escalation

Delega la clasificación final de causa a `rac/load-balancing`.

# Data sensitivity

Media — `service_name` enmascarado.

# Context budget

Bajo.

# Tests

`tests/test_rac_rlb_analysis.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `service-analysis.md`.

# Evolution via `/change`

N/A — RLB goal es estable desde 11gR2.

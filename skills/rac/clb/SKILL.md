---
name: clb
id: rac/clb
version: 1.0.0
domain: rac
status: active
---

# Purpose

Evaluar específicamente Connection Load Balancing: cómo SCAN/listener distribuyen **nuevas** conexiones entre instancias según `CLB_GOAL`. Distinto de RLB (`rac/rlb`), que redistribuye trabajo entre conexiones ya existentes.

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`rac/services` resuelto.

# Required evidence

- `Q-RAC-SERVICES-001` (`CLB_GOAL` por servicio — `LONG`/`SHORT`).

# Optional evidence

Ninguna.

# Read-only operations

Lectura de `GV$SERVICES.CLB_GOAL`.

# Forbidden operations

No modifica `CLB_GOAL`.

# Decision logic

1. `CLB_GOAL: LONG` favorece sesiones de larga duración distribuidas uniformemente; `SHORT` favorece throughput de conexión (conexiones cortas/frecuentes). Ninguno es "correcto" universalmente — depende del workload declarado.
2. Un servicio con `CLB_GOAL` inconsistente con el patrón de conexión observado (ej. `SHORT` sobre un pool de conexiones persistentes) se reporta como observación de configuración, correlacionada por `rac/load-balancing`.

# Confidence model

`FACT` para `CLB_GOAL` leído directamente.

# Output schema

```yaml
findings:
  - service: string
    clb_goal: string
    evidence_refs: [EVD-...]
```

# Related skills

`rac/load-balancing`, `rac/rlb`, `network/scan`.

# Escalation

Delega la clasificación de causa a `rac/load-balancing` — este skill sólo reporta el goal configurado.

# Data sensitivity

Media — `service_name` enmascarado.

# Context budget

Bajo.

# Tests

`tests/test_rac_clb_analysis.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `service-analysis.md`.

# Evolution via `/change`

N/A — CLB_GOAL es estable desde 11gR2.

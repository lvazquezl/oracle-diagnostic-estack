---
name: load-balancing
id: rac/load-balancing
version: 1.0.0
domain: rac
status: active
---

# Purpose

Diagnóstico unificado de Connection Load Balancing (CLB) y Runtime Load Balancing (RLB) — el skill "paraguas" que orquesta `rac/clb`/`rac/rlb` y aplica el modelo de correlación de `# 50` del prompt de Fase 4. Diferencia explícitamente CLB, RLB, TAF y Application Continuity — nunca los trata como equivalentes (`# 16`).

# Supported Oracle versions

11gR2–23ai.

# Supported OS/platforms

Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server.

# Supported architectures

RAC y RAC One Node.

# Prerequisites

`rac/services` y `rac/session-distribution` resueltos.

# Required evidence

- `Q-RAC-SESSION-DIST-001`, `Q-RAC-SERVICES-001`

# Optional evidence

- evidencia de `network/scan` (uso real de SCAN por el cliente) cuando el desbalance podría originarse en el path de conexión, no en el servidor.

# Read-only operations

Lectura de `GV$SESSION`, `GV$SERVICES` (`CLB_GOAL`, `GOAL`/RLB).

# Forbidden operations

No modifica servicios ni goals de balanceo.

# Decision logic

1. Recibir el desbalance ya calculado por `rac/session-distribution`.
2. Correlacionar: `CLB_GOAL` (nuevas conexiones) + `RLB_GOAL`/`goal` (redistribución runtime, requiere FAN) + placement de servicio + connection pool awareness + uso de SCAN + distribución de sesión observada.
3. Clasificar según `# 50`: `CONFIGURATION|CLIENT_BEHAVIOR|POOLING|SERVICE_AFFINITY|WORKLOAD|FAILOVER_HISTORY|INSUFFICIENT_EVIDENCE`.
4. Nunca modifica servicios automáticamente — toda corrección es `manual_action`.

# Confidence model

`FACT` para goals/configuración leídos directamente. `PROBABLE_CAUSE` para la clasificación con 2+ señales correlacionadas.

# Output schema

```yaml
findings:
  - service: string
    clb_goal: string
    rlb_goal: string
    observed_imbalance_ratio: number
    classification: CONFIGURATION|CLIENT_BEHAVIOR|POOLING|SERVICE_AFFINITY|WORKLOAD|FAILOVER_HISTORY|INSUFFICIENT_EVIDENCE
    confidence: FACT|HYPOTHESIS|PROBABLE_CAUSE
    evidence_refs: [EVD-...]
```

# Related skills

`rac/clb`, `rac/rlb`, `rac/session-distribution`, `rac/services`, `network/scan`.

# Escalation

Recomendación de corrección de servicio → `manual_action` vía `change-advisor`, nunca ejecutada por este stack.

# Data sensitivity

Media — `service_name` enmascarado.

# Context budget

Media.

# Tests

`tests/test_rac_clb_analysis.sh`, `tests/test_rac_rlb_analysis.sh`, `tests/test_no_write_operations.sh`, `tests/test_no_srvctl_modify_execution.sh`.

# Documentation requirements

Alimenta `service-analysis.md`.

# Evolution via `/change`

Nuevas señales de correlación (TAF/Application Continuity metadata) vía `/change query`.

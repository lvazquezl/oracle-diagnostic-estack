---
name: switchover-readiness
id: dataguard/switchover-readiness
version: 1.0.0
domain: dataguard
status: active
---

# Purpose

Evaluar readiness para una transición de rol **planificada** (`# 28`, `# 31` del prompt de Fase 5) — nunca ejecuta el switchover. Diferenciado explícitamente de `dataguard/failover-readiness` (transición de emergencia).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported Data Guard architectures

PHYSICAL_STANDBY.

# Prerequisites

`dataguard/role`, `dataguard/lag`, `dataguard/archive-gaps`, `dataguard/standby-redo-logs`, `dataguard/broker` (si habilitado) resueltos.

# Required evidence

- `Q-DG-ROLE-001` (roles/protección/`SWITCHOVER_STATUS`)
- `Q-DG-STATS-001` (lag)

# Optional evidence

- collector `get_dataguard_database_status` (estado Broker por miembro, si Broker está habilitado).

# Licensing requirements

Ninguno.

# Query IDs

`Q-DG-ROLE-001`, `Q-DG-STATS-001`, `Q-DG-ARCHIVE-GAP-001`.

# Collector IDs

`get_dataguard_database_status`.

# Read-only operations

Orquesta lecturas ya cubiertas por skills subordinados — no introduce lecturas propias adicionales.

# Forbidden operations

No ejecuta `ALTER DATABASE SWITCHOVER` ni `DGMGRL SWITCHOVER TO` bajo ninguna circunstancia.

# Decision logic

1. Evaluar, como mínimo (`# 28`): roles primary/standby, salud de transporte, salud de apply, lag, gaps, salud de Broker (si se usa), `SWITCHOVER_STATUS`, SRLs, consistencia de protección, errores de destino, flashback awareness, implicaciones RAC/servicio, warnings conocidos.
2. Cada verificación produce `PASS`/`WARNING`/`BLOCKING` — nunca se omite una verificación sin declararla en `unsupported_checks` si no puede evaluarse.
3. Resultado final: `READY` (todo `PASS`), `READY_WITH_WARNINGS` (sin `BLOCKING`, con `WARNING`), `NOT_READY` (al menos un `BLOCKING`), `INSUFFICIENT_EVIDENCE` (una o más verificaciones críticas no pudieron evaluarse) — nunca `READY` sin evidencia suficiente para todas las verificaciones críticas.

# Normal state

Todas las verificaciones `PASS`, `SWITCHOVER_STATUS = TO STANDBY`/`SESSIONS ACTIVE` (según versión), lag dentro de umbral, sin gaps.

# Abnormal patterns

`SWITCHOVER_STATUS = NOT ALLOWED`; lag por encima de umbral; gap sin resolver; SRL insuficiente.

# False positives

Warning de Broker transitorio ya resuelto en la evidencia más reciente — usar la observación más actual, no una ventana obsoleta.

# Correlation rules

Consolida hallazgos de `dataguard/lag`, `dataguard/archive-gaps`, `dataguard/standby-redo-logs`, `dataguard/broker`, `dataguard/protection` — nunca reconstruye esos análisis, sólo los consume por referencia.

# Confidence model

`FACT` para cada verificación individual leída directamente. El `confidence` del resultado consolidado es el mínimo de sus componentes — `HYPOTHESIS` si alguna verificación no pudo confirmarse con evidencia directa.

# Severity

`NOT_READY` con un `BLOCKING` crítico (ej. gap sin resolver) → `HIGH`; `READY_WITH_WARNINGS` → `MEDIUM`.

# Output schema

```yaml
readiness:
  status: READY|READY_WITH_WARNINGS|NOT_READY|INSUFFICIENT_EVIDENCE
  blocking_findings: [string]
  warnings: [string]
  evidence_refs: [EVD-...]
  data_loss_exposure: string|null
  manual_prechecks: [string]
  unsupported_checks: [string]
  confidence: FACT|OBSERVATION|HYPOTHESIS
```

# Related skills

`dataguard/lag`, `dataguard/archive-gaps`, `dataguard/standby-redo-logs`, `dataguard/broker`, `dataguard/failover-readiness`.

# Escalation

`NOT_READY` con un blocking crítico y el usuario solicita proceder → generar el Switchover Manual Plan completo (`docs/DATAGUARD_SWITCHOVER_READINESS.md#switchover-manual-plan`), nunca ejecutar.

# Manual remediation guidance

Si el usuario solicita el procedimiento de switchover: `PRECHECKS`, `CHANGE WINDOW REQUIREMENTS`, `APPLICATION COORDINATION`, `RAC/SERVICE CONSIDERATIONS`, `MANUAL COMMANDS`, `EXPECTED STATE TRANSITIONS`, `VALIDATION`, `ROLLBACK/FALLBACK`, `POSTCHECKS` — todo marcado `MANUAL DBA ACTION`/`NOT EXECUTED` (`# 29`).

# Security

Ninguna dato sensible propio más allá de lo ya enmascarado por los skills consumidos.

# Tests

`tests/test_switchover_ready.sh`, `tests/test_switchover_not_ready_transport.sh`, `tests/test_switchover_not_ready_gap.sh`, `tests/test_switchover_warning.sh`, `tests/test_readiness_insufficient_evidence.sh`, `tests/test_no_switchover_execution.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `readiness.md` con el resultado completo del Readiness Result Contract.

# Change history

v1.0.0 — Fase 5, creación inicial.

---
name: failover-readiness
id: dataguard/failover-readiness
version: 1.0.0
domain: dataguard
status: active
---

# Purpose

Evaluar readiness para una transición de rol de **emergencia/desastre** (`# 30`, `# 31` del prompt de Fase 5), incluyendo exposición a pérdida de datos — nunca ejecuta el failover. Diferenciado explícitamente de `dataguard/switchover-readiness` (transición planificada).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported Data Guard architectures

PHYSICAL_STANDBY.

# Prerequisites

`dataguard/lag`, `dataguard/archive-gaps`, `dataguard/fsfo` (si aplica) resueltos.

# Required evidence

- `Q-DG-STATS-001` (último redo recibido/aplicado)
- `Q-DG-ARCHIVE-GAP-001` (gaps de transporte/apply)

# Optional evidence

- collector `get_fsfo_status` (estado FSFO/observer, si Broker está habilitado).

# Licensing requirements

Ninguno.

# Query IDs

`Q-DG-STATS-001`, `Q-DG-ARCHIVE-GAP-001`.

# Collector IDs

`get_fsfo_status`.

# Read-only operations

Orquesta lecturas ya cubiertas por skills subordinados.

# Forbidden operations

No ejecuta `ALTER DATABASE FAILOVER` ni `DGMGRL FAILOVER TO`, no ejecuta `REINSTATE DATABASE` bajo ninguna circunstancia.

# Decision logic

1. Evaluar, como mínimo (`# 30`): último redo recibido, último redo aplicado, gaps de transporte/apply, exposición a pérdida de datos, protection mode, estado Broker, estado FSFO, flashback awareness (prerequisito de reinstate), implicaciones de servicio.
2. **Data loss exposure** se calcula explícitamente a partir de la diferencia entre último redo generado en el primary (si es alcanzable) y último redo aplicado en el standby — nunca se omite este cálculo cuando la evidencia lo permite.
3. Resultado: `READY`/`READY_WITH_WARNINGS`/`NOT_READY`/`INSUFFICIENT_EVIDENCE` — nunca `READY` sin evidencia suficiente (`# 30`: "No presentar READY sin evidencia suficiente").

# Normal state

Gap mínimo o nulo, `data_loss_exposure` reportado como bajo/nulo, protection mode `MAXIMUM AVAILABILITY`/`MAXIMUM PROTECTION` con FSFO consistente.

# Abnormal patterns

Gap significativo sin resolver; `data_loss_exposure` no calculable por falta de evidencia del lado primary (esperado en un escenario real de desastre, pero se declara `INSUFFICIENT_EVIDENCE`, nunca se asume cero pérdida).

# False positives

Ninguno específico — un resultado `NOT_READY`/`INSUFFICIENT_EVIDENCE` en un escenario de desastre real es el comportamiento correcto, no un falso positivo del sistema.

# Correlation rules

Consolida `dataguard/lag`, `dataguard/archive-gaps`, `dataguard/fsfo`, `dataguard/observer` — nunca reconstruye esos análisis.

# Confidence model

`FACT` para redo recibido/aplicado leído directamente del standby. `INSUFFICIENT_EVIDENCE` explícito cuando el primary no es alcanzable (escenario real de failover) — nunca se asume el estado del primary.

# Severity

`data_loss_exposure` no nulo → siempre reportado, severidad proporcional a la magnitud del gap de redo no aplicado.

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

`dataguard/lag`, `dataguard/archive-gaps`, `dataguard/fsfo`, `dataguard/observer`, `dataguard/switchover-readiness`.

# Escalation

Failover real en curso o inminente → `incident-root-cause-analyst` inmediato, severity `CRITICAL`.

# Manual remediation guidance

Ejecución de failover/reinstate es siempre `manual_action`, `execution_status: NOT_EXECUTED` — nunca ejecutado por este stack bajo ninguna circunstancia, incluso en un escenario de desastre real.

# Security

Ninguna dato sensible propio más allá de lo ya enmascarado por los skills consumidos.

# Tests

`tests/test_failover_readiness.sh`, `tests/test_failover_data_loss_exposure.sh`, `tests/test_readiness_insufficient_evidence.sh`, `tests/test_no_failover_execution.sh`, `tests/test_no_reinstate_execution.sh`, `tests/test_no_write_operations.sh`.

# Documentation requirements

Alimenta `readiness.md` con el resultado completo del Readiness Result Contract, incluyendo `data_loss_exposure` explícito.

# Change history

v1.0.0 — Fase 5, creación inicial.

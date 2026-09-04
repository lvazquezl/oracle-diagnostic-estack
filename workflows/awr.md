---
name: awr
version: 1.0.0
status: active
---

# Trigger/intent

Comando `/awr`. Análisis de performance dirigido a una ventana AWR/ASH específica (opcionalmente comparando dos períodos).

# Prerequisites

Target identificado, `constraints.time_window` (o dos ventanas para comparación) explícito.

# Discovery requirements

`oracle-discovery-analyst` obligatorio si no hay cache válido, para confirmar licenciamiento de Diagnostics Pack vía `oracle-performance-analyst` (declarado, no confirmado por discovery directamente).

# Minimum agents

`oracle-operations-orchestrator`, `oracle-performance-analyst`.

# Optional agents

`oracle-rac-analyst` (si el wait dominante es `gc *`), `oracle-asm-storage-analyst`/`os-platform-analyst` (si el wait dominante es I/O), `incident-root-cause-analyst` (si se pide RCA sobre la ventana, no sólo caracterización).

# Activation conditions

Igual que la lógica de escalada declarada en `agents/oracle-performance-analyst.md#collaboration-delegation-rules`.

# Skills

`performance/awr-analysis`, `performance/wait-events`, `performance/db-time`, `performance/top-sql`, y el resto de `performance/*` según lo que la pregunta requiera.

# Evidence required

`Q-PERF-WAIT-AWR-001` como mínimo; `Q-PERF-WAIT-ASH-001` si se pide granularidad fina; fallback a `Q-PERF-WAIT-STATSPACK-001` si no hay Diagnostics Pack.

# Stop conditions

Ventana de tiempo solicitada excede la retención de AWR/Statspack disponible — se declara y se ofrece la ventana máxima disponible.

# Confidence threshold

`PROBABLE_CAUSE` requiere correlación wait event + top SQL + ventana; `CONFIRMED_ROOT_CAUSE` sólo vía `incident-root-cause-analyst`, nunca directamente de este workflow.

# Escalation

A `oracle-rac-analyst`/`os-platform-analyst`/`oracle-asm-storage-analyst` según el wait dominante; a `incident-root-cause-analyst` si el DBA pide RCA explícito.

# Documentation output

`analysis/ANA-YYYYMMDD-NNN/` con `findings.md` centrado en el load profile y top wait/SQL de la ventana.

# Token/context budget

Medio-alto, estrictamente acotado por `time_window`; nunca procesa un AWR sin ventana explícita.

# Security constraints

READ-ONLY ALWAYS. SQL text sólo por SQL_ID/plan hash salvo autorización explícita del DBA para la sesión.

# Gates

```yaml
gates:
  version:      config/capability-matrix.yaml → AWR/ASH/ADDM son LICENSE_DEPENDENT en toda versión 10g-latest; Statspack es SUPPORTED (Fase 3, primera clase, sin licencia)
  architecture: agentes de escalada (oracle-rac-analyst/oracle-asm-storage-analyst/os-platform-analyst) sólo se activan si el wait dominante lo justifica Y la arquitectura aplica (ej. gc waits sólo si RAC)
  environment:  target debe estar en config/allowed-targets.local.yaml
  license:      si Diagnostics Pack no se confirma, capability_status LICENSE_RESTRICTED en AWR/ASH; fallback automático a Q-PERF-WAIT-STATSPACK-001
  privilege:    ESTACK_DIAGNOSTIC_ROLE debe alcanzar DBA_HIST_* o STATS$* según el fallback
  security:     ninguna query requerida puede tener risk_class fuera de R0
  cost:         Q-PERF-WAIT-ASH-001 es cost_class HIGH → exige time_window explícito y acotado (policies/query-cost-policy.md)
  evidence:     exige constraints.time_window explícito en el Task Package; sin ventana, el workflow no arranca
```

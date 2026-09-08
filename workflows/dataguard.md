---
name: dataguard
version: 2.0.0
status: active
---

# Trigger/intent

Comando `/dataguard`. Diagnóstico dirigido a rol, topología, protección, transporte, apply, lag, gaps, SRL, Broker, FSFO/observer y readiness de switchover/failover de Data Guard (Fase 5 — `agents/oracle-dataguard-analyst/AGENT.md`).

# Prerequisites

Target identificado; discovery debe confirmar `database_role` (Primary o Physical Standby) y, si es posible, el sitio par.

# Discovery requirements

`oracle-discovery-analyst` obligatorio si no hay cache válido, en ambos sitios cuando el DBA provee acceso a los dos.

# Minimum agents

`oracle-operations-orchestrator`, `oracle-dataguard-analyst`.

# Optional agents

`oracle-network-analyst` (conectividad entre sitios), `oracle-backup-recovery-analyst` (gap que requiere evaluación de recuperación), `incident-root-cause-analyst` (lag crítico con riesgo de RPO).

# Activation conditions

Igual que `agents/oracle-dataguard-analyst/routing.yaml#activation_conditions`.

# Skills

`dataguard/role`, `dataguard/topology`, `dataguard/protection`, `dataguard/transport`, `dataguard/apply`, `dataguard/lag`, `dataguard/archive-gaps`, `dataguard/standby-redo-logs`, `dataguard/broker`, `dataguard/switchover-readiness`, `dataguard/failover-readiness`, y el resto de `dataguard/*` (21 skills) según la pregunta.

# Evidence required

`Q-DG-ROLE-001`, `Q-DG-STATS-001` como mínimo; `Q-DG-ARCHIVE-GAP-001` si hay indicios de gap; `Q-DG-SRL-001`/collectors Broker según readiness.

# Stop conditions

Sólo hay acceso read-only a un sitio (ej. sólo standby) — el workflow continúa con lo disponible y declara explícitamente qué no pudo confirmarse desde el otro sitio.

# Confidence threshold

Igual al general del stack; `readiness` de switchover se declara explícitamente `NOT READY` con la razón si el lag excede el umbral de política.

# Escalation

Lag que excede el umbral de RPO de política escala a `incident-root-cause-analyst`; causa identificada y corregible escala a `change-advisor`.

# Documentation output

`analysis/ANA-YYYYMMDD-NNN/` con sección explícita de readiness de switchover/failover (nunca se ejecuta, sólo se evalúa).

# Token/context budget

Bajo-medio.

# Security constraints

READ-ONLY ALWAYS. Nunca ejecuta switchover/failover ni cambia protection mode.

# Gates

```yaml
gates:
  version:      config/capability-matrix.yaml → Data Guard es SUPPORTED 10g-23ai para PHYSICAL_STANDBY; LOGICAL_STANDBY/SNAPSHOT_STANDBY/FAR_SYNC son PARTIALLY_SUPPORTED; Active Data Guard (lectura en standby) es LICENSE_DEPENDENT y se evalúa por finding específico vía ACTIVE_DATA_GUARD_CHECK
  architecture: requiere target_profile.dataguard.enabled = true confirmado por discovery en al menos un sitio (primary o standby); si no hay ningún sitio identificable, capability_status ENVIRONMENT_UNKNOWN
  environment:  target(s) deben estar en config/allowed-targets.local.yaml
  license:      si se detecta uso de Active Data Guard sin confirmar licencia, LICENSE_RESTRICTED con required_action LICENSE_CHECK_REQUIRED, el resto del workflow continúa
  privilege:    ESTACK_DIAGNOSTIC_ROLE debe alcanzar V$DATABASE/V$DATAGUARD_STATS/V$ARCHIVE_DEST_STATUS/V$MANAGED_STANDBY (10.2-12.1)/V$DATAGUARD_PROCESS (12.2+, ver docs/PHASE_5_FINAL_PROCESS_VIEW_PORTABILITY_HARDENING.md)/V$STANDBY_LOG en cada sitio accesible; identidad diagnóstica Broker separada para collectors DGMGRL — INSUFFICIENT_PRIVILEGES + MANUAL_COLLECTION_REQUIRED si no disponible, nunca escalamiento automático
  security:     ninguna query requerida puede tener risk_class fuera de R0; ninguna tool de switchover/failover/reinstate/broker-edit existe en el catálogo (tests/test_no_switchover_execution.sh, tests/test_no_failover_execution.sh, tests/test_no_reinstate_execution.sh, tests/test_no_broker_edit.sh)
  cost:         Q-DG-ARCHIVED-LOG-001 es cost_class MEDIUM (parametrizada por ventana de tiempo, # 55); el resto del catálogo es LOW
  evidence:     si sólo hay acceso a un sitio, continúa con lo disponible y declara explícitamente qué no pudo confirmarse desde el otro; reutiliza target_profile.dataguard ya cacheado por oracle-discovery-analyst
```

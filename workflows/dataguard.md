---
name: dataguard
version: 1.0.0
status: active
---

# Trigger/intent

Comando `/dataguard`. Diagnóstico dirigido a rol, lag, gaps, Broker y readiness de Data Guard.

# Prerequisites

Target identificado; discovery debe confirmar `database_role` (Primary o Physical Standby) y, si es posible, el sitio par.

# Discovery requirements

`oracle-discovery-analyst` obligatorio si no hay cache válido, en ambos sitios cuando el DBA provee acceso a los dos.

# Minimum agents

`oracle-operations-orchestrator`, `oracle-dataguard-analyst`.

# Optional agents

`oracle-network-analyst` (conectividad entre sitios), `oracle-backup-recovery-analyst` (gap que requiere evaluación de recuperación), `incident-root-cause-analyst` (lag crítico con riesgo de RPO).

# Activation conditions

Igual que `agents/oracle-dataguard-analyst.md#collaboration-delegation-rules`.

# Skills

`dataguard/role`, `dataguard/lag`, `dataguard/archive-gap`, `dataguard/broker`, `dataguard/readiness`.

# Evidence required

`Q-DG-STATS-001` como mínimo; `Q-DG-ARCHIVE-GAP-001` si hay indicios de gap.

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
  version:      config/capability-matrix.yaml → Data Guard es PARTIAL 10g-latest; Active Data Guard (lectura en standby) es LICENSE_DEPENDENT y se evalúa por finding específico
  architecture: requiere database_role_scope: ANY confirmado por discovery en al menos un sitio (primary o standby); si no hay ningún sitio identificable, capability_status ENVIRONMENT_UNKNOWN
  environment:  target(s) deben estar en config/allowed-targets.local.yaml
  license:      si se detecta uso de Active Data Guard sin confirmar licencia, LICENSE_RESTRICTED con required_action LICENSE_CHECK_REQUIRED, el resto del workflow continúa
  privilege:    ESTACK_DIAGNOSTIC_ROLE debe alcanzar V$DATAGUARD_STATS/V$ARCHIVE_DEST_STATUS en cada sitio accesible
  security:     ninguna query requerida puede tener risk_class fuera de R0; ninguna tool de switchover/failover existe en el catálogo
  cost:         Q-DG-STATS-001/Q-DG-ARCHIVE-GAP-001 son cost_class LOW
  evidence:     si sólo hay acceso a un sitio, continúa con lo disponible y declara explícitamente qué no pudo confirmarse desde el otro
```

---
name: healthcheck
version: 2.0.0
status: active
---

# Trigger/intent

Comando `/healthcheck`. Solicitud general de salud de un target Oracle (todo el ambiente o un módulo específico). Invocaciones acotadas por módulo (Fase 4): `/healthcheck rac` (orquesta `rac/healthcheck`), `/healthcheck asm` (orquesta `asm/healthcheck`), `/healthcheck network` (orquesta `network/healthcheck`) — cada una activa únicamente el agente correspondiente, sin recorrer Oracle Core completo.

# Prerequisites

Target identificado (alias de conexión read-only ya configurado en `config/allowed-targets.local.yaml`).

# Discovery requirements

`oracle-discovery-analyst` obligatorio si no hay cache de discovery válido para el target (TTL en `config/estack.config.example.yaml`).

# Minimum agents

`oracle-operations-orchestrator`, `oracle-discovery-analyst` (si no cacheado), `oracle-dba-analyst`.

# Optional agents

`oracle-performance-analyst` (si `constraints.include_performance = true` o el DBA lo pide), `oracle-rac-analyst` (si discovery reporta RAC), `oracle-asm-storage-analyst` (si `storage_mode = asm`), `oracle-dataguard-analyst` (si hay standby configurado), `oracle-multitenant-analyst` (si `container_mode = cdb`), `oracle-backup-recovery-analyst`, `oracle-network-analyst`, `oracle-security-analyst`, `os-platform-analyst`, `capacity-analyst`.

# Activation conditions

- RAC → activa `oracle-rac-analyst` sólo si `architecture.cluster_mode = rac` (Target Profile; ver `target_profile.rac.enabled`).
- ASM → activa `oracle-asm-storage-analyst` sólo si `architecture.storage_mode = asm` (`target_profile.asm.enabled`).
- Network → `oracle-network-analyst` se activa junto con `oracle-rac-analyst` en `/healthcheck rac`/`/healthcheck` completo cuando hay SCAN configurado, o de forma independiente vía `/healthcheck network`.
- Data Guard → activa `oracle-dataguard-analyst` sólo si discovery confirma standby asociado o `database_role != primary` sin standby (para reportar el gap).
- CDB → activa `oracle-multitenant-analyst` sólo si `architecture.multitenant_mode = cdb`.
- El resto de agentes opcionales sólo se activan si el DBA los pide explícitamente o si `oracle-dba-analyst` reporta un hallazgo que los amerita (ver `Escalation`).

# Skills

`core/context-discovery`, `core/version-awareness` (vía discovery); `oracle-dba-analyst` activa, según `constraints.area_scope` o por defecto todas, las 18 skills Oracle Core (`oracle/database-state`, `oracle/instance`, `oracle/parameters`, `oracle/spfile`, `oracle/controlfile`, `oracle/redo`, `oracle/archive`, `oracle/tablespaces`, `oracle/temp`, `oracle/undo`, `oracle/sessions`, `oracle/processes`, `oracle/jobs`, `oracle/objects`, `oracle/components`, `oracle/invalid-objects`, `oracle/resource-limits`, `oracle/diagnostics`) — ver `agents/oracle-dba-analyst/AGENT.md#responsibilities`.

# Evidence required

`Q-DISC-IDENTITY-001`, `Q-DISC-INSTANCE-001`, `Q-DBA-TBS-USAGE-001` como mínimo del Target Profile + tablespaces; el resto de las ~20 queries `Q-ORA-*` de Oracle Core (ver `queries/REGISTRY.md#oracle-core-queries-fase-2`) según las áreas efectivamente activadas.

# Stop conditions

Discovery no puede confirmar identidad/rol del target con al menos `OBSERVATION`; target no accesible en modo read-only.

# Confidence threshold

Hallazgos se reportan como `PROBABLE_CAUSE` sólo si hay al menos una correlación entre dos fuentes de evidencia; si no, quedan como `OBSERVATION`/`HYPOTHESIS`.

# Escalation

Un hallazgo `HIGH` de `oracle-dba-analyst` (ej. tablespace crítico) activa `capacity-analyst` para forecast y `change-advisor` para propuesta. Múltiples hallazgos correlacionables activan `incident-root-cause-analyst`.

# Documentation output

`analysis/ANA-YYYYMMDD-NNN/` completo (`analysis.md, context.md, evidence.md, findings.md, recommendations.md, proposed-changes.md, metadata.yaml, evidence-manifest.json`) vía `documentation/healthcheck-report`.

# Token/context budget

Medio: acotado a discovery + agentes mínimos; cada agente opcional suma su propio presupuesto sólo si se activa.

# Security constraints

READ-ONLY ALWAYS. Identidad `ESTACK_DIAG_*`. Ningún agente activado puede ejecutar remediación — sólo `change-advisor` genera texto para ejecución humana.

# Gates

```yaml
gates:
  version:      config/capability-matrix.yaml → Oracle Core/Performance deben ser al menos FOUNDATION_ONLY para la versión detectada
  architecture: activa oracle-rac-analyst/oracle-asm-storage-analyst/oracle-multitenant-analyst/oracle-dataguard-analyst SÓLO si discovery confirma esa arquitectura (ver Activation conditions)
  environment:  target debe estar en config/allowed-targets.local.yaml
  license:      si include_performance=true y no hay Diagnostics Pack confirmado, performance queda LICENSE_RESTRICTED con fallback a Statspack, no bloquea el resto del healthcheck
  privilege:    ESTACK_DIAGNOSTIC_ROLE debe alcanzar para Q-DISC-IDENTITY-001/Q-DISC-INSTANCE-001/Q-DBA-TBS-USAGE-001 como mínimo
  security:     ninguna query requerida puede tener risk_class fuera de R0
  cost:         queries cost_class HIGH no se activan automáticamente en /healthcheck (ver policies/query-cost-policy.md) salvo pedido explícito
  evidence:     reutiliza discovery cache si el TTL de config/estack.config.example.yaml no venció
```

# Skill Registry

Catálogo completo de skills (sección 9 del prompt maestro). Todo skill nuevo o modificado sigue el [Skill Contract](../docs/CONTRACTS.md#skill-contract) y el flujo `/change skill`.

## Regla de identificador canónico (Foundation Hardening)

> `skill_id` must always be globally unique and domain-qualified.

Este registro identifica cada skill **exclusivamente** por su `skill_id` completamente calificado (`dominio/skill`, columna "skill_id"). Nombres cortos como `temp`, `undo`, `sga`, `pga`, `services`, `memory`, `io` **no son identificadores válidos** — existen legítimamente en varios dominios (`oracle/temp` ≠ `performance/temp` ≠ `capacity/temp`; `performance/sga` ≠ `capacity/sga`) y sólo tienen sentido calificados. Ningún agente, workflow, skill u otro documento puede referenciar un skill por su nombre corto — siempre por `skill_id` completo tal como aparece en este registro. Un nombre corto sólo es válido como `display_name` (presentación en UI/reportes), nunca como identificador operativo. Validado por `tests/test_skill_ids_are_globally_unique.sh`, `tests/test_skill_ids_are_domain_qualified.sh`, `tests/test_no_ambiguous_skill_references.sh`.

**Status:**
- `active` — materializado por completo (19 secciones del Skill Contract), archivo real en el dominio.
- `registered` — nombre, dominio y propósito fijados en este registro; su materialización completa es Fase 2+ según `README.md#fases-de-construcción`. No es un placeholder vacío: es la entrada de catálogo que gobierna qué se puede construir y en qué orden vía `/change skill`.

Fase 1 materializó **un ejemplo representativo completo por dominio** (14); Foundation Hardening agregó `core/version-awareness` (15); **Fase 2 (Oracle Core) materializa las 18 skills del dominio `oracle` completo** (32 activos en total); **Fase 3 (Oracle Performance) materializa las 31 skills del dominio `performance` completo** (63 activos en total); **Fase 4 (RAC/GI/ASM/Network) materializa 57 skills — dominio `rac` completo (31: 19 RAC + 12 GI), `asm` completo (12), `network` completo (14)** (120 activos en total); **Fase 5 (Data Guard) materializa las 21 skills del dominio `dataguard` completo** (141 activos en total); **Fase 6 (Multitenant/CDB/PDB) materializa las 26 skills del dominio `multitenant` completo** (166 activos en total); **Fase 7 (Backup & Recovery/RMAN) materializa las 30 skills del dominio `rman` completo** (196 activos en total); **Fase 8 (Security & Compliance) materializa las 39 skills del dominio `security` completo, genuinamente nuevo** (235 activos en total); **PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING agrega `network/oracle-net-security`** (236 activos en total). El resto queda `registered` para materialización gobernada en Fase 9, en el orden de `README.md`.

## core (20)

| skill_id | status |
|---|---|
| `core/context-discovery` | **active** ([core/context-discovery.md](core/context-discovery.md)) |
| `core/environment-classification` | registered |
| `core/evidence-collection` | registered |
| `core/evidence-validation` | registered |
| `core/evidence-referencing` | registered |
| `core/hypothesis-generation` | registered |
| `core/hypothesis-validation` | registered |
| `core/root-cause-analysis` | registered |
| `core/risk-classification` | registered |
| `core/recommendation-generation` | registered |
| `core/change-proposal` | registered |
| `core/command-generation` | registered |
| `core/rollback-generation` | registered |
| `core/postcheck-generation` | registered |
| `core/confidence-scoring` | registered |
| `core/version-awareness` | **active** ([core/version-awareness.md](core/version-awareness.md)) — agregado en Foundation Hardening |
| `core/platform-awareness` | registered |
| `core/data-minimization` | registered |
| `core/redaction` | registered |
| `core/reporting` | registered |

## oracle (18) — completo desde Fase 2 (Oracle Core)

Todos materializados con estructura `skills/oracle/<skill>/SKILL.md` + `manifest.yaml`.

| skill_id | status |
|---|---|
| `oracle/database-state` | **active** ([oracle/database-state/SKILL.md](oracle/database-state/SKILL.md)) |
| `oracle/instance` | **active** ([oracle/instance/SKILL.md](oracle/instance/SKILL.md)) |
| `oracle/parameters` | **active** ([oracle/parameters/SKILL.md](oracle/parameters/SKILL.md)) |
| `oracle/spfile` | **active** ([oracle/spfile/SKILL.md](oracle/spfile/SKILL.md)) |
| `oracle/controlfile` | **active** ([oracle/controlfile/SKILL.md](oracle/controlfile/SKILL.md)) |
| `oracle/redo` | **active** ([oracle/redo/SKILL.md](oracle/redo/SKILL.md)) |
| `oracle/archive` | **active** ([oracle/archive/SKILL.md](oracle/archive/SKILL.md)) |
| `oracle/tablespaces` | **active** ([oracle/tablespaces/SKILL.md](oracle/tablespaces/SKILL.md)) — materializado en Fase 1, extendido en Fase 2 |
| `oracle/temp` | **active** ([oracle/temp/SKILL.md](oracle/temp/SKILL.md)) |
| `oracle/undo` | **active** ([oracle/undo/SKILL.md](oracle/undo/SKILL.md)) |
| `oracle/sessions` | **active** ([oracle/sessions/SKILL.md](oracle/sessions/SKILL.md)) |
| `oracle/processes` | **active** ([oracle/processes/SKILL.md](oracle/processes/SKILL.md)) |
| `oracle/jobs` | **active** ([oracle/jobs/SKILL.md](oracle/jobs/SKILL.md)) |
| `oracle/objects` | **active** ([oracle/objects/SKILL.md](oracle/objects/SKILL.md)) |
| `oracle/components` | **active** ([oracle/components/SKILL.md](oracle/components/SKILL.md)) |
| `oracle/invalid-objects` | **active** ([oracle/invalid-objects/SKILL.md](oracle/invalid-objects/SKILL.md)) |
| `oracle/resource-limits` | **active** ([oracle/resource-limits/SKILL.md](oracle/resource-limits/SKILL.md)) |
| `oracle/diagnostics` | **active** ([oracle/diagnostics/SKILL.md](oracle/diagnostics/SKILL.md)) |

## performance (31)

| skill_id | status |
|---|---|
| `performance/awr-analysis` | **active** ([performance/awr-analysis/SKILL.md](performance/awr-analysis/SKILL.md)) |
| `performance/ash-analysis` | **active** ([performance/ash-analysis/SKILL.md](performance/ash-analysis/SKILL.md)) |
| `performance/statspack-analysis` | **active** ([performance/statspack-analysis/SKILL.md](performance/statspack-analysis/SKILL.md)) |
| `performance/addm-analysis` | **active** ([performance/addm-analysis/SKILL.md](performance/addm-analysis/SKILL.md)) |
| `performance/db-time` | **active** ([performance/db-time/SKILL.md](performance/db-time/SKILL.md)) |
| `performance/db-cpu` | **active** ([performance/db-cpu/SKILL.md](performance/db-cpu/SKILL.md)) |
| `performance/load-profile` | **active** ([performance/load-profile/SKILL.md](performance/load-profile/SKILL.md)) |
| `performance/wait-events` | **active** ([performance/wait-events/SKILL.md](performance/wait-events/SKILL.md)) |
| `performance/wait-classes` | **active** ([performance/wait-classes/SKILL.md](performance/wait-classes/SKILL.md)) |
| `performance/top-sql` | **active** ([performance/top-sql/SKILL.md](performance/top-sql/SKILL.md)) |
| `performance/sql-cpu` | **active** ([performance/sql-cpu/SKILL.md](performance/sql-cpu/SKILL.md)) |
| `performance/sql-elapsed` | **active** ([performance/sql-elapsed/SKILL.md](performance/sql-elapsed/SKILL.md)) |
| `performance/sql-io` | **active** ([performance/sql-io/SKILL.md](performance/sql-io/SKILL.md)) |
| `performance/sql-executions` | **active** ([performance/sql-executions/SKILL.md](performance/sql-executions/SKILL.md)) |
| `performance/execution-plan` | **active** ([performance/execution-plan/SKILL.md](performance/execution-plan/SKILL.md)) |
| `performance/plan-regression` | **active** ([performance/plan-regression/SKILL.md](performance/plan-regression/SKILL.md)) |
| `performance/sga` | **active** ([performance/sga/SKILL.md](performance/sga/SKILL.md)) |
| `performance/pga` | **active** ([performance/pga/SKILL.md](performance/pga/SKILL.md)) |
| `performance/memory` | **active** ([performance/memory/SKILL.md](performance/memory/SKILL.md)) |
| `performance/hard-parse` | **active** ([performance/hard-parse/SKILL.md](performance/hard-parse/SKILL.md)) |
| `performance/library-cache` | **active** ([performance/library-cache/SKILL.md](performance/library-cache/SKILL.md)) |
| `performance/shared-pool` | **active** ([performance/shared-pool/SKILL.md](performance/shared-pool/SKILL.md)) |
| `performance/io` | **active** ([performance/io/SKILL.md](performance/io/SKILL.md)) |
| `performance/temp` | **active** ([performance/temp/SKILL.md](performance/temp/SKILL.md)) |
| `performance/undo` | **active** ([performance/undo/SKILL.md](performance/undo/SKILL.md)) |
| `performance/concurrency` | **active** ([performance/concurrency/SKILL.md](performance/concurrency/SKILL.md)) |
| `performance/locking` | **active** ([performance/locking/SKILL.md](performance/locking/SKILL.md)) |
| `performance/blocking` | **active** ([performance/blocking/SKILL.md](performance/blocking/SKILL.md)) |
| `performance/parallelism` | **active** ([performance/parallelism/SKILL.md](performance/parallelism/SKILL.md)) |
| `performance/commit-redo` | **active** ([performance/commit-redo/SKILL.md](performance/commit-redo/SKILL.md)) |
| `performance/trending` | **active** ([performance/trending/SKILL.md](performance/trending/SKILL.md)) |

## rac (31 — Fase 4: 19 RAC + 12 GI, todos `active`)

Fase 4 (RAC/GI/ASM/Network) materializa el dominio `rac` completo y **reconcilia** la lista `registered` heredada de Foundation con los nombres realmente construidos — varios nombres Foundation eran especulativos y se consolidaron o renombraron antes de materializarse (ninguno estaba `active`, por lo que no hay ruptura de contrato): `cluster-health`/`node-health`/`instance-health` → `instance-state` + `node-membership`; `crs-resources` → `cluster-resources`; `cache-fusion`/`gcs`/`ges`/`gc-waits`/`global-enqueues` → `global-cache` (un único skill, evita fragmentación de una misma evidencia `GV$GES_STATISTICS`/`GV$GCS_STATISTICS`); `ocr`/`voting-disk` → `gi-ocr-status`/`gi-voting-status` (movidos a la sub-familia GI); `node-eviction` → `instance-eviction`; `service-failover-analysis`/`instance-failover-analysis` → `failover` (unificado); `session-imbalance-analysis` → absorbido en `session-distribution`/`load-balancing`; `fan`/`taf` → metadata narrativa en `agents/oracle-rac-analyst/AGENT.md`, no `skill_id` propio (no hay query/collector certificado independiente todavía). Grid Infrastructure vive en este mismo dominio con prefijo `gi-` (`# 8` del prompt de Fase 4: "si ya existe categoría rac/, mantener GI allí") — decisión documentada en `docs/PHASE_4_RAC_GI_ASM_NETWORK.md#gi-skill-placement`.

| skill_id | status |
|---|---|
| `rac/topology` | **active** ([rac/topology/SKILL.md](rac/topology/SKILL.md)) |
| `rac/instance-state` | **active** ([rac/instance-state/SKILL.md](rac/instance-state/SKILL.md)) |
| `rac/node-membership` | **active** ([rac/node-membership/SKILL.md](rac/node-membership/SKILL.md)) |
| `rac/cluster-resources` | **active** ([rac/cluster-resources/SKILL.md](rac/cluster-resources/SKILL.md)) |
| `rac/services` | **active** ([rac/services/SKILL.md](rac/services/SKILL.md)) |
| `rac/service-placement` | **active** ([rac/service-placement/SKILL.md](rac/service-placement/SKILL.md)) |
| `rac/session-distribution` | **active** ([rac/session-distribution/SKILL.md](rac/session-distribution/SKILL.md)) |
| `rac/service-session-distribution` | **active** ([rac/service-session-distribution/SKILL.md](rac/service-session-distribution/SKILL.md)) |
| `rac/load-balancing` | **active** ([rac/load-balancing/SKILL.md](rac/load-balancing/SKILL.md)) |
| `rac/clb` | **active** ([rac/clb/SKILL.md](rac/clb/SKILL.md)) |
| `rac/rlb` | **active** ([rac/rlb/SKILL.md](rac/rlb/SKILL.md)) |
| `rac/failover` | **active** ([rac/failover/SKILL.md](rac/failover/SKILL.md)) |
| `rac/interconnect` | **active** ([rac/interconnect/SKILL.md](rac/interconnect/SKILL.md)) |
| `rac/global-cache` | **active** ([rac/global-cache/SKILL.md](rac/global-cache/SKILL.md)) |
| `rac/instance-eviction` | **active** ([rac/instance-eviction/SKILL.md](rac/instance-eviction/SKILL.md)) |
| `rac/configuration-drift` | **active** ([rac/configuration-drift/SKILL.md](rac/configuration-drift/SKILL.md)) |
| `rac/healthcheck` | **active** ([rac/healthcheck/SKILL.md](rac/healthcheck/SKILL.md)) |
| `rac/assessment` | **active** ([rac/assessment/SKILL.md](rac/assessment/SKILL.md)) |
| `rac/troubleshooting` | **active** ([rac/troubleshooting/SKILL.md](rac/troubleshooting/SKILL.md)) |
| `rac/gi-version` | **active** ([rac/gi-version/SKILL.md](rac/gi-version/SKILL.md)) |
| `rac/gi-node-status` | **active** ([rac/gi-node-status/SKILL.md](rac/gi-node-status/SKILL.md)) |
| `rac/gi-resource-status` | **active** ([rac/gi-resource-status/SKILL.md](rac/gi-resource-status/SKILL.md)) |
| `rac/gi-resource-properties` | **active** ([rac/gi-resource-properties/SKILL.md](rac/gi-resource-properties/SKILL.md)) |
| `rac/gi-scan` | **active** ([rac/gi-scan/SKILL.md](rac/gi-scan/SKILL.md)) |
| `rac/gi-vip` | **active** ([rac/gi-vip/SKILL.md](rac/gi-vip/SKILL.md)) |
| `rac/gi-listeners` | **active** ([rac/gi-listeners/SKILL.md](rac/gi-listeners/SKILL.md)) |
| `rac/gi-network-interfaces` | **active** ([rac/gi-network-interfaces/SKILL.md](rac/gi-network-interfaces/SKILL.md)) |
| `rac/gi-ocr-status` | **active** ([rac/gi-ocr-status/SKILL.md](rac/gi-ocr-status/SKILL.md)) |
| `rac/gi-voting-status` | **active** ([rac/gi-voting-status/SKILL.md](rac/gi-voting-status/SKILL.md)) |
| `rac/gi-cluster-health` | **active** ([rac/gi-cluster-health/SKILL.md](rac/gi-cluster-health/SKILL.md)) |
| `rac/gi-configuration-consistency` | **active** ([rac/gi-configuration-consistency/SKILL.md](rac/gi-configuration-consistency/SKILL.md)) |

## asm (12 — Fase 4, todos `active`)

| skill_id | status |
|---|---|
| `asm/topology` | **active** ([asm/topology/SKILL.md](asm/topology/SKILL.md)) |
| `asm/instances` | **active** ([asm/instances/SKILL.md](asm/instances/SKILL.md)) |
| `asm/diskgroups` | **active** ([asm/diskgroups/SKILL.md](asm/diskgroups/SKILL.md)) |
| `asm/capacity` | **active** ([asm/capacity/SKILL.md](asm/capacity/SKILL.md)) |
| `asm/redundancy` | **active** ([asm/redundancy/SKILL.md](asm/redundancy/SKILL.md)) |
| `asm/disks` | **active** ([asm/disks/SKILL.md](asm/disks/SKILL.md)) |
| `asm/failure-groups` | **active** ([asm/failure-groups/SKILL.md](asm/failure-groups/SKILL.md)) |
| `asm/rebalance` | **active** ([asm/rebalance/SKILL.md](asm/rebalance/SKILL.md)) |
| `asm/operations` | **active** ([asm/operations/SKILL.md](asm/operations/SKILL.md)) |
| `asm/healthcheck` | **active** ([asm/healthcheck/SKILL.md](asm/healthcheck/SKILL.md)) |
| `asm/assessment` | **active** ([asm/assessment/SKILL.md](asm/assessment/SKILL.md)) |
| `asm/troubleshooting` | **active** ([asm/troubleshooting/SKILL.md](asm/troubleshooting/SKILL.md)) |

## dataguard (21 — Fase 5, todos `active`)

Reconciliación de la lista Foundation (sólo `lag` estaba `active`): `discovery` → absorbido en `topology`/`role` (sin skill_id propio); `protection-mode` → `protection`; `archive-gap` → `archive-gaps`; `mrp`/`rfs` → absorbidos en `apply` (estado MRP) + `processes` (RFS/LNS/LGWR/ARCH/DGRD unificados); `srl` → `standby-redo-logs`; `services`/`network`/`performance` → sin skill_id propio, correlación cross-domain narrativa vía delegación a `oracle-rac-analyst`/`oracle-network-analyst`/`oracle-performance-analyst` (ver `agents/oracle-dataguard-analyst/AGENT.md#correlation-model`); `readiness` → dividido en `switchover-readiness` + `failover-readiness` (`# 31` del prompt de Fase 5: nunca el mismo workflow). Nuevos: `topology`, `real-time-apply`, `fsfo`, `observer`, `configuration-drift`, `healthcheck`, `assessment`, `incident-analysis`.

| skill_id | status |
|---|---|
| `dataguard/topology` | **active** ([dataguard/topology/SKILL.md](dataguard/topology/SKILL.md)) |
| `dataguard/role` | **active** ([dataguard/role/SKILL.md](dataguard/role/SKILL.md)) |
| `dataguard/protection` | **active** ([dataguard/protection/SKILL.md](dataguard/protection/SKILL.md)) |
| `dataguard/transport` | **active** ([dataguard/transport/SKILL.md](dataguard/transport/SKILL.md)) |
| `dataguard/apply` | **active** ([dataguard/apply/SKILL.md](dataguard/apply/SKILL.md)) |
| `dataguard/lag` | **active** ([dataguard/lag/SKILL.md](dataguard/lag/SKILL.md)) |
| `dataguard/archive-gaps` | **active** ([dataguard/archive-gaps/SKILL.md](dataguard/archive-gaps/SKILL.md)) |
| `dataguard/archive-destinations` | **active** ([dataguard/archive-destinations/SKILL.md](dataguard/archive-destinations/SKILL.md)) |
| `dataguard/processes` | **active** ([dataguard/processes/SKILL.md](dataguard/processes/SKILL.md)) |
| `dataguard/standby-redo-logs` | **active** ([dataguard/standby-redo-logs/SKILL.md](dataguard/standby-redo-logs/SKILL.md)) |
| `dataguard/real-time-apply` | **active** ([dataguard/real-time-apply/SKILL.md](dataguard/real-time-apply/SKILL.md)) |
| `dataguard/broker` | **active** ([dataguard/broker/SKILL.md](dataguard/broker/SKILL.md)) |
| `dataguard/fsfo` | **active** ([dataguard/fsfo/SKILL.md](dataguard/fsfo/SKILL.md)) |
| `dataguard/observer` | **active** ([dataguard/observer/SKILL.md](dataguard/observer/SKILL.md)) |
| `dataguard/switchover-readiness` | **active** ([dataguard/switchover-readiness/SKILL.md](dataguard/switchover-readiness/SKILL.md)) |
| `dataguard/failover-readiness` | **active** ([dataguard/failover-readiness/SKILL.md](dataguard/failover-readiness/SKILL.md)) |
| `dataguard/configuration-drift` | **active** ([dataguard/configuration-drift/SKILL.md](dataguard/configuration-drift/SKILL.md)) |
| `dataguard/healthcheck` | **active** ([dataguard/healthcheck/SKILL.md](dataguard/healthcheck/SKILL.md)) |
| `dataguard/assessment` | **active** ([dataguard/assessment/SKILL.md](dataguard/assessment/SKILL.md)) |
| `dataguard/troubleshooting` | **active** ([dataguard/troubleshooting/SKILL.md](dataguard/troubleshooting/SKILL.md)) |
| `dataguard/incident-analysis` | **active** ([dataguard/incident-analysis/SKILL.md](dataguard/incident-analysis/SKILL.md)) |

## multitenant (26 — Fase 6, todos active)

> **Fase 6**: reconciliación de la lista Foundation (12 nombres `registered`, sólo `container-state` activo) a las 26 skills reales del dominio `multitenant` completo. Mapeo: `discovery`/`cdb`→`cdb-discovery`, `pdb`→`pdb-inventory`, `container-state`→`pdb-state` (migrado, contenido expandido — `multitenant/container-state.md` eliminado), `services`→`pdb-services`, `storage`→`pdb-tablespaces`, `temp`→`pdb-temp`, `undo`→`pdb-undo`, `resource-manager`→`resource-manager` (sin cambio de nombre), `common-users`/`local-users`→`common-local-users`/`common-local-roles` (separados por identidad de usuario vs. rol), `troubleshooting`→`troubleshooting` (sin cambio). Nuevos sin equivalente Foundation: `architecture`, `pdb-open-mode`, `pdb-rac-placement`, `pdb-sessions`, `local-undo`, `parameters`, `components`, `plugin-violations`, `resource-usage`, `lockdown-profiles`, `application-containers`, `proxy-pdb`, `configuration-drift`, `healthcheck`, `assessment`.

| skill_id | status |
|---|---|
| `multitenant/architecture` | **active** ([multitenant/architecture/SKILL.md](multitenant/architecture/SKILL.md)) |
| `multitenant/cdb-discovery` | **active** ([multitenant/cdb-discovery/SKILL.md](multitenant/cdb-discovery/SKILL.md)) |
| `multitenant/pdb-inventory` | **active** ([multitenant/pdb-inventory/SKILL.md](multitenant/pdb-inventory/SKILL.md)) |
| `multitenant/pdb-state` | **active** ([multitenant/pdb-state/SKILL.md](multitenant/pdb-state/SKILL.md)) |
| `multitenant/pdb-open-mode` | **active** ([multitenant/pdb-open-mode/SKILL.md](multitenant/pdb-open-mode/SKILL.md)) |
| `multitenant/pdb-services` | **active** ([multitenant/pdb-services/SKILL.md](multitenant/pdb-services/SKILL.md)) |
| `multitenant/pdb-rac-placement` | **active** ([multitenant/pdb-rac-placement/SKILL.md](multitenant/pdb-rac-placement/SKILL.md)) |
| `multitenant/pdb-sessions` | **active** ([multitenant/pdb-sessions/SKILL.md](multitenant/pdb-sessions/SKILL.md)) |
| `multitenant/pdb-tablespaces` | **active** ([multitenant/pdb-tablespaces/SKILL.md](multitenant/pdb-tablespaces/SKILL.md)) |
| `multitenant/pdb-temp` | **active** ([multitenant/pdb-temp/SKILL.md](multitenant/pdb-temp/SKILL.md)) |
| `multitenant/pdb-undo` | **active** ([multitenant/pdb-undo/SKILL.md](multitenant/pdb-undo/SKILL.md)) |
| `multitenant/local-undo` | **active** ([multitenant/local-undo/SKILL.md](multitenant/local-undo/SKILL.md)) |
| `multitenant/parameters` | **active** ([multitenant/parameters/SKILL.md](multitenant/parameters/SKILL.md)) |
| `multitenant/common-local-users` | **active** ([multitenant/common-local-users/SKILL.md](multitenant/common-local-users/SKILL.md)) |
| `multitenant/common-local-roles` | **active** ([multitenant/common-local-roles/SKILL.md](multitenant/common-local-roles/SKILL.md)) |
| `multitenant/components` | **active** ([multitenant/components/SKILL.md](multitenant/components/SKILL.md)) |
| `multitenant/plugin-violations` | **active** ([multitenant/plugin-violations/SKILL.md](multitenant/plugin-violations/SKILL.md)) |
| `multitenant/resource-usage` | **active** ([multitenant/resource-usage/SKILL.md](multitenant/resource-usage/SKILL.md)) |
| `multitenant/resource-manager` | **active** ([multitenant/resource-manager/SKILL.md](multitenant/resource-manager/SKILL.md)) |
| `multitenant/lockdown-profiles` | **active** ([multitenant/lockdown-profiles/SKILL.md](multitenant/lockdown-profiles/SKILL.md)) |
| `multitenant/application-containers` | **active** ([multitenant/application-containers/SKILL.md](multitenant/application-containers/SKILL.md)) |
| `multitenant/proxy-pdb` | **active** ([multitenant/proxy-pdb/SKILL.md](multitenant/proxy-pdb/SKILL.md)) |
| `multitenant/configuration-drift` | **active** ([multitenant/configuration-drift/SKILL.md](multitenant/configuration-drift/SKILL.md)) |
| `multitenant/healthcheck` | **active** ([multitenant/healthcheck/SKILL.md](multitenant/healthcheck/SKILL.md)) |
| `multitenant/assessment` | **active** ([multitenant/assessment/SKILL.md](multitenant/assessment/SKILL.md)) |
| `multitenant/troubleshooting` | **active** ([multitenant/troubleshooting/SKILL.md](multitenant/troubleshooting/SKILL.md)) |

## rman (30 — Fase 7, todos `active`)

Reemplaza el placeholder de 14 skills `registered` de Foundation (nombres provisionales: `rman/backup-history`, `rman/sbt`, `rman/controlfile`, `rman/spfile`, `rman/archivelog`, `rman/rac`, `rman/dataguard`, `rman/performance` nunca materializados) — la única excepción `active` de Foundation (`rman/backup-status.md`, plano) fue reestructurada a carpeta completa, mismo patrón que `oracle-multitenant-analyst.md` en Fase 6.

| skill_id | status |
|---|---|
| `rman/configuration` | **active** ([rman/configuration/SKILL.md](rman/configuration/SKILL.md)) |
| `rman/backup-inventory` | **active** ([rman/backup-inventory/SKILL.md](rman/backup-inventory/SKILL.md)) |
| `rman/backup-status` | **active** ([rman/backup-status/SKILL.md](rman/backup-status/SKILL.md)) |
| `rman/backup-freshness` | **active** ([rman/backup-freshness/SKILL.md](rman/backup-freshness/SKILL.md)) |
| `rman/backup-duration` | **active** ([rman/backup-duration/SKILL.md](rman/backup-duration/SKILL.md)) |
| `rman/backup-throughput` | **active** ([rman/backup-throughput/SKILL.md](rman/backup-throughput/SKILL.md)) |
| `rman/full-backup` | **active** ([rman/full-backup/SKILL.md](rman/full-backup/SKILL.md)) |
| `rman/incremental-backup` | **active** ([rman/incremental-backup/SKILL.md](rman/incremental-backup/SKILL.md)) |
| `rman/archivelog-backup` | **active** ([rman/archivelog-backup/SKILL.md](rman/archivelog-backup/SKILL.md)) |
| `rman/controlfile-backup` | **active** ([rman/controlfile-backup/SKILL.md](rman/controlfile-backup/SKILL.md)) |
| `rman/spfile-backup` | **active** ([rman/spfile-backup/SKILL.md](rman/spfile-backup/SKILL.md)) |
| `rman/retention-policy` | **active** ([rman/retention-policy/SKILL.md](rman/retention-policy/SKILL.md)) |
| `rman/backup-optimization` | **active** ([rman/backup-optimization/SKILL.md](rman/backup-optimization/SKILL.md)) |
| `rman/channels` | **active** ([rman/channels/SKILL.md](rman/channels/SKILL.md)) |
| `rman/device-types` | **active** ([rman/device-types/SKILL.md](rman/device-types/SKILL.md)) |
| `rman/sbt-media-manager` | **active** ([rman/sbt-media-manager/SKILL.md](rman/sbt-media-manager/SKILL.md)) |
| `rman/fra` | **active** ([rman/fra/SKILL.md](rman/fra/SKILL.md)) |
| `rman/fra-pressure` | **active** ([rman/fra-pressure/SKILL.md](rman/fra-pressure/SKILL.md)) |
| `rman/obsolete-expired-awareness` | **active** ([rman/obsolete-expired-awareness/SKILL.md](rman/obsolete-expired-awareness/SKILL.md)) |
| `rman/snapshot-controlfile` | **active** ([rman/snapshot-controlfile/SKILL.md](rman/snapshot-controlfile/SKILL.md)) |
| `rman/rac-awareness` | **active** ([rman/rac-awareness/SKILL.md](rman/rac-awareness/SKILL.md)) |
| `rman/dataguard-awareness` | **active** ([rman/dataguard-awareness/SKILL.md](rman/dataguard-awareness/SKILL.md)) |
| `rman/multitenant-awareness` | **active** ([rman/multitenant-awareness/SKILL.md](rman/multitenant-awareness/SKILL.md)) |
| `rman/restore-readiness` | **active** ([rman/restore-readiness/SKILL.md](rman/restore-readiness/SKILL.md)) |
| `rman/recovery-readiness` | **active** ([rman/recovery-readiness/SKILL.md](rman/recovery-readiness/SKILL.md)) |
| `rman/pitr-readiness` | **active** ([rman/pitr-readiness/SKILL.md](rman/pitr-readiness/SKILL.md)) |
| `rman/pdb-pitr-awareness` | **active** ([rman/pdb-pitr-awareness/SKILL.md](rman/pdb-pitr-awareness/SKILL.md)) |
| `rman/troubleshooting` | **active** ([rman/troubleshooting/SKILL.md](rman/troubleshooting/SKILL.md)) |
| `rman/channel-contention` | **active** ([rman/channel-contention/SKILL.md](rman/channel-contention/SKILL.md)) |
| `rman/manual-recovery-plan` | **active** ([rman/manual-recovery-plan/SKILL.md](rman/manual-recovery-plan/SKILL.md)) |

## security (39 — Fase 8, todos `active`)

Dominio `security` genuinamente nuevo — no existía ninguna entrada `registered` previa que
reconciliar (a diferencia de RMAN/Multitenant). El agente `oracle-security-analyst` sí existía
como manifest plano desde Foundation (deepened en esta fase, ver `agents/REGISTRY.md`), pero sus
skills nunca se materializaron.

| skill_id | status |
|---|---|
| `security/account-inventory` | **active** ([security/account-inventory/SKILL.md](security/account-inventory/SKILL.md)) |
| `security/account-status` | **active** ([security/account-status/SKILL.md](security/account-status/SKILL.md)) |
| `security/default-accounts` | **active** ([security/default-accounts/SKILL.md](security/default-accounts/SKILL.md)) |
| `security/stale-accounts` | **active** ([security/stale-accounts/SKILL.md](security/stale-accounts/SKILL.md)) |
| `security/common-local-users` | **active** ([security/common-local-users/SKILL.md](security/common-local-users/SKILL.md)) |
| `security/roles` | **active** ([security/roles/SKILL.md](security/roles/SKILL.md)) |
| `security/system-privileges` | **active** ([security/system-privileges/SKILL.md](security/system-privileges/SKILL.md)) |
| `security/object-privileges` | **active** ([security/object-privileges/SKILL.md](security/object-privileges/SKILL.md)) |
| `security/powerful-privileges` | **active** ([security/powerful-privileges/SKILL.md](security/powerful-privileges/SKILL.md)) |
| `security/public-grants` | **active** ([security/public-grants/SKILL.md](security/public-grants/SKILL.md)) |
| `security/admin-privileges` | **active** ([security/admin-privileges/SKILL.md](security/admin-privileges/SKILL.md)) |
| `security/proxy-authentication` | **active** ([security/proxy-authentication/SKILL.md](security/proxy-authentication/SKILL.md)) |
| `security/external-authentication` | **active** ([security/external-authentication/SKILL.md](security/external-authentication/SKILL.md)) |
| `security/password-profiles` | **active** ([security/password-profiles/SKILL.md](security/password-profiles/SKILL.md)) |
| `security/password-policy-strength` | **active** ([security/password-policy-strength/SKILL.md](security/password-policy-strength/SKILL.md)) |
| `security/password-complexity` | **active** ([security/password-complexity/SKILL.md](security/password-complexity/SKILL.md)) |
| `security/password-verify-function` | **active** ([security/password-verify-function/SKILL.md](security/password-verify-function/SKILL.md)) |
| `security/password-verifiers` | **active** ([security/password-verifiers/SKILL.md](security/password-verifiers/SKILL.md)) |
| `security/audit-configuration` | **active** ([security/audit-configuration/SKILL.md](security/audit-configuration/SKILL.md)) |
| `security/unified-auditing` | **active** ([security/unified-auditing/SKILL.md](security/unified-auditing/SKILL.md)) |
| `security/traditional-auditing` | **active** ([security/traditional-auditing/SKILL.md](security/traditional-auditing/SKILL.md)) |
| `security/privileged-audit` | **active** ([security/privileged-audit/SKILL.md](security/privileged-audit/SKILL.md)) |
| `security/tde-awareness` | **active** ([security/tde-awareness/SKILL.md](security/tde-awareness/SKILL.md)) |
| `security/keystore-awareness` | **active** ([security/keystore-awareness/SKILL.md](security/keystore-awareness/SKILL.md)) |
| `security/tablespace-encryption` | **active** ([security/tablespace-encryption/SKILL.md](security/tablespace-encryption/SKILL.md)) |
| `security/network-encryption` | **active** ([security/network-encryption/SKILL.md](security/network-encryption/SKILL.md)) |
| `security/tls-awareness` | **active** ([security/tls-awareness/SKILL.md](security/tls-awareness/SKILL.md)) |
| `security/security-parameters` | **active** ([security/security-parameters/SKILL.md](security/security-parameters/SKILL.md)) |
| `security/database-links` | **active** ([security/database-links/SKILL.md](security/database-links/SKILL.md)) |
| `security/directories` | **active** ([security/directories/SKILL.md](security/directories/SKILL.md)) |
| `security/database-vault-awareness` | **active** ([security/database-vault-awareness/SKILL.md](security/database-vault-awareness/SKILL.md)) |
| `security/ols-awareness` | **active** ([security/ols-awareness/SKILL.md](security/ols-awareness/SKILL.md)) |
| `security/data-redaction-awareness` | **active** ([security/data-redaction-awareness/SKILL.md](security/data-redaction-awareness/SKILL.md)) |
| `security/data-masking-awareness` | **active** ([security/data-masking-awareness/SKILL.md](security/data-masking-awareness/SKILL.md)) |
| `security/licensing-gates` | **active** ([security/licensing-gates/SKILL.md](security/licensing-gates/SKILL.md)) |
| `security/compliance-mapping` | **active** ([security/compliance-mapping/SKILL.md](security/compliance-mapping/SKILL.md)) |
| `security/security-healthcheck` | **active** ([security/security-healthcheck/SKILL.md](security/security-healthcheck/SKILL.md)) |
| `security/security-assessment` | **active** ([security/security-assessment/SKILL.md](security/security-assessment/SKILL.md)) |
| `security/manual-remediation-plan` | **active** ([security/manual-remediation-plan/SKILL.md](security/manual-remediation-plan/SKILL.md)) |

## network (15 — Fase 4 (14) + Fase 8 hardening (1), todos `active`)

Reconciliación de la lista Foundation (ninguna estaba `active`): `network/tns` (flat) → `network/oracle-net` + `network/tns-errors`; `listener`/`scan-listener` → `network/listeners`/`network/scan`; `dns`/`hosts` → `network/name-resolution`/`network/scan-resolution`; `tcp`/`ports`/`ephemeral-ports` → cubiertos narrativamente por `network/connection-path`/`network/timeouts` (sin `skill_id` propio — no hay query/collector certificado independiente de puertos efímeros todavía); `tns-125xx`/`ora-3136` → `network/tns-errors` (taxonomía en `knowledge/errors/tns/`/`knowledge/errors/ora/`, no un skill por código); `rac-interconnect`/`bonding`/`vlan` → `network/interconnect`; `latency` → cubierto narrativamente, sin collector de latencia certificado en esta fase.

| skill_id | status |
|---|---|
| `network/oracle-net` | **active** ([network/oracle-net/SKILL.md](network/oracle-net/SKILL.md)) |
| `network/listeners` | **active** ([network/listeners/SKILL.md](network/listeners/SKILL.md)) |
| `network/scan` | **active** ([network/scan/SKILL.md](network/scan/SKILL.md)) |
| `network/scan-resolution` | **active** ([network/scan-resolution/SKILL.md](network/scan-resolution/SKILL.md)) |
| `network/service-registration` | **active** ([network/service-registration/SKILL.md](network/service-registration/SKILL.md)) |
| `network/local-listener` | **active** ([network/local-listener/SKILL.md](network/local-listener/SKILL.md)) |
| `network/remote-listener` | **active** ([network/remote-listener/SKILL.md](network/remote-listener/SKILL.md)) |
| `network/connection-path` | **active** ([network/connection-path/SKILL.md](network/connection-path/SKILL.md)) |
| `network/tns-errors` | **active** ([network/tns-errors/SKILL.md](network/tns-errors/SKILL.md)) |
| `network/timeouts` | **active** ([network/timeouts/SKILL.md](network/timeouts/SKILL.md)) |
| `network/name-resolution` | **active** ([network/name-resolution/SKILL.md](network/name-resolution/SKILL.md)) |
| `network/interconnect` | **active** ([network/interconnect/SKILL.md](network/interconnect/SKILL.md)) |
| `network/healthcheck` | **active** ([network/healthcheck/SKILL.md](network/healthcheck/SKILL.md)) |
| `network/troubleshooting` | **active** ([network/troubleshooting/SKILL.md](network/troubleshooting/SKILL.md)) |
| `network/oracle-net-security` | **active** ([network/oracle-net-security/SKILL.md](network/oracle-net-security/SKILL.md)) — PHASE 8 SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING |

## os (18 × 5 plataformas: linux, solaris, aix, windows, hpux)

Implementación por plataforma bajo `skills/os/<plataforma>/`, `skill_id` = `os/<plataforma>/<skill>` (ej. `os/linux/memory`). Lista de skills (idéntica por plataforma, contenido específico):

cpu, memory, swap, hugepages, numa, processes, load, filesystems, io, kernel, limits, network, tcp, dns, time, users, groups, oracle-processes.

| plataforma | status |
|---|---|
| `os/linux/memory` | **active** ([os/linux/memory.md](os/linux/memory.md)) — representativo; resto de `os/linux/*` y las otras 4 plataformas (17 skills × 5 plataformas restantes + 17 de Linux) quedan `registered` bajo `os/<plataforma>/<skill>` |
| `os/solaris/*` (18) | registered |
| `os/aix/*` (18) | registered |
| `os/windows/*` (18) | registered |
| `os/hpux/*` (18) | registered |

`hugepages`/`numa` no aplican a Windows — su entrada `registered` (`os/windows/hugepages`, `os/windows/numa`) se materializará como `N/A` documentado explícitamente, no se omite del registro (ver `_SKILL_CONTRACT_TEMPLATE.md#supported-os-platforms`).

## capacity (16)

| skill_id | status |
|---|---|
| `capacity/cpu` | registered |
| `capacity/memory` | registered |
| `capacity/sga` | registered |
| `capacity/pga` | registered |
| `capacity/filesystem` | registered |
| `capacity/asm` | registered |
| `capacity/tablespaces` | registered |
| `capacity/temp` | registered |
| `capacity/undo` | registered |
| `capacity/fra` | registered |
| `capacity/archive` | registered |
| `capacity/growth` | registered |
| `capacity/trending` | registered |
| `capacity/forecast` | **active** ([capacity/forecast.md](capacity/forecast.md)) |
| `capacity/headroom` | registered |
| `capacity/risk` | registered |

## incident (8)

| skill_id | status |
|---|---|
| `incident/root-cause-analysis` | **active** ([incident/root-cause-analysis.md](incident/root-cause-analysis.md)) |
| `incident/evidence-correlation` | registered |
| `incident/hypothesis-management` | registered |
| `incident/timeline-analysis` | registered |
| `incident/cause-validation` | registered |
| `incident/blast-radius` | registered |
| `incident/impact-analysis` | registered |
| `incident/lessons-learned` | registered |

## documentation (24)

| skill_id | status |
|---|---|
| `documentation/analysis-record` | registered |
| `documentation/assessment-report` | registered |
| `documentation/healthcheck-report` | **active** ([documentation/healthcheck-report.md](documentation/healthcheck-report.md)) |
| `documentation/incident-report` | registered |
| `documentation/rca-report` | registered |
| `documentation/executive-summary` | registered |
| `documentation/technical-findings` | registered |
| `documentation/evidence-register` | registered |
| `documentation/recommendation-report` | registered |
| `documentation/change-proposal` | registered |
| `documentation/implementation-runbook` | registered |
| `documentation/rollback-plan` | registered |
| `documentation/post-validation` | registered |
| `documentation/lessons-learned` | registered |
| `documentation/knowledge-candidate` | registered |
| `documentation/document-planner` | registered |
| `documentation/technical-writer` | registered |
| `documentation/executive-writer` | registered |
| `documentation/table-builder` | registered |
| `documentation/chart-builder` | registered |
| `documentation/word-generator` | registered |
| `documentation/excel-generator` | registered |
| `documentation/pdf-generator` | registered |
| `documentation/presentation-generator` | registered |
| `documentation/template-manager` | registered |
| `documentation/document-validator` | registered |

## change (12)

| skill_id | status |
|---|---|
| `change/gap-analysis` | **active** ([change/gap-analysis.md](change/gap-analysis.md)) |
| `change/impact-analysis` | registered |
| `change/skill-evolution` | registered |
| `change/agent-evolution` | registered |
| `change/query-evolution` | registered |
| `change/workflow-evolution` | registered |
| `change/policy-evolution` | registered |
| `change/knowledge-evolution` | registered |
| `change/compatibility-evolution` | registered |
| `change/documentation-evolution` | registered |
| `change/security-evolution` | registered |
| `change/regression-validation` | registered |

## Error knowledge

No hay un agente ni un skill por código ORA/TNS/RMAN/CRS individual. La taxonomía vive en [`knowledge/errors/`](../knowledge/errors/) (patrones validados, promovidos vía `/change knowledge`), consumida por los skills de `troubleshooting` de cada dominio (`rac/troubleshooting`, `dataguard/troubleshooting`, `multitenant/troubleshooting`, `rman/troubleshooting`).

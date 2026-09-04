# Skill Registry

Catálogo completo de skills (sección 9 del prompt maestro). Todo skill nuevo o modificado sigue el [Skill Contract](../docs/CONTRACTS.md#skill-contract) y el flujo `/change skill`.

## Regla de identificador canónico (Foundation Hardening)

> `skill_id` must always be globally unique and domain-qualified.

Este registro identifica cada skill **exclusivamente** por su `skill_id` completamente calificado (`dominio/skill`, columna "skill_id"). Nombres cortos como `temp`, `undo`, `sga`, `pga`, `services`, `memory`, `io` **no son identificadores válidos** — existen legítimamente en varios dominios (`oracle/temp` ≠ `performance/temp` ≠ `capacity/temp`; `performance/sga` ≠ `capacity/sga`) y sólo tienen sentido calificados. Ningún agente, workflow, skill u otro documento puede referenciar un skill por su nombre corto — siempre por `skill_id` completo tal como aparece en este registro. Un nombre corto sólo es válido como `display_name` (presentación en UI/reportes), nunca como identificador operativo. Validado por `tests/test_skill_ids_are_globally_unique.sh`, `tests/test_skill_ids_are_domain_qualified.sh`, `tests/test_no_ambiguous_skill_references.sh`.

**Status:**
- `active` — materializado por completo (19 secciones del Skill Contract), archivo real en el dominio.
- `registered` — nombre, dominio y propósito fijados en este registro; su materialización completa es Fase 2+ según `README.md#fases-de-construcción`. No es un placeholder vacío: es la entrada de catálogo que gobierna qué se puede construir y en qué orden vía `/change skill`.

Fase 1 materializó **un ejemplo representativo completo por dominio** (14); Foundation Hardening agregó `core/version-awareness` (15); **Fase 2 (Oracle Core) materializa las 18 skills del dominio `oracle` completo** (32 activos en total); **Fase 3 (Oracle Performance) materializa las 31 skills del dominio `performance` completo** (63 activos en total); **Fase 4 (RAC/GI/ASM/Network) materializa 57 skills — dominio `rac` completo (31: 19 RAC + 12 GI), `asm` completo (12), `network` completo (14)** (120 activos en total). El resto queda `registered` para materialización gobernada en Fases 5–9, en el orden de `README.md`.

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

## dataguard (17)

| skill_id | status |
|---|---|
| `dataguard/discovery` | registered |
| `dataguard/role` | registered |
| `dataguard/protection-mode` | registered |
| `dataguard/transport` | registered |
| `dataguard/apply` | registered |
| `dataguard/lag` | **active** ([dataguard/lag.md](dataguard/lag.md)) |
| `dataguard/archive-destinations` | registered |
| `dataguard/archive-gap` | registered |
| `dataguard/mrp` | registered |
| `dataguard/rfs` | registered |
| `dataguard/srl` | registered |
| `dataguard/broker` | registered |
| `dataguard/services` | registered |
| `dataguard/network` | registered |
| `dataguard/performance` | registered |
| `dataguard/readiness` | registered |
| `dataguard/troubleshooting` | registered |

## multitenant (12)

| skill_id | status |
|---|---|
| `multitenant/discovery` | registered |
| `multitenant/cdb` | registered |
| `multitenant/pdb` | registered |
| `multitenant/container-state` | **active** ([multitenant/container-state.md](multitenant/container-state.md)) |
| `multitenant/services` | registered |
| `multitenant/storage` | registered |
| `multitenant/temp` | registered |
| `multitenant/undo` | registered |
| `multitenant/resource-manager` | registered |
| `multitenant/common-users` | registered |
| `multitenant/local-users` | registered |
| `multitenant/troubleshooting` | registered |

## rman (14)

| skill_id | status |
|---|---|
| `rman/configuration` | registered |
| `rman/backup-status` | **active** ([rman/backup-status.md](rman/backup-status.md)) |
| `rman/backup-history` | registered |
| `rman/channels` | registered |
| `rman/sbt` | registered |
| `rman/controlfile` | registered |
| `rman/spfile` | registered |
| `rman/archivelog` | registered |
| `rman/fra` | registered |
| `rman/recovery-readiness` | registered |
| `rman/restore-readiness` | registered |
| `rman/rac` | registered |
| `rman/dataguard` | registered |
| `rman/performance` | registered |
| `rman/troubleshooting` | registered |

## network (14 — Fase 4, todos `active`)

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

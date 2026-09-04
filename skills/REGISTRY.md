# Skill Registry

Catálogo completo de skills (sección 9 del prompt maestro). Todo skill nuevo o modificado sigue el [Skill Contract](../docs/CONTRACTS.md#skill-contract) y el flujo `/change skill`.

## Regla de identificador canónico (Foundation Hardening)

> `skill_id` must always be globally unique and domain-qualified.

Este registro identifica cada skill **exclusivamente** por su `skill_id` completamente calificado (`dominio/skill`, columna "skill_id"). Nombres cortos como `temp`, `undo`, `sga`, `pga`, `services`, `memory`, `io` **no son identificadores válidos** — existen legítimamente en varios dominios (`oracle/temp` ≠ `performance/temp` ≠ `capacity/temp`; `performance/sga` ≠ `capacity/sga`) y sólo tienen sentido calificados. Ningún agente, workflow, skill u otro documento puede referenciar un skill por su nombre corto — siempre por `skill_id` completo tal como aparece en este registro. Un nombre corto sólo es válido como `display_name` (presentación en UI/reportes), nunca como identificador operativo. Validado por `tests/test_skill_ids_are_globally_unique.sh`, `tests/test_skill_ids_are_domain_qualified.sh`, `tests/test_no_ambiguous_skill_references.sh`.

**Status:**
- `active` — materializado por completo (19 secciones del Skill Contract), archivo real en el dominio.
- `registered` — nombre, dominio y propósito fijados en este registro; su materialización completa es Fase 2+ según `README.md#fases-de-construcción`. No es un placeholder vacío: es la entrada de catálogo que gobierna qué se puede construir y en qué orden vía `/change skill`.

Fase 1 materializó **un ejemplo representativo completo por dominio** (14); Foundation Hardening agregó `core/version-awareness` (15); **Fase 2 (Oracle Core) materializa las 18 skills del dominio `oracle` completo** (32 activos en total); **Fase 3 (Oracle Performance) materializa las 31 skills del dominio `performance` completo** (63 activos en total). El resto queda `registered` para materialización gobernada en Fases 4–9, en el orden de `README.md`.

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

## rac (29)

| skill_id | status |
|---|---|
| `rac/topology` | registered |
| `rac/cluster-health` | registered |
| `rac/node-health` | registered |
| `rac/instance-health` | registered |
| `rac/services` | registered |
| `rac/service-placement` | registered |
| `rac/session-distribution` | **active** ([rac/session-distribution.md](rac/session-distribution.md)) |
| `rac/session-imbalance-analysis` | registered |
| `rac/clb` | registered |
| `rac/rlb` | registered |
| `rac/fan` | registered |
| `rac/taf` | registered |
| `rac/scan` | registered |
| `rac/vip` | registered |
| `rac/listeners` | registered |
| `rac/interconnect` | registered |
| `rac/cache-fusion` | registered |
| `rac/gcs` | registered |
| `rac/ges` | registered |
| `rac/gc-waits` | registered |
| `rac/global-enqueues` | registered |
| `rac/crs-resources` | registered |
| `rac/ocr` | registered |
| `rac/voting-disk` | registered |
| `rac/node-eviction` | registered |
| `rac/service-failover-analysis` | registered |
| `rac/instance-failover-analysis` | registered |
| `rac/troubleshooting` | registered |

## asm (9)

| skill_id | status |
|---|---|
| `asm/discovery` | registered |
| `asm/diskgroups` | registered |
| `asm/disks` | registered |
| `asm/failure-groups` | registered |
| `asm/redundancy` | registered |
| `asm/capacity` | **active** ([asm/capacity.md](asm/capacity.md)) |
| `asm/rebalance-analysis` | registered |
| `asm/io` | registered |
| `asm/alerts` | registered |

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

## network (15)

| skill_id | status |
|---|---|
| `network/tns` | **active** ([network/tns.md](network/tns.md)) |
| `network/listener` | registered |
| `network/scan-listener` | registered |
| `network/dns` | registered |
| `network/hosts` | registered |
| `network/tcp` | registered |
| `network/ports` | registered |
| `network/ephemeral-ports` | registered |
| `network/timeouts` | registered |
| `network/tns-125xx` | registered |
| `network/ora-3136` | registered |
| `network/rac-interconnect` | registered |
| `network/bonding` | registered |
| `network/vlan` | registered |
| `network/latency` | registered |

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

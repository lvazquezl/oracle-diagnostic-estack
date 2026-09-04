# Phase 3 — Oracle Performance

Branch: `phase/3-performance`. Baseline: `v0.2.0-oracle-core`. Objetivo del baseline resultante: `v0.3.0-performance`.

## Scope

Capa funcional de análisis de rendimiento Oracle: DB Time/DB CPU/Load Profile, wait classes/events, top SQL, planes de ejecución y su regresión, SGA/PGA/memoria, parsing/library cache/shared pool, I/O, TEMP/UNDO desde la óptica de rendimiento, concurrencia/locking/blocking, paralelismo, commit/redo, y tendencia entre snapshots — sobre AWR/ASH/ADDM (detrás de Licensing Gate), Statspack (sin licencia, primera clase) y vistas dinámicas (ruta estándar). No reconstruye Foundation ni Oracle Core; no avanza a RAC/GI/ASM deep diagnostics ni implementa auto-remediation.

## Agents

`agents/oracle-performance-analyst/AGENT.md` (v3.0.0) — reestructurado de manifest plano a carpeta profunda, análogo a `oracle-dba-analyst`/`oracle-discovery-analyst`. Documenta: Responsibilities, Explicit boundaries, Scope, Activation, Supported versions/platforms/architectures, Allowed skills (31), Forbidden capabilities, Task/Result Package contracts, Performance workflow, Licensing rules + fallback examples, SQL text policy, Evidence policy + AWR input model, Correlation model (con ejemplos certificados OBSERVATION→HYPOTHESIS→PROBABLE_CAUSE) + multi-instance/multitenant awareness, Context/token policy, Confidence rules, Manual command generation (nunca `KILL SESSION`/`ALTER SYSTEM` ejecutado), Collaboration/escalation, Security, Tests, Change history.

## Skills

31 skills `performance/*` completamente materializados (`SKILL.md` + `manifest.yaml`, ~30 secciones cada uno): `awr-analysis`, `ash-analysis`, `statspack-analysis`, `addm-analysis`, `db-time`, `db-cpu`, `load-profile`, `wait-events` (upgrade de Fase 1, extendido no reconstruido), `wait-classes`, `top-sql` + familia (`sql-cpu`, `sql-elapsed`, `sql-io`, `sql-executions` — reutilizan la evidencia de `top-sql`, sin query propia, sólo reordenamiento), `execution-plan`, `plan-regression`, `sga`, `pga`, `memory`, `hard-parse`, `library-cache`, `shared-pool`, `io`, `temp` (extiende `oracle/temp`, no duplica), `undo` (reutiliza `oracle/undo` completo, sin query propia), `concurrency`, `locking`, `blocking`, `parallelism`, `commit-redo`, `trending`.

## Query catalog

`queries/performance/` — 21 queries certificadas (Query Contract v2 + Query Variant Contract), todas `implicit_full_range` (ninguna requirió split de versión: diseñadas evitando columnas version-gated no guardadas, ej. `V$PGASTAT`/`V$SYSSTAT` filtradas por columna `name` en vez de por nombre de columna SQL — ver `docs/QUERY_VARIANTS.md`). Distribución: `waits/` (3, incluye `Q-PERF-WAIT-AWR-001`/`Q-PERF-WAIT-ASH-001` relocalizadas de `queries/` plano + `Q-PERF-WAIT-STATSPACK-001` recién materializada), `db-time/` (2), `sql/` (2), `plans/` (2), `memory/` (5), `io/` (2), `temp/` (1), `concurrency/` (2), `parallel/` (1), `redo/` (1). Cada query con ruta AWR (licenciada) tiene, cuando aplica, una contraparte `*-CURRENT-001` de ruta estándar sin licencia.

## Query variants

Ninguna variante de versión requerida — validado contra `compatibility/oracle-dictionary/` (extendido con 20 vistas/columnas nuevas: `STATS$SYSTEM_EVENT`, `STATS$SNAPSHOT`, `DBA_HIST_SYS_TIME_MODEL`, `V$SYS_TIME_MODEL`, `DBA_HIST_SQLSTAT`, `V$SQLSTATS`, `V$SQL_PLAN`, `DBA_HIST_SQL_PLAN`, `V$SGA`, `V$SGAINFO`, `V$SGASTAT`, `V$PGASTAT`, `V$SYSSTAT`, `V$LIBRARYCACHE`, `V$ROWCACHE`, `V$SYSTEM_EVENT`, `V$FILESTAT`, `V$DATAFILE`, `V$SORT_USAGE`, `V$LOCK`, `V$PX_SESSION`, `V$PQ_SYSSTAT`). Todas las 21 registradas en `config/query-compatibility-matrix.yaml` — verificado por `tests/test_performance_version_support_matches_reality.sh`.

## Supported Oracle versions

10g–23ai para el core no licenciado (Statspack + ruta estándar) — genuinamente `SUPPORTED`, no sólo declarado (validado por el mismo Query Variant Resolver y SQL Static Validator endurecidos en la Compatibility Hardening previa). AWR/ASH/ADDM son `LICENSE_DEPENDENT` en las mismas versiones — su disponibilidad depende del contrato de licenciamiento del cliente, no de cobertura del e-stack.

## AWR capability

`performance/awr-analysis` correlaciona DB Time/DB CPU + top wait events + top SQL de la misma ventana — nunca resume el AWR sin cruzar secciones. AWR input model documentado (parser local → secciones estructuradas → sanitizer → evidencia por referencia); no se envía un AWR completo al modelo. Parseo de un artefacto AWR HTML/texto externo adjuntado por el DBA queda fuera de alcance ejecutable de esta fase (ver Known limitations) — la evidencia hoy proviene de las queries certificadas `Q-PERF-*-001`, no de parsear un archivo.

## ASH capability

`performance/ash-analysis` — agregados por ventana/wait_class/evento/SQL_ID, nunca muestras masivas. Sin fallback de igual granularidad sin licencia (cae a `wait-events` agregado o `statspack-analysis`).

## Statspack capability

`performance/statspack-analysis` — ruta de **primera clase**, no un fallback de segunda categoría. `Q-PERF-WAIT-STATSPACK-001` recién materializada (antes sólo `registered`). Gap honesto: sólo wait events cubiertos hoy — Load Profile/SQL statistics/Instance Activity vía Statspack (`STATS$SQL_SUMMARY`, `STATS$SYSSTAT`) documentados como limitación explícita, no fingidos como cubiertos.

## ADDM capability

`performance/addm-analysis` — interpreta recomendaciones ADDM ya generadas por Oracle (no las ejecuta vía `DBMS_ADVISOR`), clasificándolas siempre como `EVIDENCE_SOURCE` correlacionado con evidencia AWR independiente, nunca como causa confirmada automática.

## Standard non-licensed performance path

Ruta explícita sin AWR/ASH/ADDM/SQL Tuning Advisor: `Q-PERF-DBTIME-CURRENT-001` (`V$SYS_TIME_MODEL`), `Q-PERF-TOPSQL-CURRENT-001` (`V$SQLSTATS`), `Q-PERF-IO-001` (`V$SYSTEM_EVENT`), memoria estructural (`Q-PERF-SGA-001`/`Q-PERF-PGA-001`/etc., nunca licenciada). Permite troubleshooting útil sin Diagnostic/Tuning Pack — validado por 5 tests dedicados (`test_standard_path_*`, `test_performance_without_diagnostic_pack.sh`).

## Licensing gates

Secuencia completa documentada en `agents/oracle-performance-analyst/AGENT.md#licensing-rules`: Capability requested → Version check → Architecture check → License gate → Privilege gate → Cost gate → Evidence collection. Sin confirmación (`constraints.license_confirmed`), `capability_status: LICENSE_RESTRICTED` con fallback declarado (nunca AWR/ASH/ADDM usado como fallback de otra capability — el fallback siempre va hacia una fuente MENOS restringida).

## Performance correlation model

Ejemplos certificados en `agents/oracle-performance-analyst/AGENT.md#correlation-model`: CPU-bound workload (High DB CPU + Top SQL CPU concentrado + low non-CPU waits), comportamiento de commit de aplicación vs. latencia de storage de redo (mismo síntoma `log file sync` alto, dos hipótesis distinguidas por `log file parallel write`). Todo patrón distingue `OBSERVATION` → `HYPOTHESIS` → `PROBABLE_CAUSE`; nunca `CONFIRMED_ROOT_CAUSE` (exclusivo de `incident-root-cause-analyst`).

## DB Time / DB CPU

`performance/db-time` distingue DB Time/DB CPU/non-idle waits, correlacionado con `elapsed_sec`/concurrencia — nunca interpretado aislado. `performance/db-cpu` nunca concluye "high DB CPU = CPU problem" sin correlación con top SQL/paralelismo/evidencia OS.

## Wait analysis

`performance/wait-events` (extendido, no reconstruido) + `performance/wait-classes`. Nunca usa `Cluster` como causa fuera de RAC. Severidad considera `total_wait_time`, `average_wait`, `wait_count`, `pct_db_time`, workload y baseline — nunca una sola métrica.

## Top SQL

`performance/top-sql` + familia (`sql-cpu`/`sql-elapsed`/`sql-io`/`sql-executions`, reordenamientos sobre la misma evidencia, sin query propia). Métricas por-ejecución con manejo seguro de división por cero — nunca juzga por el total absoluto.

## Execution plan

`performance/execution-plan` nunca declara un Full Table Scan malo por definición. `performance/plan-regression` detecta múltiples `plan_hash_value` con degradación medible; nunca recomienda SPM automáticamente.

## Memory

`performance/sga`/`performance/pga`/`performance/memory` — nunca recomienda memoria por ratio aislado (`buffer cache hit ratio < X` prohibido explícitamente). `PGA_AGGREGATE_LIMIT` (12.1+) tratado como `NOT_APPLICABLE` explícito antes de esa versión, nunca asumido — vía filtrado por columna `name` (string), no por columna SQL inexistente. `performance/hard-parse`/`performance/library-cache`/`performance/shared-pool` nunca usan un ratio aislado como causa definitiva.

## I/O

`performance/io` correlaciona waits agregados + latencia por datafile; latencia alta reportada por Oracle es `OBSERVATION`, nunca confirmación de problema de storage sin evidencia OS/storage externa.

## TEMP / UNDO

`performance/temp` extiende `oracle/temp` (capacidad) con uso activo (`V$SORT_USAGE`) — sin duplicar su query. `performance/undo` reutiliza `oracle/undo` por completo (`V$UNDOSTAT`), sin query propia — riesgo de `ORA-01555` evaluado estructuralmente, nunca confirmado sin evidencia externa de un error real.

## Concurrency

`performance/blocking`/`performance/locking`/`performance/concurrency` — cadenas blocker/waiter vía `V$SESSION.BLOCKING_SESSION` (preferido sobre `DBA_BLOCKERS`/`DBA_WAITERS`, legacy y menos confiables en RAC). `KILL SESSION` nunca ejecutado — únicamente texto `NOT_EXECUTED`/`HUMAN_REVIEW_REQUIRED`.

## Parallelism

`performance/parallelism` — `V$PX_SESSION`, detecta degradación `degree < req_degree`; nunca recomienda `parallel_max_servers`/DOP sin correlación CPU/I/O completa.

## Commit / Redo

`performance/commit-redo` distingue comportamiento de aplicación (commit frecuente) de latencia de storage de redo como hipótesis separadas — mismo síntoma (`log file sync` alto), correlación con `log file parallel write` determina cuál.

## Trending

`performance/trending` — comparación baseline/before-after/period-over-period sobre evidencia ya recolectada; nunca genera forecast (delegado a `capacity-analyst`).

## Evidence model

Cada finding referencia `evidence_refs` (nunca evidencia cruda repetida). `time_window` obligatorio para AWR/ASH/Statspack históricos; `sql_id` obligatorio para `execution-plan`/`plan-regression`. Multi-instance: nunca se agregan valores de distintas instancias de forma ingenua — `instance-level`/`database-level`/`cluster-level` diferenciados. Multitenant: `CON_ID` distinguido, nunca comparado entre `CDB$ROOT` y PDB como el mismo scope.

## Sanitization

SQL text policy explícita: `SQL_ID`/`PLAN_HASH_VALUE`/métricas siempre; `SQL_TEXT`/`SQL_FULLTEXT` nunca por defecto; bind values/datos de aplicación nunca. Predicados de plan (`access_predicates`/`filter_predicates`) enmascarados si contienen literales de aplicación. Nombres de datafile enmascarados por defecto.

## Token/context optimization

Top-N configurable (`top_sql_default: 10`, `top_waits_default: 10`) — agregación local antes de enviar, nunca AWR/Statspack completo propagado, nunca SQL text completo, evidencia por referencia reutilizada dentro de la sesión.

## Workflows

`.claude/commands/awr.md`/`workflows/awr.md` (ya existentes de Fase 1, gate de Statspack actualizado de `FOUNDATION_ONLY` a `SUPPORTED`). `workflows/analyze.md` extendido con mapeo explícito `performance`/`sql`/`memory`/`io`/`waits` → `oracle-performance-analyst` + sub-skill, sin nuevos slash commands.

## Documentation

Este documento. Actualizados: `CHANGELOG.md`, `config/capability-matrix.yaml` + `docs/CAPABILITY_MATRIX.md` (Performance/Statspack `PARTIAL`/`FOUNDATION_ONLY` → `SUPPORTED`; AWR/ASH/ADDM permanecen `LICENSE_DEPENDENT` sin cambio), `mcp/tool-manifest.md` (9 tools nuevas + `get_top_sql_metrics` materializada), `agents/REGISTRY.md`, `skills/REGISTRY.md` (31 filas `performance/*` activas + 3 filas nuevas — `memory`, `commit-redo`, `trending` — que faltaban del catálogo original), `queries/REGISTRY.md`, `policies/licensing-awareness-policy.md` (referencia de ruta actualizada). `ARCHITECTURE.md`/`README.md` actualizados sólo donde aplica (sin cambio arquitectónico de componentes — extensión del mismo modelo de Fase 2).

## Capability Matrix update

`Performance`: `PARTIAL` → `SUPPORTED` 10g–23ai (core no licenciado, validado). `Statspack`: `FOUNDATION_ONLY` → `SUPPORTED` 10g–23ai (materializado). `AWR`/`ASH`/`ADDM`: sin cambio, `LICENSE_DEPENDENT` — no es limitación del e-stack. `RAC Performance Deep`: `PLANNED`, sin cambio (Fase 4).

## Skill Quality Gate

Los 31 skills cumplen: Contract, Documentation (~30 secciones), Evidence, Decision Logic, Licensing, Version Awareness, Architecture Awareness, Security, Queries, Tests, Token Policy, Correlation, Examples, Change History.

## Agent Quality Gate

`oracle-performance-analyst` validado contra Agent Contract, Routing (Activation), Allowed skills (31), Forbidden capabilities, Context policy, Evidence policy, Output schema, Collaboration, Security, Tests.

## Security validation

Todos los tests de seguridad Foundation siguen pasando. Nuevos: `test_performance_queries_read_only.sh`, `test_performance_no_arbitrary_sql.sh`, `test_performance_no_application_data.sh`, `test_performance_no_bind_values.sh`, `test_awr_license_gate.sh`, `test_ash_license_gate.sh`, `test_addm_license_gate.sh`, `test_sql_text_masked_by_default.sh`, `test_no_kill_session_execution.sh`, `test_manual_kill_command_marked_not_executed.sh` — todos `PASS`.

## Test results

47 tests nuevos de Fase 3, todos `PASS` (verificados individualmente tras corregir 3 falsos positivos propios de diseño de test — grep de archivo completo capturando menciones en prosa en vez de uso real en `objects_accessed`/bloque SQL, y una negación textual de `CONFIRMED_ROOT_CAUSE` mal interpretada como asignación).

## Regression results

Ver sección "TEST RESULTS"/"REGRESSION RESULTS" del reporte final — Foundation + Foundation Hardening + Oracle Core + Compatibility Hardening + Fase 3 + Security + Regression, todos ejecutados antes del reporte de cierre.

## Known limitations

- El AWR input model (parser local de un artefacto AWR HTML/texto externo) está documentado pero no implementado como parser ejecutable — la evidencia AWR de esta fase proviene de las 21 queries certificadas contra el ambiente vivo (Fase 7 automatiza la ejecución real vía Gateway MCP), no de parsear un archivo adjunto por el DBA.
- Statspack cubre únicamente wait events (`Q-PERF-WAIT-STATSPACK-001`) — Load Profile/SQL statistics/Instance Activity vía `STATS$SQL_SUMMARY`/`STATS$SYSSTAT` quedan como `/change query` futuro, documentado explícitamente en `performance/statspack-analysis/SKILL.md`, no fingido como cubierto.
- `Q-PERF-PARALLEL-STAT-001` (`V$PQ_SYSSTAT` agregado) documentado como candidato futuro en `Q-PERF-PARALLEL-001`, no materializado — `performance/parallelism` cubre sesiones activas puntuales, no estadísticas acumuladas de servers.
- `performance/trending` compone evidencia ya recolectada en la sesión; no persiste snapshots entre sesiones distintas (eso requeriría un almacén de evidencia histórico, fuera de alcance de esta fase).
- ADDM se interpreta sólo cuando el DBA provee su output — este e-stack no invoca `DBMS_ADVISOR.EXECUTE_TASK` (correctamente, por diseño — nunca debe hacerlo), por lo que no hay una query certificada que "genere" ADDM, sólo que lo correlacione.

## Examples

Ver `tests/fixtures/{10g-statspack,11g-statspack,12c-awr,19c-standalone-performance,19c-rac-multi-instance,19c-no-diagnostic-pack,19c-blocking,19c-high-cpu,19c-high-io,19c-log-file-sync,23ai-modern-performance}.yaml` (11 fixtures nuevas).

## Tests

Ver `# Test results` arriba y `docs/PHASE_3_ORACLE_PERFORMANCE.md#security-validation`.

## Next phase

Fase 4 — RAC/GI/ASM deep diagnostics (`oracle-rac-analyst`, `oracle-asm-storage-analyst`), explícitamente fuera de alcance de esta fase (`gc *` waits y contención ASM se señalan y escalan, nunca se interpretan internamente).

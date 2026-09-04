# Tool Manifest — MCP Diagnostic Gateway

Cada tool mapea 1:1 (o 1:N) a entradas certificadas de [`queries/REGISTRY.md`](../queries/REGISTRY.md). Ninguna tiene un parámetro de texto libre para SQL/shell.

| tool | input schema | output (resumen) | queries certificadas detrás |
|---|---|---|---|
| `get_database_identity(target)` | `{target: string}` | version, edition, role, cdb, open_mode | `Q-DISC-IDENTITY-001` |
| `get_instance_status(target)` | `{target: string}` | instance_mode, instance_number, status por instancia | `Q-DISC-INSTANCE-001` |
| `get_rac_topology(target)` | `{target: string}` | nodos, instancias, versión GI | `Q-DISC-RAC-001` |
| `get_session_distribution(target, service?)` | `{target: string, service?: string}` | sesiones por instancia/servicio | `Q-RAC-SESSION-DIST-001`, `Q-RAC-SERVICE-PLACEMENT-001` |
| `get_wait_events(target, window_start, window_end, source?)` | `{target, window_start, window_end, source?: awr\|ash\|statspack}` | top wait events | `Q-PERF-WAIT-AWR-001`, `Q-PERF-WAIT-ASH-001`, `Q-PERF-WAIT-STATSPACK-001` |
| `get_top_sql_metrics(target, window_start?, window_end?)` | `{target, window_start?, window_end?}` | SQL_ID, plan hash, métricas (sin SQL text por defecto) | `Q-PERF-TOPSQL-001`, `Q-PERF-TOPSQL-CURRENT-001` |
| `get_db_time(target, window_start?, window_end?)` | `{target, window_start?, window_end?}` | DB Time/DB CPU, ventana AWR o acumulado desde arranque | `Q-PERF-DBTIME-001`, `Q-PERF-DBTIME-CURRENT-001` |
| `get_execution_plan(target, sql_id, plan_hash_value?, window_start?, window_end?)` | `{target, sql_id, plan_hash_value?, window_start?, window_end?}` | operaciones/costo/cardinalidad del plan, o historial de plan_hash_value | `Q-PERF-PLAN-001`, `Q-PERF-PLAN-HIST-001` |
| `get_memory_status(target)` | `{target: string}` | SGA/PGA/library cache/shared pool | `Q-PERF-SGA-001`, `Q-PERF-PGA-001`, `Q-PERF-HARDPARSE-001`, `Q-PERF-LIBCACHE-001`, `Q-PERF-SHAREDPOOL-001` |
| `get_io_waits(target)` | `{target: string}` | waits de I/O dominantes y latencia por datafile | `Q-PERF-IO-001`, `Q-PERF-IO-FILESTAT-001` |
| `get_active_temp_usage(target)` | `{target: string}` | uso activo de TEMP por sesión/SQL_ID | `Q-PERF-TEMP-001` |
| `get_blocking_sessions(target)` | `{target: string}` | cadenas de bloqueo blocker/waiter, locks activos | `Q-PERF-BLOCKING-001`, `Q-PERF-LOCKS-001` |
| `get_parallel_sessions(target)` | `{target: string}` | sesiones Parallel Execution activas | `Q-PERF-PARALLEL-001` |
| `get_redo_activity(target)` | `{target: string}` | volumen de redo y tasa de commit/rollback | `Q-PERF-REDO-001` |
| `get_tablespace_usage(target)` | `{target: string}` | uso/autoextend por tablespace | `Q-DBA-TBS-USAGE-001`, `Q-DBA-TBS-DATAFILES-001` |
| `get_asm_usage(target)` | `{target: string}` | espacio usable por disk group | `Q-ASM-DG-USAGE-001`, `Q-ASM-OPERATION-001` |
| `get_dataguard_status(target)` | `{target: string}` | rol, lag, gaps, destinos | `Q-DG-STATS-001`, `Q-DG-ARCHIVE-GAP-001` |
| `get_listener_status(target)` | `{target: string}` | estado de listener/SCAN listener, servicios registrados | `Q-NET-LISTENER-STATUS-001` *(registered — Fase 4)* |
| `get_os_cpu(target)` | `{target: string}` | load, run queue | `Q-OS-<plataforma>-CPU-001` *(registered por plataforma — Fase 6, salvo Linux representativo)* |
| `get_os_memory(target)` | `{target: string}` | uso de memoria/swap/HugePages | `Q-OS-LINUX-MEM-001` (Linux, active); resto `registered` |
| `get_os_io(target)` | `{target: string}` | latencia/throughput por dispositivo | `Q-OS-<plataforma>-IO-001` *(registered)* |
| `get_os_network(target)` | `{target: string}` | interfaces, errores, latencia | `Q-OS-<plataforma>-NET-001` *(registered)* |
| `get_rman_status(target)` | `{target: string}` | último backup por tipo, estado FRA | `Q-RMAN-BACKUP-JOB-001`, `Q-RMAN-BACKUPSET-001` |
| `get_security_posture(target)` | `{target: string}` | usuarios privilegiados, profiles, DB links | `Q-SEC-USERS-001` *(registered — Fase 5)* |
| `get_capacity_trend(target, resource, horizon_months)` | `{target, resource, horizon_months: 1\|3\|6}` | serie histórica + proyección | `Q-CAP-TIMESERIES-001` |
| `get_pdb_state(target)` | `{target: string}` | estado por PDB | `Q-CDB-PDB-STATE-001`, `Q-CDB-CONTAINERS-001` |
| `get_database_state(target)` | `{target: string}` | flashback/guard/protection flags | `Q-ORA-DB-STATE-001` |
| `get_database_parameters(target)` | `{target: string}` | parámetros no-default (+ diff RAC si aplica) | `Q-ORA-PARAMETERS-001`, `Q-ORA-PARAMETERS-RAC-DIFF-001` |
| `get_controlfile_metadata(target)` | `{target: string}` | multiplexado, record sections | `Q-ORA-CONTROLFILE-001` |
| `get_redo_configuration(target, window_start?, window_end?)` | `{target, window_start?, window_end?}` | grupos/miembros, frecuencia de switch | `Q-ORA-REDO-001`, `Q-ORA-REDO-SWITCH-FREQ-001` |
| `get_archive_configuration(target)` | `{target: string}` | destinos, estado, último archivado | `Q-ORA-ARCHIVE-001` |
| `get_temp_usage(target)` | `{target: string}` | uso/configuración de TEMP | `Q-ORA-TEMP-001` |
| `get_undo_status(target)` | `{target: string}` | configuración/uso de UNDO | `Q-ORA-UNDO-001` |
| `get_session_summary(target)` | `{target: string}` | resumen agregado de sesiones | `Q-ORA-SESSIONS-SUMMARY-001` |
| `get_process_summary(target)` | `{target: string}` | procesos vs. límite | `Q-ORA-PROCESSES-SUMMARY-001` |
| `get_resource_limits(target)` | `{target: string}` | uso pico vs. límite (processes/sessions/open_cursors/...) | `Q-ORA-RESOURCE-LIMITS-001` |
| `get_invalid_object_summary(target)` | `{target: string}` | objetos inválidos por owner/tipo | `Q-ORA-INVALID-OBJECTS-001` |
| `get_component_status(target)` | `{target: string}` | estado/versión de componentes | `Q-ORA-COMPONENTS-001` |
| `get_jobs_summary(target)` | `{target: string}` | jobs fallidos/broken/larga duración | `Q-ORA-JOBS-SUMMARY-001` |
| `get_objects_inventory(target)` | `{target: string}` | inventario agregado de objetos | `Q-ORA-OBJECTS-INVENTORY-001` |
| `get_spfile_status(target)` | `{target: string}` | existencia SPFILE, cambios no persistidos | `Q-ORA-SPFILE-001` |
| `get_diagnostic_state(target, window_start?, window_end?)` | `{target, window_start?, window_end?}` | incidentes ADR, extracto de alert log | `Q-ORA-DIAGNOSTICS-ADR-001`, `Q-ORA-DIAGNOSTICS-ALERTLOG-001` |

## MCP Query Certification (Compatibility Hardening)

Antes de exponer una tool contra un target concreto, el Gateway MCP consulta al Query Variant Resolver (`docs/QUERY_VARIANTS.md#query-variant-resolver`) por cada `query_id` detrás de esa tool. Estado resultante posible:

| Resolver status | Tool disponible para ese target |
|---|---|
| `SUPPORTED` (el Resolver encontró un variant compatible) | Sí — `CERTIFIED` para ese target específico. |
| `UNSUPPORTED` (ningún variant cubre ese target) | No — la tool no se expone; el orquestador reporta `capability_status: UNSUPPORTED` con `reason`/`alternative` (nunca un error genérico). |
| `PARTIALLY_SUPPORTED` sin variant compatible para ese target concreto | No — no equivale a `CERTIFIED`; sólo aplica si existe al menos un variant que cubra ese target exacto. |
| Query no revisada por Compatibility Hardening (`NOT_CERTIFIED`/estado desconocido) | No — nunca expuesta. Ninguna tool detrás de una query `NOT_CERTIFIED` o `UNKNOWN` es alcanzable vía MCP, independientemente de si su Query Contract declara metadata de soporte. |

Esto es evaluado **por target**, no una vez globalmente: la misma tool puede estar `CERTIFIED` para un target 19c y no disponible para un target 10g si el Resolver no encuentra variant para ese caso — ver la tabla `10g COMPATIBILITY`…`23ai COMPATIBILITY` en `docs/PHASE_2_COMPATIBILITY_HARDENING.md`. El Gateway MCP en sí (ejecución real contra una instancia) es Fase 7; hasta entonces esta sección documenta la regla que ese Gateway debe implementar, no un comportamiento runtime activo hoy.

## Reglas del manifest

- Toda tool declara `timeout`/`max_rows` heredados de su(s) query(s) certificada(s) — el más restrictivo aplica si hay varias.
- Toda tool pasa por el Sanitizer antes de devolver resultado (ver `sanitizers/data-classification-policy.md`).
- Una tool marcada con queries `registered` (no `active`) no está disponible aún en el Gateway real — su presencia aquí es de catálogo/roadmap, materializada en la fase indicada.
- Ninguna tool acepta un parámetro `sql`, `command`, o `raw_query` de texto libre.

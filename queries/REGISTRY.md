# Query Registry — Catálogo certificado read-only

Todo query/comando aquí es de sólo lectura por construcción (`execution_mode: READ_ONLY`, ver [Query Contract v2](../docs/CONTRACTS.md#query-contract-v2-foundation-hardening)). Ninguna entrada puede tener un verbo distinto de `SELECT`/`get`/`show status`/equivalente. Las 14 tools "semánticas" nombradas explícitamente en el prompt maestro están marcadas `core-14`; las demás son extensión Fase 1 documentada en [ARCHITECTURE.md](../ARCHITECTURE.md#5-decisiones-arquitectónicas-fase-1) decisión 9.

> **Foundation Hardening**: esta tabla migró a Query Contract v2 — se separó en "Identity & Scope" y "Cost, Risk & Sensitivity" para mantener cada tabla legible. `id` es la clave de unión entre ambas. `risk_class` (seguridad) y `cost_class` (impacto operacional) son dimensiones **distintas** — ver `policies/query-cost-policy.md`.

> **Fase 2 (Oracle Core)**: el catálogo Oracle se organizó por carpeta bajo `queries/oracle/<categoría>/`, una query por archivo (`<query_id>.md`), en vez de un único archivo `.md` plano por query en `queries/`. Las 4 queries de discovery (`Q-DISC-IDENTITY-001`, `Q-DISC-INSTANCE-001`, `Q-DISC-RAC-001`, `Q-DISC-ASM-001`) y las 2 de tablespaces (`Q-DBA-TBS-USAGE-001`, `Q-DBA-TBS-DATAFILES-001`) se **relocalizaron** (mismos IDs, sin duplicar) a `queries/oracle/discovery/` y `queries/oracle/tablespaces/` respectivamente. Se agregaron 20 queries nuevas para las 18 áreas Oracle Core (`Q-ORA-*`) — ver sección "Oracle Core queries (Fase 2)" abajo.

## Tools semánticas MCP (nivel Gateway)

| tool | catálogo | dominio | agente principal |
|---|---|---|---|
| `get_database_identity` | core-14 | discovery | oracle-discovery-analyst |
| `get_instance_status` | core-14 | discovery/dba | oracle-discovery-analyst, oracle-dba-analyst |
| `get_rac_topology` | core-14 | rac | oracle-rac-analyst |
| `get_session_distribution` | core-14 | rac | oracle-rac-analyst |
| `get_wait_events` | core-14 | performance | oracle-performance-analyst |
| `get_top_sql_metrics` | core-14 | performance | oracle-performance-analyst |
| `get_tablespace_usage` | core-14 | dba/capacity | oracle-dba-analyst, capacity-analyst |
| `get_asm_usage` | core-14 | asm | oracle-asm-storage-analyst |
| `get_dataguard_status` | core-14 | dataguard | oracle-dataguard-analyst |
| `get_listener_status` | core-14 | network | oracle-network-analyst |
| `get_os_cpu` | core-14 | os | os-platform-analyst |
| `get_os_memory` | core-14 | os | os-platform-analyst |
| `get_os_io` | core-14 | os | os-platform-analyst |
| `get_os_network` | core-14 | os | os-platform-analyst |
| `get_rman_status` | extensión F1 | rman | oracle-backup-recovery-analyst |
| `get_security_posture` | extensión F1 | security | oracle-security-analyst |
| `get_capacity_trend` | extensión F1 | capacity | capacity-analyst |
| `get_pdb_state` | extensión F1 | multitenant | oracle-multitenant-analyst |

Manifest completo de tools (schema de input/output, certificación): [`mcp/tool-manifest.md`](../mcp/tool-manifest.md).

## Queries certificadas materializadas (Fase 1) — Identity & Scope

| id | purpose | versions | platform | architecture | container_scope | database_role_scope |
|---|---|---|---|---|---|---|
| `Q-DISC-IDENTITY-001` | Identidad de versión/edición/rol | 10g–23ai | todas | todas | ANY_CONTAINER | ANY |
| `Q-DISC-INSTANCE-001` | Estado de instancia y modo | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | ANY |
| `Q-DISC-RAC-001` | Topología RAC | 11gR2–23ai | Linux/RHEL/SUSE/Solaris/AIX/Windows | RAC | NOT_APPLICABLE | ANY |
| `Q-DISC-ASM-001` | Presencia de ASM | 11g–23ai | todas | ASM | NOT_APPLICABLE | ANY |
| `Q-DBA-TBS-USAGE-001` | Uso de tablespaces | 10g–23ai | todas | NON-CDB/CDB | ANY_CONTAINER | ANY |
| `Q-DBA-TBS-DATAFILES-001` | Detalle de datafiles/autoextend | 10g–23ai | todas | NON-CDB/CDB | ANY_CONTAINER | ANY |
| `Q-PERF-WAIT-AWR-001` | Wait events agregados (AWR) | 10g–23ai (Diagnostics Pack) | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-PERF-WAIT-ASH-001` | Wait events granulares (ASH) | 10g–23ai (Diagnostics Pack) | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-PERF-WAIT-STATSPACK-001` | Wait events (fallback sin licencia) | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-RAC-SESSION-DIST-001` | Distribución de sesiones por instancia | 11gR2–23ai | Linux/RHEL/SUSE/Solaris/AIX/Windows | RAC | NOT_APPLICABLE | ANY |
| `Q-RAC-SERVICE-PLACEMENT-001` | Placement y goals de servicio | 11gR2–23ai | ídem | RAC | NOT_APPLICABLE | ANY |
| `Q-ASM-DG-USAGE-001` | Espacio usable por disk group | 11g–23ai | ídem | ASM | NOT_APPLICABLE | ANY |
| `Q-ASM-OPERATION-001` | Progreso de rebalance (lectura) | 11g–23ai | ídem | ASM | NOT_APPLICABLE | ANY |
| `Q-DG-STATS-001` | Lag de transporte/apply | 10g–23ai | todas | Primary/Standby | NOT_APPLICABLE | ANY |
| `Q-DG-ARCHIVE-GAP-001` | Gap de archivelog | 10g–23ai | todas | Primary/Standby | NOT_APPLICABLE | ANY |
| `Q-CDB-PDB-STATE-001` | Estado de PDBs | 12c–23ai | todas | CDB | CDB_ROOT | ANY |
| `Q-CDB-CONTAINERS-001` | Metadata de contenedores | 12c–23ai | todas | CDB | CDB_ROOT | ANY |
| `Q-RMAN-BACKUP-JOB-001` | Estado de jobs de backup | 10g–23ai | todas | Standalone/RAC | NOT_APPLICABLE | ANY |
| `Q-RMAN-BACKUPSET-001` | Detalle de backup sets | 10g–23ai | todas | Standalone/RAC | NOT_APPLICABLE | ANY |
| `Q-NET-TNS-CONFIG-001` | Lectura de config Oracle Net | 10g–23ai | todas (ruta por plataforma) | todas | NOT_APPLICABLE | NOT_APPLICABLE |
| `Q-NET-LISTENER-LOG-001` | Extracto de listener.log | 10g–23ai | todas | todas | NOT_APPLICABLE | NOT_APPLICABLE |
| `Q-OS-LINUX-MEM-001` | Memoria/swap (Linux) | N/A | Oracle Linux/RHEL/SUSE | todas | NOT_APPLICABLE | NOT_APPLICABLE |
| `Q-OS-LINUX-HUGEPAGES-001` | HugePages (Linux) | N/A | Oracle Linux/RHEL/SUSE | todas | NOT_APPLICABLE | NOT_APPLICABLE |
| `Q-CAP-TIMESERIES-001` | Serie histórica de un recurso | 10g–23ai | todas | todas | ANY_CONTAINER | ANY |

`Q-PERF-WAIT-*` se restringen a `PRIMARY` porque AWR/ASH/Statspack reflejan actividad de sesiones de usuario, mínima o nula en un Standby en mount — ver `skills/performance/wait-events.md`.

## Queries certificadas materializadas (Fase 1) — Cost, Risk & Sensitivity

| id | objects_accessed | risk_class | cost_class | timeout_s | max_rows | sensitivity | license_requirements |
|---|---|---|---|---|---|---|---|
| `Q-DISC-IDENTITY-001` | `V$INSTANCE`, `V$DATABASE` | R0 | LOW | 10 | 5 | LOW | none |
| `Q-DISC-INSTANCE-001` | `V$INSTANCE`, `GV$INSTANCE` | R0 | LOW | 10 | 50 | LOW | none |
| `Q-DISC-RAC-001` | `GV$INSTANCE`, `V$ACTIVE_INSTANCES` | R0 | LOW | 15 | 50 | MEDIUM (hostnames) | none |
| `Q-DISC-ASM-001` | `V$ASM_DISKGROUP` | R0 | LOW | 10 | 20 | LOW | none |
| `Q-DBA-TBS-USAGE-001` | `DBA_TABLESPACE_USAGE_METRICS`, `DBA_DATA_FILES` | R0 | LOW | 20 | 500 | MEDIUM (nombres) | none |
| `Q-DBA-TBS-DATAFILES-001` | `DBA_DATA_FILES` | R0 | MEDIUM | 20 | 2000 | MEDIUM | none |
| `Q-PERF-WAIT-AWR-001` | `DBA_HIST_SYSTEM_EVENT` | R0 | MEDIUM | 60 | 200 | MEDIUM | Diagnostics Pack |
| `Q-PERF-WAIT-ASH-001` | `V$ACTIVE_SESSION_HISTORY`, `DBA_HIST_ACTIVE_SESS_HISTORY` | R0 | HIGH | 60 | 1000 | MEDIUM | Diagnostics Pack |
| `Q-PERF-WAIT-STATSPACK-001` | `STATS$SYSTEM_EVENT` | R0 | MEDIUM | 60 | 200 | MEDIUM | none |
| `Q-RAC-SESSION-DIST-001` | `GV$SESSION`, `GV$SERVICES` | R0 | MEDIUM | 30 | 5000 | MEDIUM | none |
| `Q-RAC-SERVICE-PLACEMENT-001` | `DBA_SERVICES`, `GV$SERVICES` | R0 | LOW | 20 | 200 | MEDIUM | none |
| `Q-ASM-DG-USAGE-001` | `V$ASM_DISKGROUP` | R0 | LOW | 15 | 50 | LOW | none |
| `Q-ASM-OPERATION-001` | `V$ASM_OPERATION` | R0 | LOW | 15 | 50 | LOW | none |
| `Q-DG-STATS-001` | `V$DATAGUARD_STATS`, `V$ARCHIVE_DEST_STATUS` | R0 | LOW | 20 | 50 | MEDIUM | none |
| `Q-DG-ARCHIVE-GAP-001` | `V$ARCHIVE_GAP` | R0 | LOW | 15 | 50 | LOW | none |
| `Q-CDB-PDB-STATE-001` | `DBA_PDBS`, `V$PDBS` | R0 | LOW | 15 | 200 | MEDIUM (nombres) | none (multi-PDB puede ser LICENSE_DEPENDENT — ver `docs/CAPABILITY_MATRIX.md`) |
| `Q-CDB-CONTAINERS-001` | `V$CONTAINERS` | R0 | LOW | 15 | 200 | LOW | none |
| `Q-RMAN-BACKUP-JOB-001` | `V$RMAN_BACKUP_JOB_DETAILS` | R0 | MEDIUM | 30 | 500 | LOW | none |
| `Q-RMAN-BACKUPSET-001` | `V$BACKUP_SET` | R0 | MEDIUM | 30 | 2000 | LOW | none |
| `Q-NET-TNS-CONFIG-001` | `tnsnames.ora`, `sqlnet.ora` (archivo, collector certificado) | R0 | LOW | 15 | N/A | HIGH (hostnames/IP; posibles secretos → sanitizer bloquea) | none |
| `Q-NET-LISTENER-LOG-001` | `listener.log` (ventana acotada) | R0 | MEDIUM | 30 | 5000 líneas | MEDIUM | none |
| `Q-OS-LINUX-MEM-001` | `/proc/meminfo` | R0 | LOW | 10 | N/A | LOW | none |
| `Q-OS-LINUX-HUGEPAGES-001` | `/proc/meminfo`, `vm.nr_hugepages` | R0 | LOW | 10 | N/A | LOW | none |
| `Q-CAP-TIMESERIES-001` | `DBA_HIST_*`/snapshots retenidos | R0 | MEDIUM | 45 | 5000 | LOW | none |

Todas con `status: active`, `execution_mode: READ_ONLY`, `tests:` referenciado a `tests/test_no_write_operations.*`, `tests/test_query_limits.*`, `tests/test_query_contract_requires_container_scope.sh`, `tests/test_query_contract_requires_role_scope.sh`, `tests/test_query_contract_requires_cost_class.sh`, `tests/test_query_contract_requires_license_metadata.sh` como mínimo. Ninguna entrada certificada tiene `cost_class: BLOCKED` — esa clase describe por qué una query se **rechaza** del catálogo (ver `policies/query-cost-policy.md`), no un modo de ejecución.

## Oracle Core queries (Fase 2) — Identity & Scope

| id | purpose | versions | platform | architecture | container_scope | database_role_scope |
|---|---|---|---|---|---|---|
| `Q-ORA-DB-STATE-001` | Flags globales de V$DATABASE (flashback/guard/protection) | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | ANY |
| `Q-ORA-INSTANCE-STATE-001` | Estado operativo de instancia(s) | 10g–23ai | todas | Standalone/RAC | NOT_APPLICABLE | ANY |
| `Q-ORA-PARAMETERS-001` | Parámetros no-default | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | ANY |
| `Q-ORA-PARAMETERS-RAC-DIFF-001` | Parámetros divergentes entre instancias | 10g–23ai | todas | RAC | ANY_CONTAINER | ANY |
| `Q-ORA-SPFILE-001` | Existencia de SPFILE / cambios no persistidos | 10g–23ai | todas | Standalone/RAC | NOT_APPLICABLE | ANY |
| `Q-ORA-CONTROLFILE-001` | Multiplexado y record sections | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | ANY |
| `Q-ORA-REDO-001` | Configuración de grupos/miembros de redo | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-ORA-REDO-SWITCH-FREQ-001` | Frecuencia de log switches (ventana) | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-ORA-ARCHIVE-001` | Configuración/estado de destinos de archivado | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-ORA-TEMP-001` | Uso/configuración de tempfiles | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | ANY |
| `Q-ORA-UNDO-001` | Configuración/uso de UNDO activo | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-ORA-SESSIONS-SUMMARY-001` | Resumen agregado de sesiones | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | ANY |
| `Q-ORA-PROCESSES-SUMMARY-001` | Resumen de procesos vs. límite | 10g–23ai | todas | Standalone/RAC | NOT_APPLICABLE | ANY |
| `Q-ORA-JOBS-SUMMARY-001` | Jobs fallidos/broken/larga duración | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-ORA-OBJECTS-INVENTORY-001` | Inventario agregado de objetos | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | ANY |
| `Q-ORA-INVALID-OBJECTS-001` | Objetos inválidos por owner/tipo | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | ANY |
| `Q-ORA-COMPONENTS-001` | Estado/versión de componentes | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | ANY |
| `Q-ORA-RESOURCE-LIMITS-001` | Uso pico vs. límite de recursos | 10g–23ai | todas | Standalone/RAC | NOT_APPLICABLE | ANY |
| `Q-ORA-DIAGNOSTICS-ADR-001` | Incidentes ADR abiertos | 11g–23ai | todas | Standalone/RAC | NOT_APPLICABLE | ANY |
| `Q-ORA-DIAGNOSTICS-ALERTLOG-001` | Extracto acotado de alert log (errores ORA-*) | 10g–23ai | todas | Standalone/RAC | NOT_APPLICABLE | ANY |

## Oracle Core queries (Fase 2) — Cost, Risk & Sensitivity

| id | objects_accessed | risk_class | cost_class | timeout_s | max_rows | sensitivity | license_requirements |
|---|---|---|---|---|---|---|---|
| `Q-ORA-DB-STATE-001` | `V$DATABASE` | R0 | LOW | 10 | 1 | LOW | none |
| `Q-ORA-INSTANCE-STATE-001` | `GV$INSTANCE` | R0 | LOW | 10 | 50 | LOW | none |
| `Q-ORA-PARAMETERS-001` | `V$PARAMETER` | R0 | LOW | 20 | 500 | MEDIUM | none |
| `Q-ORA-PARAMETERS-RAC-DIFF-001` | `GV$PARAMETER` | R0 | MEDIUM | 30 | 1000 | MEDIUM | none |
| `Q-ORA-SPFILE-001` | `V$SPPARAMETER`, `V$PARAMETER` | R0 | LOW | 10 | 500 | LOW | none |
| `Q-ORA-CONTROLFILE-001` | `V$CONTROLFILE`, `V$CONTROLFILE_RECORD_SECTION` | R0 | LOW | 10 | 100 | LOW | none |
| `Q-ORA-REDO-001` | `V$LOG`, `V$LOGFILE` | R0 | LOW | 10 | 200 | LOW | none |
| `Q-ORA-REDO-SWITCH-FREQ-001` | `V$LOG_HISTORY` | R0 | MEDIUM | 30 | 2000 | LOW | none |
| `Q-ORA-ARCHIVE-001` | `V$ARCHIVE_DEST`, `V$ARCHIVE_DEST_STATUS`, `V$ARCHIVED_LOG` | R0 | LOW | 15 | 100 | MEDIUM | none |
| `Q-ORA-TEMP-001` | `DBA_TEMP_FILES`, `DBA_TEMP_FREE_SPACE` | R0 | LOW | 15 | 200 | MEDIUM | none |
| `Q-ORA-UNDO-001` | `V$PARAMETER`, `DBA_TABLESPACES`, `V$UNDOSTAT` | R0 | LOW | 15 | 100 | LOW | none |
| `Q-ORA-SESSIONS-SUMMARY-001` | `V$SESSION` (agregado) | R0 | MEDIUM | 20 | 200 | MEDIUM | none |
| `Q-ORA-PROCESSES-SUMMARY-001` | `V$PROCESS`, `V$PARAMETER` | R0 | LOW | 10 | 5 | LOW | none |
| `Q-ORA-JOBS-SUMMARY-001` | `DBA_SCHEDULER_JOBS`, `DBA_SCHEDULER_JOB_RUN_DETAILS`, `DBA_JOBS` | R0 | MEDIUM | 20 | 500 | MEDIUM | none |
| `Q-ORA-OBJECTS-INVENTORY-001` | `DBA_OBJECTS` (agregado) | R0 | MEDIUM | 30 | 1000 | MEDIUM | none |
| `Q-ORA-INVALID-OBJECTS-001` | `DBA_OBJECTS` | R0 | LOW | 20 | 500 | MEDIUM | none |
| `Q-ORA-COMPONENTS-001` | `DBA_REGISTRY` | R0 | LOW | 10 | 100 | LOW | none |
| `Q-ORA-RESOURCE-LIMITS-001` | `V$RESOURCE_LIMIT` | R0 | LOW | 10 | 50 | LOW | none |
| `Q-ORA-DIAGNOSTICS-ADR-001` | `V$DIAG_INFO`, `DBA_OUTSTANDING_ALERTS` | R0 | LOW | 15 | 100 | MEDIUM | none |
| `Q-ORA-DIAGNOSTICS-ALERTLOG-001` | alert log (archivo, collector certificado) | R0 | MEDIUM | 30 | 2000 | HIGH | none |

Todas con `status: active`, `execution_mode: READ_ONLY`, mismo set mínimo de tests que el resto del catálogo. Ninguna es `cost_class: BLOCKED`. Ninguna toca tablas de aplicación (`tests/test_no_application_table_access.sh`, `tests/test_application_data_blocked.sh`).

## Extensión más allá de las 14 tools nombradas

`Q-RMAN-*`, `Q-NET-*` (más allá de listener básico), y `Q-CAP-TIMESERIES-001` no tienen tool MCP 1:1 en la lista original de la sección 4 del prompt maestro. Se certificaron en Fase 1 porque los agentes 7.9 (`oracle-backup-recovery-analyst`), 7.10 (`oracle-network-analyst`) y 7.13 (`capacity-analyst`) los requieren para cumplir su contrato — ver decisión arquitectónica 9 en `ARCHITECTURE.md`. Cualquier extensión futura del catálogo sigue `/change query`.

## Queries no certificadas

Si un agente necesita una query fuera de este catálogo, **no la ejecuta**. La genera como texto (SQL/comando) para que el DBA la revise y ejecute manualmente, y simultáneamente dispara `/change query` para evaluar su certificación futura.

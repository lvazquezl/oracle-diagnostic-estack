# Query Registry — Catálogo certificado read-only

Todo query/comando aquí es de sólo lectura por construcción (`execution_mode: READ_ONLY`, ver [Query Contract v2](../docs/CONTRACTS.md#query-contract-v2-foundation-hardening)). Ninguna entrada puede tener un verbo distinto de `SELECT`/`get`/`show status`/equivalente. Las 14 tools "semánticas" nombradas explícitamente en el prompt maestro están marcadas `core-14`; las demás son extensión Fase 1 documentada en [ARCHITECTURE.md](../ARCHITECTURE.md#5-decisiones-arquitectónicas-fase-1) decisión 9.

> **Foundation Hardening**: esta tabla migró a Query Contract v2 — se separó en "Identity & Scope" y "Cost, Risk & Sensitivity" para mantener cada tabla legible. `id` es la clave de unión entre ambas. `risk_class` (seguridad) y `cost_class` (impacto operacional) son dimensiones **distintas** — ver `policies/query-cost-policy.md`.

> **Fase 2 (Oracle Core)**: el catálogo Oracle se organizó por carpeta bajo `queries/oracle/<categoría>/`, una query por archivo (`<query_id>.md`), en vez de un único archivo `.md` plano por query en `queries/`. Las 4 queries de discovery (`Q-DISC-IDENTITY-001`, `Q-DISC-INSTANCE-001`, `Q-DISC-RAC-001`, `Q-DISC-ASM-001`) y las 2 de tablespaces (`Q-DBA-TBS-USAGE-001`, `Q-DBA-TBS-DATAFILES-001`) se **relocalizaron** (mismos IDs, sin duplicar) a `queries/oracle/discovery/` y `queries/oracle/tablespaces/` respectivamente. Se agregaron 20 queries nuevas para las 18 áreas Oracle Core (`Q-ORA-*`) — ver sección "Oracle Core queries (Fase 2)" abajo.

> **Fase 4 (RAC/GI/ASM/Network)**: `Q-RAC-SESSION-DIST-001` se relocalizó (mismo ID, sin duplicar) a `queries/rac/`. Las filas Foundation `Q-RAC-SERVICE-PLACEMENT-001`/`Q-ASM-DG-USAGE-001`/`Q-ASM-OPERATION-001` nunca tuvieron un archivo `.md` real pese a figurar en la sección "materializadas" — gap pre-existente detectado y corregido en esta fase: reemplazadas por 7 queries genuinamente materializadas bajo `queries/rac/`/`queries/asm/` (`Q-RAC-TOPOLOGY-001`, `Q-RAC-SERVICES-001` — cubre placement, `Q-RAC-INTERCONNECT-001`, `Q-RAC-GES-GCS-001`, `Q-ASM-TOPOLOGY-001` — cubre espacio usable vía `V$ASM_DISKGROUP_STAT`, `Q-ASM-DISKS-001`, `Q-ASM-REBALANCE-001` — cubre progreso de rebalance).

> **Fase 5 (Data Guard)**: mismo gap pre-existente detectado — `Q-DG-STATS-001`/`Q-DG-ARCHIVE-GAP-001` (Foundation) figuraban "materializadas" sin archivo real. Se materializaron ambas de verdad bajo `queries/dataguard/` (mismos IDs, sin duplicar) y se agregaron 5 queries nuevas: `Q-DG-ROLE-001` (role discovery), `Q-DG-DEST-001` (destinos de archive), `Q-DG-ARCHIVED-LOG-001` (secuencias por thread, ventana acotada), `Q-DG-MANAGED-PROCESS-001` (MRP/RFS/procesos), `Q-DG-SRL-001` (standby redo logs) — 7 queries certificadas en total.
>
> **PHASE 5 — DATA GUARD COMPATIBILITY & QUERY CERTIFICATION HARDENING**: `Q-DG-ROLE-001` corregida (`LOG_ARCHIVE_CONFIG` no es columna de `V$DATABASE` — bug de certificación real, ver `docs/PHASE_5_COMPATIBILITY_HARDENING.md`); todas las queries `Q-DG-*` pasaron de `max: latest` a `max: "23.0"` explícito; `Q-DG-MANAGED-PROCESS-001` modernizada a variantes legacy/modern (`V$MANAGED_STANDBY` default, `V$DATAGUARD_PROCESS` on-demand).
>
> **PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY HARDENING**: metadata de `V$DATAGUARD_PROCESS` corregida contra Oracle Database Reference — min_version real 12.2.0.1 (no 11.2), columnas reales NAME/PID/TYPE/ROLE/ACTION/CLIENT_PID/CLIENT_ROLE/THREAD#/SEQUENCE#/BLOCK#/BLOCK_COUNT (STATUS/CLIENT_PROCESS eliminadas — no existen en esa vista). `Q-DG-MANAGED-PROCESS-001` pasa de "legacy default + modern on-demand" a una partición real sin solapamiento: legacy 10.2–12.1 (única opción, `V$MANAGED_STANDBY` deprecada desde 12.2.0.1), modern 12.2–23.0 (única opción). Ver `docs/PHASE_5_FINAL_PROCESS_VIEW_PORTABILITY_HARDENING.md`.

> **Fase 6 (Multitenant/CDB/PDB)**: mismo gap pre-existente detectado — `Q-CDB-PDB-STATE-001`/`Q-CDB-CONTAINERS-001` (Foundation) figuraban "materializadas" sin archivo real y con `container_scope: CDB_ROOT` (fuera del enum `CDB_ROOT_ONLY|PDB_ONLY|ANY_CONTAINER|NON_CDB_ONLY|NOT_APPLICABLE`). Se materializaron ambas de verdad bajo `queries/multitenant/` (mismos IDs, sin duplicar, `container_scope` corregido a `CDB_ROOT_ONLY`) y se agregaron 13 queries nuevas — 15 queries certificadas en total. Nombres de vista verificados contra Oracle Database Reference antes de declarar metadata (ej. el Resource Manager real es `DBA_CDB_RSRC_PLAN_DIRECTIVES`, no "CDB_RSRC_PLAN_DIRECTIVES"). Ver `docs/PHASE_6_ORACLE_MULTITENANT.md`.

> **PHASE 6 — MULTITENANT QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING**: 3 defectos de certificación adicionales detectados y corregidos, independientemente verificados vía WebFetch contra docs.oracle.com (no confiados por declaración): (1) `Q-CDB-PDB-SAVED-STATE-001` usaba `CDB_PDB_SAVED_STATES`, que **no es una vista Oracle real** (404 en docs.oracle.com) — corregida a `DBA_PDB_SAVED_STATES` (7 columnas reales), con min_version patch-level `12.1.0.2` (no `12.1` genérico — PDB Saved State no existe en 12.1.0.0/12.1.0.1). (2) `Q-CDB-RESOURCE-USAGE-001` declaraba `V$RSRCPDBMETRIC` disponible desde 12.1 — la vista real se introduce en 12.2.0.1; corregida a `min: "12.2"`, 12.1 degrada a `PARTIALLY_SUPPORTED` sin fuente alternativa inventada. (3) `Q-CDB-PLUGIN-VIOLATIONS-001` seleccionaba `CON_ID` incondicionalmente desde 12.1 — esa columna no existe en la referencia 12.1 (9 columnas), se agrega en 12.2 (10 columnas); split en variantes legacy (12.1, sin `CON_ID`, `container_id: NOT_AVAILABLE`) / modern (12.2+, con `CON_ID`). El SQL Static Validator (`tests/test_sql_static_validator.sh`) se extendió con un chequeo nuevo (view-level y column-level `min_version` cross-check contra el rango declarado del bloque SQL) que hasta ahora nunca se ejecutaba — causa raíz de que las tres metadata incorrectas certificaran SQL incorrecto sin que ningún test lo detectara. Ver `docs/PHASE_6_QUERY_COMPATIBILITY_HARDENING.md`.

> **Fase 3 (Oracle Performance)**: `Q-PERF-WAIT-AWR-001` y `Q-PERF-WAIT-ASH-001` se **relocalizaron** (mismos IDs, sin duplicar) de `queries/` plano a `queries/performance/waits/`. `Q-PERF-WAIT-STATSPACK-001` (antes sólo `registered`) se materializó en la misma carpeta — ver `docs/PHASE_3_ORACLE_PERFORMANCE.md`. Las filas de estas 3 queries en las tablas "Fase 1" abajo permanecen sin cambio (identidad de catálogo, no ubicación física). Se agregaron 18 queries nuevas bajo `queries/performance/<categoría>/` — ver sección "Performance queries (Fase 3)" abajo.

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
| `Q-RAC-SESSION-DIST-001` | Distribución de sesiones por instancia (relocalizada a `queries/rac/` en Fase 4) | 11gR2–23ai | Linux/RHEL/SUSE/Solaris/AIX/Windows | RAC | NOT_APPLICABLE | ANY |
| `Q-RAC-TOPOLOGY-001` | Topología de instancias RAC | 11gR2–23ai | ídem | RAC | NOT_APPLICABLE | ANY |
| `Q-RAC-SERVICES-001` | Servicios, CLB/RLB goal, placement configurado vs. activo | 11gR2–23ai | ídem | RAC | NOT_APPLICABLE | ANY |
| `Q-RAC-INTERCONNECT-001` | Interfaces de interconnect privado activas | 11gR2–23ai | ídem | RAC | NOT_APPLICABLE | ANY |
| `Q-RAC-GES-GCS-001` | Indicadores agregados GES/GCS | 11gR2–23ai | ídem | RAC | NOT_APPLICABLE | ANY |
| `Q-ASM-TOPOLOGY-001` | Instancias ASM y disk groups (`V$ASM_DISKGROUP_STAT`, sin disk discovery) | 11gR2–23ai | ídem | ASM | NOT_APPLICABLE | ANY |
| `Q-ASM-DISKS-001` | Salud de discos individuales (sólo anómalos) | 11gR2–23ai | ídem | ASM | NOT_APPLICABLE | ANY |
| `Q-ASM-REBALANCE-001` | Progreso de operaciones ASM en curso (lectura) | 11gR2–23ai | ídem | ASM | NOT_APPLICABLE | ANY |
| `Q-DG-ROLE-001` | Rol, protección, switchover status, flashback | 10g–23ai | todas | Primary/Standby | ANY_CONTAINER | ANY |
| `Q-DG-STATS-001` | Lag de transporte/apply | 10g–23ai | todas | Primary/Standby | ANY_CONTAINER | STANDBY |
| `Q-DG-DEST-001` | Estado de destinos de archive | 10g–23ai | todas | Primary/Standby | ANY_CONTAINER | PRIMARY |
| `Q-DG-ARCHIVED-LOG-001` | Secuencias recibidas/aplicadas por thread (ventana acotada) | 10g–23ai | todas | Primary/Standby | ANY_CONTAINER | STANDBY |
| `Q-DG-ARCHIVE-GAP-001` | Gap de archivelog (thread-aware) | 10g–23ai | todas | Primary/Standby | ANY_CONTAINER | STANDBY |
| `Q-DG-MANAGED-PROCESS-001` | Procesos MRP/RFS/LNS/ARCH (legacy V1 10.2–12.1, modern V2 12.2–23.0, sin solapamiento) | 10g–23ai | todas | Primary/Standby | ANY_CONTAINER | ANY |
| `Q-DG-SRL-001` | Standby redo logs por thread | 10g–23ai | todas | Primary/Standby | ANY_CONTAINER | ANY |
| `Q-CDB-PDB-STATE-001` | Estado de PDBs (legacy V1 12.1, modern V2 12.2–23.0 con Application Containers/Proxy PDB/Local Undo) | 12c–23ai | todas | CDB | CDB_ROOT_ONLY | ANY |
| `Q-CDB-CONTAINERS-001` | Topología completa de contenedores (incl. CDB$ROOT) | 12c–23ai | todas | CDB | CDB_ROOT_ONLY | ANY |
| `Q-CDB-PDB-SAVED-STATE-001` | Visibilidad de PDB save state | 12.1.0.2–23ai | todas | CDB | CDB_ROOT_ONLY | ANY |
| `Q-CDB-SERVICES-001` | Servicios por PDB (CLB/RLB goal, instancia activa) | 12c–23ai | ídem | CDB | CDB_ROOT_ONLY | ANY |
| `Q-CDB-SESSION-DIST-001` | Distribución de sesiones por PDB/instancia/servicio | 12c–23ai | ídem | CDB | CDB_ROOT_ONLY | ANY |
| `Q-CDB-TABLESPACES-001` | Uso de tablespaces por PDB | 12c–23ai | todas | CDB | CDB_ROOT_ONLY | ANY |
| `Q-CDB-TEMP-001` | Uso de TEMP por PDB | 12c–23ai | todas | CDB | CDB_ROOT_ONLY | ANY |
| `Q-CDB-PARAMETERS-001` | Scope de parámetros CDB$ROOT vs. PDB | 12c–23ai | todas | CDB | CDB_ROOT_ONLY | ANY |
| `Q-CDB-USERS-001` | Usuarios comunes vs. locales (sólo visibilidad) | 12c–23ai | todas | CDB | CDB_ROOT_ONLY | ANY |
| `Q-CDB-ROLES-001` | Roles comunes vs. locales (sólo visibilidad) | 12c–23ai | todas | CDB | CDB_ROOT_ONLY | ANY |
| `Q-CDB-COMPONENTS-001` | Salud de componentes por contenedor | 12c–23ai | todas | CDB | CDB_ROOT_ONLY | ANY |
| `Q-CDB-PLUGIN-VIOLATIONS-001` | Plug-in violations por PDB | 12c–23ai (CON_ID sólo 12.2+) | todas | CDB | CDB_ROOT_ONLY | ANY |
| `Q-CDB-RESOURCE-USAGE-001` | Consumo de recursos por PDB (CPU/sesiones/parallel/SGA/PGA/I/O) | 12.2–23ai (12.1: PARTIALLY_SUPPORTED) | todas | CDB | CDB_ROOT_ONLY | ANY |
| `Q-CDB-RESOURCE-MANAGER-001` | CDB Resource Plan y directivas por PDB (sólo lectura) | 12c–23ai | todas | CDB | CDB_ROOT_ONLY | ANY |
| `Q-CDB-LOCKDOWN-001` | Lockdown profiles asignados (sólo lectura) | 12.2–23ai | todas | CDB | CDB_ROOT_ONLY | ANY |
| `Q-RMAN-BACKUP-JOB-001` | Estado de jobs de backup | 10g–23ai | todas | Standalone/RAC | NOT_APPLICABLE | ANY |
| `Q-RMAN-BACKUPSET-001` | Detalle de backup sets | 10g–23ai | todas | Standalone/RAC | NOT_APPLICABLE | ANY |
| `Q-NET-TNS-CONFIG-001` | Lectura de config Oracle Net | 10g–23ai | todas (ruta por plataforma) | todas | NOT_APPLICABLE | NOT_APPLICABLE |
| `Q-NET-LISTENER-LOG-001` | Extracto de listener.log | 10g–23ai | todas | todas | NOT_APPLICABLE | NOT_APPLICABLE |
| `Q-OS-LINUX-MEM-001` | Memoria/swap (Linux) | N/A | Oracle Linux/RHEL/SUSE | todas | NOT_APPLICABLE | NOT_APPLICABLE |
| `Q-OS-LINUX-HUGEPAGES-001` | HugePages (Linux) | N/A | Oracle Linux/RHEL/SUSE | todas | NOT_APPLICABLE | NOT_APPLICABLE |
| `Q-CAP-TIMESERIES-001` | Serie histórica de un recurso | 10g–23ai | todas | todas | ANY_CONTAINER | ANY |

`Q-PERF-WAIT-*` se restringen a `PRIMARY` porque AWR/ASH/Statspack reflejan actividad de sesiones de usuario, mínima o nula en un Standby en mount — ver `skills/performance/wait-events/SKILL.md`.

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
| `Q-RAC-TOPOLOGY-001` | `GV$INSTANCE`, `V$ACTIVE_INSTANCES` | R0 | LOW | 15 | 50 | MEDIUM | none |
| `Q-RAC-SERVICES-001` | `GV$SERVICES`, `GV$ACTIVE_SERVICES` | R0 | LOW | 15 | 200 | MEDIUM | none |
| `Q-RAC-INTERCONNECT-001` | `GV$CLUSTER_INTERCONNECTS` | R0 | LOW | 15 | 50 | HIGH | none |
| `Q-RAC-GES-GCS-001` | `GV$GES_STATISTICS`, `GV$GCS_STATISTICS`, `GV$INSTANCE_CACHE_TRANSFER` | R0 | MEDIUM | 30 | 200 | LOW | none |
| `Q-ASM-TOPOLOGY-001` | `GV$ASM_INSTANCE`, `V$ASM_DISKGROUP_STAT` | R0 | LOW | 15 | 100 | MEDIUM | none |
| `Q-ASM-DISKS-001` | `V$ASM_DISK` | R0 | MEDIUM | 30 | 500 | HIGH | none |
| `Q-ASM-REBALANCE-001` | `GV$ASM_OPERATION` | R0 | LOW | 15 | 50 | LOW | none |
| `Q-DG-ROLE-001` | `V$DATABASE` | R0 | LOW | 10 | 1 | MEDIUM | none |
| `Q-DG-STATS-001` | `V$DATAGUARD_STATS` | R0 | LOW | 15 | 20 | LOW | none |
| `Q-DG-DEST-001` | `V$ARCHIVE_DEST`, `V$ARCHIVE_DEST_STATUS` | R0 | LOW | 15 | 32 | HIGH | none |
| `Q-DG-ARCHIVED-LOG-001` | `V$ARCHIVED_LOG` | R0 | MEDIUM | 30 | 500 | LOW | none |
| `Q-DG-ARCHIVE-GAP-001` | `V$ARCHIVE_GAP` | R0 | LOW | 15 | 50 | LOW | none |
| `Q-DG-MANAGED-PROCESS-001` | `V$MANAGED_STANDBY`, `GV$MANAGED_STANDBY`, `V$DATAGUARD_PROCESS`, `GV$DATAGUARD_PROCESS` | R0 | LOW | 15 | 100 | LOW | none |
| `Q-DG-SRL-001` | `V$STANDBY_LOG`, `V$LOG` | R0 | LOW | 15 | 100 | LOW | none |
| `Q-CDB-PDB-STATE-001` | `V$PDBS` | R0 | LOW | 15 | 200 | MEDIUM (nombres) | none (multi-PDB puede ser LICENSE_DEPENDENT — ver `docs/CAPABILITY_MATRIX.md`) |
| `Q-CDB-CONTAINERS-001` | `V$CONTAINERS` | R0 | LOW | 15 | 200 | MEDIUM (nombres) | none |
| `Q-CDB-PDB-SAVED-STATE-001` | `DBA_PDB_SAVED_STATES` | R0 | LOW | 10 | 200 | MEDIUM (nombres) | none |
| `Q-CDB-SERVICES-001` | `GV$SERVICES`, `GV$ACTIVE_SERVICES` | R0 | LOW | 15 | 200 | MEDIUM (nombres) | none |
| `Q-CDB-SESSION-DIST-001` | `GV$SESSION` | R0 | MEDIUM | 20 | 500 | MEDIUM (nombres) | none |
| `Q-CDB-TABLESPACES-001` | `CDB_TABLESPACE_USAGE_METRICS`, `CDB_TABLESPACES`, `CDB_DATA_FILES` | R0 | LOW | 20 | 500 | LOW | none |
| `Q-CDB-TEMP-001` | `CDB_TEMP_FILES`, `GV$TEMP_SPACE_HEADER` | R0 | LOW | 15 | 200 | LOW | none |
| `Q-CDB-PARAMETERS-001` | `GV$SYSTEM_PARAMETER` | R0 | MEDIUM | 20 | 500 | MEDIUM (valores) | none |
| `Q-CDB-USERS-001` | `CDB_USERS` | R0 | MEDIUM | 20 | 500 | HIGH | none |
| `Q-CDB-ROLES-001` | `CDB_ROLES` | R0 | LOW | 15 | 200 | MEDIUM (nombres) | none |
| `Q-CDB-COMPONENTS-001` | `CDB_REGISTRY` | R0 | LOW | 15 | 500 | LOW | none |
| `Q-CDB-PLUGIN-VIOLATIONS-001` | `PDB_PLUG_IN_VIOLATIONS` | R0 | LOW | 15 | 200 | MEDIUM (texto libre) | none |
| `Q-CDB-RESOURCE-USAGE-001` | `V$RSRCPDBMETRIC` | R0 | LOW | 15 | 200 | LOW | none |
| `Q-CDB-RESOURCE-MANAGER-001` | `DBA_CDB_RSRC_PLAN_DIRECTIVES` | R0 | LOW | 15 | 200 | LOW | none |
| `Q-CDB-LOCKDOWN-001` | `CDB_LOCKDOWN_PROFILES` | R0 | LOW | 15 | 500 | LOW | none |
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

## Performance queries (Fase 3) — Identity & Scope

| id | purpose | versions | platform | architecture | container_scope | database_role_scope |
|---|---|---|---|---|---|---|
| `Q-PERF-DBTIME-001` | DB Time/DB CPU sobre ventana AWR | 10g–23ai (Diagnostics Pack) | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-PERF-DBTIME-CURRENT-001` | DB Time/DB CPU acumulado (sin licencia) | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-PERF-TOPSQL-001` | Top SQL sobre ventana AWR | 10g–23ai (Diagnostics Pack) | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-PERF-TOPSQL-CURRENT-001` | Top SQL acumulado (sin licencia) | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-PERF-PLAN-001` | Plan de ejecución actual | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-PERF-PLAN-HIST-001` | Historial de plan_hash_value (AWR) | 10g–23ai (Diagnostics Pack) | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-PERF-SGA-001` | Tamaño/componentes de SGA | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | ANY |
| `Q-PERF-PGA-001` | Uso/over-allocation de PGA | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | ANY |
| `Q-PERF-HARDPARSE-001` | Parse count total/hard | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-PERF-LIBCACHE-001` | Reloads/invalidations de Library Cache | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | ANY |
| `Q-PERF-SHAREDPOOL-001` | Memoria libre shared pool + dictionary cache | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | ANY |
| `Q-PERF-IO-001` | Waits de I/O dominantes | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-PERF-IO-FILESTAT-001` | Latencia por datafile | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-PERF-TEMP-001` | Uso activo de TEMP por sesión/SQL_ID | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-PERF-BLOCKING-001` | Cadenas de bloqueo blocker/waiter | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-PERF-LOCKS-001` | Enqueue locks activos | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-PERF-PARALLEL-001` | Sesiones Parallel Execution activas | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |
| `Q-PERF-REDO-001` | Volumen de redo y tasa de commit | 10g–23ai | todas | Standalone/RAC | ANY_CONTAINER | PRIMARY |

## Performance queries (Fase 3) — Cost, Risk & Sensitivity

| id | objects_accessed | risk_class | cost_class | timeout_s | max_rows | sensitivity | license_requirements |
|---|---|---|---|---|---|---|---|
| `Q-PERF-DBTIME-001` | `DBA_HIST_SYS_TIME_MODEL`, `DBA_HIST_SNAPSHOT` | R0 | MEDIUM | 30 | 100 | LOW | Diagnostics Pack |
| `Q-PERF-DBTIME-CURRENT-001` | `V$SYS_TIME_MODEL`, `V$INSTANCE` | R0 | LOW | 10 | 5 | LOW | none |
| `Q-PERF-TOPSQL-001` | `DBA_HIST_SQLSTAT`, `DBA_HIST_SNAPSHOT` | R0 | MEDIUM | 60 | 100 | MEDIUM | Diagnostics Pack |
| `Q-PERF-TOPSQL-CURRENT-001` | `V$SQLSTATS` | R0 | MEDIUM | 30 | 100 | MEDIUM | none |
| `Q-PERF-PLAN-001` | `V$SQL_PLAN` | R0 | LOW | 15 | 200 | LOW | none |
| `Q-PERF-PLAN-HIST-001` | `DBA_HIST_SQLSTAT`, `DBA_HIST_SNAPSHOT` | R0 | MEDIUM | 30 | 100 | LOW | Diagnostics Pack |
| `Q-PERF-SGA-001` | `V$SGA`, `V$SGAINFO`, `V$SGASTAT` | R0 | LOW | 10 | 50 | LOW | none |
| `Q-PERF-PGA-001` | `V$PGASTAT` | R0 | LOW | 10 | 30 | LOW | none |
| `Q-PERF-HARDPARSE-001` | `V$SYSSTAT` | R0 | LOW | 10 | 10 | LOW | none |
| `Q-PERF-LIBCACHE-001` | `V$LIBRARYCACHE` | R0 | LOW | 10 | 30 | LOW | none |
| `Q-PERF-SHAREDPOOL-001` | `V$SGASTAT`, `V$ROWCACHE` | R0 | LOW | 10 | 30 | LOW | none |
| `Q-PERF-IO-001` | `V$SYSTEM_EVENT` | R0 | LOW | 15 | 20 | LOW | none |
| `Q-PERF-IO-FILESTAT-001` | `V$FILESTAT`, `V$DATAFILE` | R0 | MEDIUM | 20 | 500 | MEDIUM | none |
| `Q-PERF-TEMP-001` | `V$SORT_USAGE`, `V$SESSION` | R0 | MEDIUM | 15 | 200 | MEDIUM | none |
| `Q-PERF-BLOCKING-001` | `V$SESSION` | R0 | MEDIUM | 15 | 200 | MEDIUM | none |
| `Q-PERF-LOCKS-001` | `V$LOCK`, `V$SESSION` | R0 | MEDIUM | 15 | 500 | MEDIUM | none |
| `Q-PERF-PARALLEL-001` | `V$PX_SESSION` | R0 | LOW | 15 | 200 | LOW | none |
| `Q-PERF-REDO-001` | `V$SYSSTAT` | R0 | LOW | 10 | 10 | LOW | none |

Todas con `status: active`, `execution_mode: READ_ONLY`, mismo set mínimo de tests que el resto del catálogo. Ninguna es `cost_class: BLOCKED`. Rutas `*-CURRENT-001`/`*-HIST-001` sin sufijo `-CURRENT-`/`-HIST-` son la alternativa AWR licenciada vs. la ruta estándar sin licencia respectivamente — ver `docs/PHASE_3_ORACLE_PERFORMANCE.md#awr-path` y `#standard-non-licensed-performance-path`. `Q-PERF-*` (excepto memoria estructural `SGA`/`PGA`/`LIBCACHE`/`SHAREDPOOL`, `database_role_scope: ANY`) se restringen a `PRIMARY` por la misma razón que `Q-PERF-WAIT-*` — reflejan actividad de sesión de usuario, mínima o nula en standby en mount.

## Extensión más allá de las 14 tools nombradas

`Q-RMAN-*`, `Q-NET-*` (más allá de listener básico), y `Q-CAP-TIMESERIES-001` no tienen tool MCP 1:1 en la lista original de la sección 4 del prompt maestro. Se certificaron en Fase 1 porque los agentes 7.9 (`oracle-backup-recovery-analyst`), 7.10 (`oracle-network-analyst`) y 7.13 (`capacity-analyst`) los requieren para cumplir su contrato — ver decisión arquitectónica 9 en `ARCHITECTURE.md`. Cualquier extensión futura del catálogo sigue `/change query`.

## Queries no certificadas

Si un agente necesita una query fuera de este catálogo, **no la ejecuta**. La genera como texto (SQL/comando) para que el DBA la revise y ejecute manualmente, y simultáneamente dispara `/change query` para evaluar su certificación futura.

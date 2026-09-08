# Phase 5 — Oracle Data Guard

Branch: `phase/5-dataguard`. Baseline: `v0.4.0-rac-gi-asm-network`. Objetivo del baseline resultante: `v0.5.0-dataguard`.

**Nota**: 3 defectos de certificación detectados post-construcción (bug real en `Q-DG-ROLE-001`, gap en el SQL Static Validator, política de versión futura inconsistente) fueron corregidos en un hardening posterior sobre esta misma rama — ver `docs/PHASE_5_COMPATIBILITY_HARDENING.md`. Un hardening final adicional corrigió metadata incorrecta de `V$DATAGUARD_PROCESS` (versión real de introducción, columnas reales) y una regresión CRLF — ver `docs/PHASE_5_FINAL_PROCESS_VIEW_PORTABILITY_HARDENING.md`. Las secciones de este documento reflejan el estado ya corregido por ambos.

## Scope

Capa especializada de diagnóstico Data Guard: rol/topología, protection mode/level, transporte y apply de redo, lag (transporte vs. apply, nunca sinónimos), gaps de archivelog thread-aware, standby redo logs, procesos MRP/RFS/LNS/LGWR/ARCH/DGRD, Data Guard Broker (visibilidad), FSFO/observer, y readiness de switchover/failover — nunca ejecutando ninguna transición de rol. No reconstruye Foundation/Oracle Core/Performance/RAC-GI-ASM-Network, no avanza a Multitenant/Backup-Recovery/Security profundos salvo integración necesaria, no implementa auto-remediation, no introduce un Execution Plane.

## Data Guard Agent

`agents/oracle-dataguard-analyst/` (v2.0.0) — materializado en contrato estructurado completo, mismo patrón que `oracle-rac-analyst`/`oracle-asm-storage-analyst`/`oracle-network-analyst` de Fase 4. Ningún agente separado para broker/transport/apply/fsfo — todo dentro del dominio `dataguard` (`# 2`).

## Data Guard Skills

21 skills materializados: `topology, role, protection, transport, apply, lag, archive-gaps, archive-destinations, processes, standby-redo-logs, real-time-apply, broker, fsfo, observer, switchover-readiness, failover-readiness, configuration-drift, healthcheck, assessment, troubleshooting, incident-analysis`. Reconciliación de la lista Foundation documentada en `skills/REGISTRY.md#dataguard`.

## Query catalog

`queries/dataguard/` — 7 queries: `Q-DG-ROLE-001`, `Q-DG-STATS-001`, `Q-DG-DEST-001`, `Q-DG-ARCHIVED-LOG-001`, `Q-DG-ARCHIVE-GAP-001`, `Q-DG-MANAGED-PROCESS-001`, `Q-DG-SRL-001`. Corrección de un gap pre-existente: `Q-DG-STATS-001`/`Q-DG-ARCHIVE-GAP-001` (Foundation) nunca tuvieron archivo real pese a figurar "materializadas" — mismo patrón que Fase 4 (RAC/ASM), corregido aquí. Ver `docs/DATAGUARD_READONLY_QUERIES.md`.

## Query variants

6 de las 7 queries son `implicit_full_range` (10.2–23.0, `max` explícito — nunca `latest`, ver Compatibility Hardening `# 10-15` — validadas contra `compatibility/oracle-dictionary/views.yaml`). `Q-DG-MANAGED-PROCESS-001` fue modernizada a un modelo de variantes real, con la frontera corregida contra Oracle Database Reference (Final Process-View Hardening): legacy (`V$MANAGED_STANDBY`/`GV$MANAGED_STANDBY`, única opción 10.2–12.1) y modern (`V$DATAGUARD_PROCESS`/`GV$DATAGUARD_PROCESS`, única opción 12.2–23.0 — introducida en 12.2.0.1, no 11.2) — partición sin solapamiento, con normalización semántica a un modelo lógico común.

## Role discovery

`dataguard/role` — `DATABASE_ROLE` como única fuente de verdad, nunca inferido de `OPEN_MODE` (`# 9`). Ver `docs/DATAGUARD_DIAGNOSTIC_MODEL.md#role-discovery-nunca-por-adivinanza`.

## Topology

`dataguard/topology` — modelo estructurado `configuration/primary/standbys/protection_mode/broker_enabled/fsfo_enabled`. RAC awareness por sitio, nunca confunde instancia con base lógica (`# 10`, `# 16`).

## Physical Standby support

Foco principal de la fase, `KNOWN_SUPPORTED` 10g–23ai en `agents/oracle-dataguard-analyst/manifest.yaml#supported_dataguard_architectures`.

## Logical Standby support

`PARTIALLY_SUPPORTED` — rol reconocido, análisis profundo específico fuera de alcance (`# 7`, `# 90`). Nunca se finge soporte completo.

## Snapshot Standby support

`PARTIALLY_SUPPORTED` — mismo criterio que Logical Standby.

## Far Sync awareness

`PARTIALLY_SUPPORTED` — reconocido cuando la evidencia lo indica, sin análisis profundo.

## Protection mode / Protection level

`dataguard/protection` — distingue configurado (`PROTECTION_MODE`) de efectivo (`PROTECTION_LEVEL`); una diferencia sostenida es evidencia de degradación, nunca afirmada como error sin descartar contexto transitorio (`# 32`).

## Redo transport

`dataguard/transport` — clasifica `HEALTHY|DEFERRED|ERROR|NETWORK_DELAY_SUSPECTED|DESTINATION_UNAVAILABLE|CONFIGURATION_MISMATCH` por destino (`# 11`).

## Redo apply

`dataguard/apply` — estado MRP, `recovery_mode`, secuencias, tasa de apply, real-time apply; nunca ejecuta `ALTER DATABASE RECOVER MANAGED STANDBY DATABASE` (`# 12`).

## Transport lag

`dataguard/lag` — regla `# 57` nombrada explícitamente: *high transport lag does not prove a network problem*.

## Apply lag

`dataguard/lag` — regla `# 56` nombrada explícitamente: *high apply lag is an observation, not a root cause*. Confidence por defecto `OBSERVATION`.

## Lag trending

`STABLE|INCREASING|DECREASING|INTERMITTENT|CATCHING_UP` (`# 14`) — alineación temporal de evidencia ya recolectada, sin forecasting complejo.

## Archive gaps

`dataguard/archive-gaps` — thread-aware siempre (`# 15`, `# 58`), 5 clasificaciones exhaustivas.

## RAC thread awareness

`THREAD#`/`SEQUENCE#` explícitos en todo el modelo de gaps/apply/SRL en RAC — nunca comparado entre threads como una sola serie (`# 15`, `# 16`).

## Standby redo logs

`dataguard/standby-redo-logs` — SRL Readiness Rule documentada y versión, nunca fórmula ciega (`# 17`, `# 18`).

## Real-time apply

`dataguard/real-time-apply` — distingue archived-log apply de real-time apply, nunca asume defecto sin requisito de diseño (`# 19`).

## Data Guard processes

`dataguard/processes` — MRP/RFS/LNS/LGWR/ARCH/DGRD según versión, evita reglas obsoletas entre versiones (`# 20`).

## Archive destinations

`dataguard/archive-destinations` — `SERVICE`/`SYNC`/`ASYNC`/`AFFIRM`/`VALID_FOR`/`DB_UNIQUE_NAME`/`NET_TIMEOUT`/`REOPEN`/`MAX_FAILURE` extraídos de forma segura, credenciales embebidas nunca expuestas (`# 33`, `# 52`).

## Parameter consistency

`dataguard/configuration-drift` — sólo parámetros que deben coincidir, nunca igualdad artificial de `DB_UNIQUE_NAME`/instance-specific/file locations/service definitions (`# 34`, `# 35`).

## Configuration drift

Ver arriba — mismo skill.

## Broker support

`dataguard/broker` — visibilidad completa: configuration status, member status/role, intended state, warnings/errores, protection mode, properties, FSFO, observer (`# 22`). Nunca modifica Broker.

## Broker collectors

`docs/DATAGUARD_BROKER_READONLY_COLLECTORS.md` — 4 collectors Broker + 1 de alert.log, reutilizando el Collector Contract de Fase 4 (`# 62`). Comandos allowlisted: `SHOW CONFIGURATION`, `SHOW DATABASE [VERBOSE] <tokenized-db>`, `SHOW FAST_START FAILOVER` (`# 23`). Bloqueados: `EDIT DATABASE/CONFIGURATION`, `ENABLE/DISABLE CONFIGURATION`, `SWITCHOVER TO`, `FAILOVER TO`, `REINSTATE DATABASE`, `CONVERT/ADD/REMOVE DATABASE` (`# 24`).

## Broker parsers

`parsers/dataguard/broker_parser.py` — 4 funciones (`parse_show_configuration`, `parse_show_database`, `parse_show_database_verbose`, `parse_show_fsfo`), Python 3 stdlib-only, mismo envelope/disciplina que `parsers/rac/` (Fase 4). `parsers/dataguard/alertlog_filter.py` filtra términos MRP/RFS/LNS/gap/transport/apply/broker en una ventana ya acotada (`# 50`).

## FSFO

`dataguard/fsfo` — enabled/target/threshold/observer visibility/protección/flashback/lag limit awareness; nunca habilita/deshabilita, nunca cambia thresholds (`# 26`).

## Observer

`dataguard/observer` — sólo visibilidad; `INSUFFICIENT_EVIDENCE` explícito si no puede verse con privilegios read-only; nunca `START OBSERVER` (`# 27`).

## Switchover readiness

Ver `docs/DATAGUARD_SWITCHOVER_READINESS.md`.

## Failover readiness

Ver `docs/DATAGUARD_FAILOVER_READINESS.md`.

## Data loss exposure

Calculado explícitamente en `dataguard/failover-readiness`, nunca omitido ni asumido en cero cuando el primary no es alcanzable (`# 30`).

## Active Data Guard licensing

`ACTIVE_DATA_GUARD_CHECK` — gate propio, independiente del Licensing Gate de AWR/ASH (`# 38`, `# 39`).

## Network correlation

Delegación a `oracle-network-analyst` sólo con evidencia real (timeout/TNS/destino inalcanzable) — nunca afirma causa de red sin ella (`# 40`, `# 57`).

## RAC correlation

Delegación a `oracle-rac-analyst` sólo cuando el problema requiere contexto de topología/threads/servicio RAC (`# 16`).

## ASM/storage correlation

Delegación a `oracle-asm-storage-analyst` con evidencia de presión de I/O en apply/destino/SRL — nunca activado por defecto (`# 41`).

## Performance correlation

Delegación a `oracle-performance-analyst` cuando apply lag se correlaciona con CPU/I/O/parallel recovery/redo generation — ese agente aplica su propio Licensing Gate para AWR/ASH (`# 42`).

## Incident integration

`dataguard/incident-analysis` coordina con `incident-root-cause-analyst`, comparte Evidence IDs, nunca transcript completo (`# 44`).

## Healthcheck Data Guard

`/healthcheck dataguard` orquesta `dataguard/healthcheck` — Data Guard Health Model por dimensión (`ROLE, TRANSPORT, APPLY, LAG, GAPS, BROKER, SRL, PROTECTION, FSFO, READINESS`), nunca un score opaco único (`# 45`, `# 46`).

## Assessment Data Guard

`/assessment dataguard` orquesta `dataguard/assessment` — arquitectura, roles, versiones, protección, transporte, apply, lag, gaps, SRL, Broker, FSFO, dependencias cross-domain, riesgos, recomendaciones, readiness (`# 47`).

## Diagnose workflows

`/diagnose` extendido con `dataguard, transport, apply, lag, gap, broker, fsfo, switchover-readiness, failover-readiness` (`# 48`) — sin comando slash por código ORA individual.

## Evidence model

`configuration/database_unique_name (tokenized)/role/instance/thread/sequence/destination/source/time/query_id/collector_id/variant_id/validation_status/sanitization` (`# 51`) — mismos Evidence IDs y trazabilidad `EVD → FND → REC → CHG`.

## Sanitization

`parsers/dataguard/common.py.Sanitizer` — tokenización determinista de `db_unique_name`/`host`/`scan`/`destination`, scrub de IPs. Un leak real de `db_unique_name` sin tokenizar (`observer_state` en `parse_show_fsfo`) fue detectado y corregido durante la construcción de esta fase — ver "Known limitations" abajo.

## Token/context optimization

`context-policy.yaml` declara `top_n` (archived_logs: 20, gaps: 10, destinations: 10) y reglas explícitas de "no full dump" (`no_full_alert_log`, `no_full_dgmgrl_verbose`, `no_unlimited_archived_log_scan`) — resumen por thread, nunca miles de archived logs (`# 79`).

## Capability Matrix

`config/capability-matrix.yaml`/`docs/CAPABILITY_MATRIX.md` actualizados: Data Guard role discovery/physical standby health/transport/apply/lag/archive gaps/SRL `SUPPORTED` 10g–23ai; Broker/FSFO `SUPPORTED`; switchover/failover execution `PROHIBITED`; Active Data Guard `LICENSE_DEPENDENT`; Logical/Snapshot Standby/Far Sync `PARTIALLY_SUPPORTED`.

## Documentation

Nuevos: `docs/PHASE_5_ORACLE_DATAGUARD.md` (este documento), `docs/DATAGUARD_DIAGNOSTIC_MODEL.md`, `docs/DATAGUARD_READONLY_QUERIES.md`, `docs/DATAGUARD_BROKER_READONLY_COLLECTORS.md`, `docs/DATAGUARD_SWITCHOVER_READINESS.md`, `docs/DATAGUARD_FAILOVER_READINESS.md`. Actualizados: `README.md`, `ARCHITECTURE.md`, `SECURITY.md`, `docs/CAPABILITY_MATRIX.md`, `CHANGELOG.md`, `docs/ORACLE_READONLY_PRIVILEGES.md`, `docs/TARGET_PROFILE.md` (schema 2.2.0), `queries/REGISTRY.md`, `skills/REGISTRY.md`, `agents/REGISTRY.md`, `mcp/tool-manifest.md`.

## Security validation

Todos los tests de fases anteriores siguen pasando sin modificación de su lógica. Nuevos: 11 tests Broker, 6 transporte, 7 apply, 4 gap, 6 SRL, 7 readiness, 3 licensing, ~17 seguridad específicos de Fase 5 (switchover/failover/reinstate/broker edit/enable-disable/alter system/archive dest modify/force logging/flashback/recovery start-stop/arbitrary SQL/secrets), 10 query, 4 contrato de agente — todos `PASS` tras corregir varios falsos positivos de negación textual (ver "Known limitations").

## Test results

~80 tests nuevos, todos `PASS`. Ver desglose por categoría arriba.

## Regression results

Ver el reporte de cierre final para el resultado agregado de `tests/run-all.sh` sobre el árbol completo (Foundation → Fase 5), ejecutado después de la construcción completa de esta fase.

## Known limitations

- `LOGICAL_STANDBY`/`SNAPSHOT_STANDBY`/`FAR_SYNC` reconocidos (rol/presencia) pero sin análisis profundo específico — candidatos a `/change query`/`/change skill` en una fase futura si se requiere certificación completa.
- `parsers/dataguard/broker_parser.py` es primera versión funcional, validada contra fixtures propios (`tests/fixtures/broker/`), no contra la diversidad completa de formatos DGMGRL entre versiones (11gR2 vs. 23ai pueden diferir en detalles menores de formato no cubiertos por esta fase).
- Durante la construcción se detectó y corrigió un leak real de `db_unique_name` sin tokenizar en el campo `observer_state` de `parse_show_fsfo` (texto libre "Observing <primary_db_name>") — el campo se eliminó del output (redundante con `observer_status` ya calculado) en vez de intentar un scrubber de texto libre complejo.
- `V$DATAGUARD_STATUS`/`V$RECOVERY_PROGRESS` registradas en el diccionario por completitud del inventario (`# 8`) pero no consultadas por ninguna query certificada activa — candidatas a `/change query` futuro.
- No se implementa RMAN profundo (`# 81`) ni operaciones Multitenant avanzadas (`# 82`) — fuera de alcance explícito de esta fase.
- (Compatibility Hardening) El chequeo de existencia de columna del SQL Static Validator sólo cubre las 9 vistas Data Guard marcadas `columns_exhaustive: true` — no se extendió a vistas de fases anteriores pese a haberse encontrado el mismo patrón de defecto en `V$ASM_DISK` (Fase 4); documentado para un `/change` dedicado, no corregido aquí por alcance.
- (Final Process-View Hardening) `V$DATAGUARD_PROCESS` se registra con un subconjunto de columnas verificadas contra Oracle Database Reference (`name`/`pid`/`type`/`role`/`action`/`client_pid`/`client_role`/`thread#`/`sequence#`/`block#`/`block_count`) — no se certifica el resto de columnas documentadas (`proc_time`/`task_time`/`task_done`/`group#`/`resetlog_id`/`delay_mins`/`dest_id`/`dest_mask`/`dbid`/`dgid`/`instance`/`stop_state`/`con_id`) por no ser usadas por la query actual. Único campo del modelo lógico sin equivalente real: `process_role` en la variante legacy.

## NOT_CERTIFIED queries

Ninguna — las 7 queries del catálogo están certificadas y materializadas.

## NOT_CERTIFIED collectors

Ninguno — los 5 collectors documentados están `FIXTURE_VALIDATED`. Ninguno alcanza `RUNTIME_VALIDATED` (ejecución real es Fase 7, Gateway MCP).

## Manual Action Contract

Todo comando `DGMGRL`/`ALTER DATABASE`/`ALTER SYSTEM` recomendado por `oracle-dataguard-analyst` usa el siguiente esquema (`# 60` del prompt de Fase 5):

```yaml
manual_action:
  action_id: string
  purpose: string
  owner_role: string           # DBA | Grid Administrator | Network Administrator
  command: string
  prechecks: [string]
  expected_result: string
  risk: string
  rollback: string
  postchecks: [string]
  execution_status: NOT_EXECUTED   # nunca EXECUTED
```

Presentado siempre con las etiquetas `MANUAL DBA ACTION` / `NOT EXECUTED` visibles. Ningún agente de esta fase ejecuta el comando — sólo lo genera como texto para revisión y ejecución humana. El Switchover Manual Plan (`docs/DATAGUARD_SWITCHOVER_READINESS.md#switchover-manual-plan`) es una extensión de este mismo contrato para el caso específico de switchover.

## Next phase

Fase 6+ — según el orden de `README.md` (Multitenant profundo, RMAN/backup profundo, Security profundo). Explícitamente fuera de alcance de esta fase.

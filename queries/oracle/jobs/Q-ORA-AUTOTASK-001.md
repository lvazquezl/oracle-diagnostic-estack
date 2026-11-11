---
query_id: Q-ORA-AUTOTASK-001
version: 1.0.0

domain: oracle
purpose: Automated maintenance tasks (estadísticas del optimizer, space advisor, SQL tuning advisor) por contenedor: estado, ventanas habilitadas, ejecuciones y fallas en 7 días y horas desde la última ejecución exitosa

supported_oracle_versions: [11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [DBA_AUTOTASK_CLIENT, DBA_AUTOTASK_WINDOW_CLIENTS, DBA_AUTOTASK_JOB_HISTORY, CDB_AUTOTASK_CLIENT, CDB_AUTOTASK_WINDOW_CLIENTS, CDB_AUTOTASK_JOB_HISTORY]
privileges_required: [SELECT on DBA_AUTOTASK_CLIENT, SELECT on DBA_AUTOTASK_WINDOW_CLIENTS, SELECT on DBA_AUTOTASK_JOB_HISTORY, SELECT on CDB_AUTOTASK_CLIENT, SELECT on CDB_AUTOTASK_WINDOW_CLIENTS, SELECT on CDB_AUTOTASK_JOB_HISTORY]

risk_class: R0
cost_class: LOW

timeout_seconds: 20
max_rows: 100
max_output_bytes: 16384

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-ORA-AUTOTASK-001-V1
    label: autotask_11g
    oracle_versions: {min: "11.1", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (autotask_11g, 11.1–11.2: DBA_AUTOTASK_*)"
  - variant_id: Q-ORA-AUTOTASK-001-V2
    label: cdb_aware_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_12plus, 12.1–23.0: CDB_AUTOTASK_* por contenedor)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_collector_factory.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (autotask_11g, 11.1–11.2: DBA_AUTOTASK_*)

```sql
SELECT CASE c.client_name WHEN 'auto optimizer stats collection' THEN 'AUTO_OPTIMIZER_STATS'
                            WHEN 'auto space advisor' THEN 'AUTO_SPACE_ADVISOR'
                            WHEN 'sql tuning advisor' THEN 'SQL_TUNING_ADVISOR' ELSE 'OTHER' END AS autotask_client,
       c.status AS autotask_status,
       (SELECT COUNT(*) FROM dba_autotask_window_clients w
        WHERE  w.autotask_status = 'ENABLED'
          AND  CASE c.client_name WHEN 'auto optimizer stats collection' THEN w.optimizer_stats
                                         WHEN 'auto space advisor' THEN w.segment_advisor
                                         WHEN 'sql tuning advisor' THEN w.sql_tune_advisor END = 'ENABLED') AS windows_enabled,
       (SELECT COUNT(*) FROM dba_autotask_job_history h
        WHERE  h.client_name = c.client_name
          AND  SYS_EXTRACT_UTC(h.job_start_time) > SYS_EXTRACT_UTC(SYSTIMESTAMP) - 7) AS runs_last_7d,
       (SELECT COUNT(*) FROM dba_autotask_job_history h
        WHERE  h.client_name = c.client_name
          AND  SYS_EXTRACT_UTC(h.job_start_time) > SYS_EXTRACT_UTC(SYSTIMESTAMP) - 7
          AND  h.job_status <> 'SUCCEEDED') AS runs_not_succeeded_7d,
       (SELECT ROUND((CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) - CAST(SYS_EXTRACT_UTC(MAX(h.job_start_time)) AS DATE)) * 24, 1) FROM dba_autotask_job_history h
        WHERE  h.client_name = c.client_name AND h.job_status = 'SUCCEEDED') AS hours_since_last_success
FROM   dba_autotask_client c
ORDER  BY c.client_name;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_12plus, 12.1–23.0: CDB_AUTOTASK_* por contenedor)

```sql
SELECT c.con_id, CASE c.client_name WHEN 'auto optimizer stats collection' THEN 'AUTO_OPTIMIZER_STATS'
                            WHEN 'auto space advisor' THEN 'AUTO_SPACE_ADVISOR'
                            WHEN 'sql tuning advisor' THEN 'SQL_TUNING_ADVISOR' ELSE 'OTHER' END AS autotask_client,
       c.status AS autotask_status,
       (SELECT COUNT(*) FROM cdb_autotask_window_clients w
        WHERE  w.autotask_status = 'ENABLED' AND w.con_id = c.con_id
          AND  CASE c.client_name WHEN 'auto optimizer stats collection' THEN w.optimizer_stats
                                         WHEN 'auto space advisor' THEN w.segment_advisor
                                         WHEN 'sql tuning advisor' THEN w.sql_tune_advisor END = 'ENABLED') AS windows_enabled,
       (SELECT COUNT(*) FROM cdb_autotask_job_history h
        WHERE  h.client_name = c.client_name AND h.con_id = c.con_id
          AND  SYS_EXTRACT_UTC(h.job_start_time) > SYS_EXTRACT_UTC(SYSTIMESTAMP) - 7) AS runs_last_7d,
       (SELECT COUNT(*) FROM cdb_autotask_job_history h
        WHERE  h.client_name = c.client_name AND h.con_id = c.con_id
          AND  SYS_EXTRACT_UTC(h.job_start_time) > SYS_EXTRACT_UTC(SYSTIMESTAMP) - 7
          AND  h.job_status <> 'SUCCEEDED') AS runs_not_succeeded_7d,
       (SELECT ROUND((CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) - CAST(SYS_EXTRACT_UTC(MAX(h.job_start_time)) AS DATE)) * 24, 1) FROM cdb_autotask_job_history h
        WHERE  h.client_name = c.client_name AND h.con_id = c.con_id AND h.job_status = 'SUCCEEDED') AS hours_since_last_success
FROM   cdb_autotask_client c
ORDER  BY c.con_id, c.client_name;
```

# Notes by version

AutoTask existe desde 11.1; en 10g la recolección automática era el job `GATHER_STATS_JOB` del Scheduler (visible en `Q-ORA-SCHEDULER-STATE-001`), y el collector es `UNSUPPORTED`. `DBA_AUTOTASK_JOB_HISTORY` conserva lo que retiene el log del Scheduler (30 días por defecto).

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

12.1+: desde `CDB$ROOT` cada contenedor tiene sus propios clientes y ventanas; una PDB con la recolección de estadísticas deshabilitada queda visible. `windows_enabled` cuenta las ventanas de mantenimiento con AutoTask habilitado que corren ese cliente. `PRIMARY`: en un standby las tareas no corren.

# Cost classification rationale

`LOW` — tres clientes por contenedor y el historial de ejecuciones de 7 días.

# License notes

Ninguna para leer el estado. Ejecutar `sql tuning advisor` (o aceptar sus perfiles) requiere Tuning Pack: su estado se reporta, nunca se asume el derecho de uso.

# Sanitization notes

El cliente sale como palabra cerrada; nombres de ventana, de job, `JOB_ERROR` y fechas absolutas nunca salen: solo estado, conteos y horas.

# Evolution via `/change query`

1.0.0 CHG-ESTACK-C-NEW-QUERIES-001: creación (lote C, cobertura del assessment).

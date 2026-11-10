---
query_id: Q-ORA-SCHEDULER-STATE-001
version: 1.0.0

domain: oracle
purpose: Inventario agregado de jobs del Scheduler y de DBMS_JOB por contenedor, tipo de dueño y estado: cantidad, jobs con fallas, máximo de fallas y peor antigüedad de la última ejecución — incluye deshabilitados y broken

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [DBA_SCHEDULER_JOBS, DBA_JOBS, CDB_SCHEDULER_JOBS, CDB_JOBS, CDB_USERS]
privileges_required: [SELECT on DBA_SCHEDULER_JOBS, SELECT on DBA_JOBS, SELECT on CDB_SCHEDULER_JOBS, SELECT on CDB_JOBS, SELECT on CDB_USERS]

risk_class: R0
cost_class: LOW

timeout_seconds: 20
max_rows: 200
max_output_bytes: 32768

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-ORA-SCHEDULER-STATE-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2: Scheduler y DBA_JOBS, SYS/SYSTEM como Oracle)"
  - variant_id: Q-ORA-SCHEDULER-STATE-001-V2
    label: cdb_12_1_0_1
    oracle_versions: {min: "12.1", max: "12.1.0.1"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_12_1_0_1, 12.1.0.1: por contenedor, SYS/SYSTEM como Oracle)"
  - variant_id: Q-ORA-SCHEDULER-STATE-001-V3
    label: cdb_oracle_maintained
    oracle_versions: {min: "12.1.0.2", max: "18.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V3 (cdb_oracle_maintained, 12.1.0.2–18c: por contenedor con ORACLE_MAINTAINED)"
  - variant_id: Q-ORA-SCHEDULER-STATE-001-V4
    label: scheduler_only_19plus
    oracle_versions: {min: "19.0", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V4 (scheduler_only_19plus, 19c+: solo el Scheduler, que ya incluye los jobs de DBMS_JOB)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_collector_factory.sh, tests/test_no_application_table_access.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2: Scheduler y DBA_JOBS, SYS/SYSTEM como Oracle)

```sql
SELECT job_source, owner_kind, state,
       COUNT(*) AS jobs,
       SUM(CASE WHEN failures > 0 THEN 1 ELSE 0 END) AS jobs_with_failures,
       MAX(failures) AS max_failure_count,
       MAX(hours_since_last_run) AS max_hours_since_last_run
FROM  (SELECT 'SCHEDULER' AS job_source, CASE WHEN j.owner IN ('SYS', 'SYSTEM') THEN 'ORACLE' ELSE 'OTHER' END AS owner_kind, j.state,
              NVL(j.failure_count, 0) AS failures,
              ROUND((CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) - CAST(SYS_EXTRACT_UTC(j.last_start_date) AS DATE)) * 24, 1) AS hours_since_last_run
       FROM   dba_scheduler_jobs j
       UNION  ALL
       SELECT 'LEGACY_JOB', CASE WHEN j.schema_user IN ('SYS', 'SYSTEM') THEN 'ORACLE' ELSE 'OTHER' END,
              CASE WHEN j.broken = 'Y' THEN 'BROKEN' WHEN j.this_date IS NOT NULL THEN 'RUNNING' ELSE 'SCHEDULED' END,
              NVL(j.failures, 0),
              ROUND((SYSDATE - j.last_date) * 24, 1)
       FROM   dba_jobs j)
GROUP  BY job_source, owner_kind, state
ORDER  BY job_source, owner_kind, state;
```

# Statement / procedure (read-only) — Variant V2 (cdb_12_1_0_1, 12.1.0.1: por contenedor, SYS/SYSTEM como Oracle)

```sql
SELECT con_id, job_source, owner_kind, state,
       COUNT(*) AS jobs,
       SUM(CASE WHEN failures > 0 THEN 1 ELSE 0 END) AS jobs_with_failures,
       MAX(failures) AS max_failure_count,
       MAX(hours_since_last_run) AS max_hours_since_last_run
FROM  (SELECT j.con_id, 'SCHEDULER' AS job_source, CASE WHEN j.owner IN ('SYS', 'SYSTEM') THEN 'ORACLE' ELSE 'OTHER' END AS owner_kind, j.state,
              NVL(j.failure_count, 0) AS failures,
              ROUND((CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) - CAST(SYS_EXTRACT_UTC(j.last_start_date) AS DATE)) * 24, 1) AS hours_since_last_run
       FROM   cdb_scheduler_jobs j
       UNION  ALL
       SELECT j.con_id, 'LEGACY_JOB', CASE WHEN j.schema_user IN ('SYS', 'SYSTEM') THEN 'ORACLE' ELSE 'OTHER' END,
              CASE WHEN j.broken = 'Y' THEN 'BROKEN' WHEN j.this_date IS NOT NULL THEN 'RUNNING' ELSE 'SCHEDULED' END,
              NVL(j.failures, 0),
              ROUND((SYSDATE - j.last_date) * 24, 1)
       FROM   cdb_jobs j)
GROUP  BY con_id, job_source, owner_kind, state
ORDER  BY con_id, job_source, owner_kind, state;
```

# Statement / procedure (read-only) — Variant V3 (cdb_oracle_maintained, 12.1.0.2–18c: por contenedor con ORACLE_MAINTAINED)

```sql
SELECT con_id, job_source, owner_kind, state,
       COUNT(*) AS jobs,
       SUM(CASE WHEN failures > 0 THEN 1 ELSE 0 END) AS jobs_with_failures,
       MAX(failures) AS max_failure_count,
       MAX(hours_since_last_run) AS max_hours_since_last_run
FROM  (SELECT j.con_id, 'SCHEDULER' AS job_source, CASE WHEN u.oracle_maintained = 'Y' THEN 'ORACLE' ELSE 'CUSTOM' END AS owner_kind, j.state,
              NVL(j.failure_count, 0) AS failures,
              ROUND((CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) - CAST(SYS_EXTRACT_UTC(j.last_start_date) AS DATE)) * 24, 1) AS hours_since_last_run
       FROM   cdb_scheduler_jobs j
       LEFT   JOIN cdb_users u ON u.con_id = j.con_id AND u.username = j.owner
       UNION  ALL
       SELECT j.con_id, 'LEGACY_JOB', CASE WHEN u.oracle_maintained = 'Y' THEN 'ORACLE' ELSE 'CUSTOM' END,
              CASE WHEN j.broken = 'Y' THEN 'BROKEN' WHEN j.this_date IS NOT NULL THEN 'RUNNING' ELSE 'SCHEDULED' END,
              NVL(j.failures, 0),
              ROUND((SYSDATE - j.last_date) * 24, 1)
       FROM   cdb_jobs j
       LEFT   JOIN cdb_users u ON u.con_id = j.con_id AND u.username = j.schema_user)
GROUP  BY con_id, job_source, owner_kind, state
ORDER  BY con_id, job_source, owner_kind, state;
```

# Statement / procedure (read-only) — Variant V4 (scheduler_only_19plus, 19c+: solo el Scheduler, que ya incluye los jobs de DBMS_JOB)

```sql
SELECT con_id, job_source, owner_kind, state,
       COUNT(*) AS jobs,
       SUM(CASE WHEN failures > 0 THEN 1 ELSE 0 END) AS jobs_with_failures,
       MAX(failures) AS max_failure_count,
       MAX(hours_since_last_run) AS max_hours_since_last_run
FROM  (SELECT j.con_id, 'SCHEDULER' AS job_source, CASE WHEN u.oracle_maintained = 'Y' THEN 'ORACLE' ELSE 'CUSTOM' END AS owner_kind, j.state,
              NVL(j.failure_count, 0) AS failures,
              ROUND((CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) - CAST(SYS_EXTRACT_UTC(j.last_start_date) AS DATE)) * 24, 1) AS hours_since_last_run
       FROM   cdb_scheduler_jobs j
       LEFT   JOIN cdb_users u ON u.con_id = j.con_id AND u.username = j.owner)
GROUP  BY con_id, job_source, owner_kind, state
ORDER  BY con_id, job_source, owner_kind, state;
```

# Notes by version

Desde 19c los jobs de `DBMS_JOB` se implementan como jobs del Scheduler y aparecen en `DBA_SCHEDULER_JOBS` y en `DBA_JOBS`: V4 lee solo el Scheduler para no contarlos dos veces (salen como `SCHEDULER`). Hasta 18c, V1–V3 suman `DBA_JOBS` como `LEGACY_JOB`. `ORACLE_MAINTAINED` desde 12.1.0.2; antes solo `SYS` y `SYSTEM` son `ORACLE` y el resto `OTHER`.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

12.1+: `CDB_SCHEDULER_JOBS` y `CDB_JOBS` desde `CDB$ROOT` cubren cada contenedor. Para `LEGACY_JOB`, `state` es `BROKEN`, `RUNNING` (`THIS_DATE` no nulo) o `SCHEDULED`, y las horas son desde la última ejecución exitosa (`LAST_DATE`); para el Scheduler, desde el último inicio. Complementa a `Q-ORA-JOBS-SUMMARY-001`, que lista los jobs con fallas.

# Cost classification rationale

`LOW` — una fila por job antes de agregar (cientos en una base típica).

# License notes

Ninguna.

# Sanitization notes

Nombres de job, dueño, `JOB_ACTION`/`WHAT` (código PL/SQL), `INTERVAL` y fechas absolutas nunca salen: solo origen, tipo de dueño, estado, conteos y horas.

# Evolution via `/change query`

1.0.0 CHG-ESTACK-C-NEW-QUERIES-001: creación (lote C, cobertura del assessment). Implementa la lectura de `DBA_JOBS` que quedó PLANNED en `Q-ORA-JOBS-SUMMARY-001`.

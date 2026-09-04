---
query_id: Q-PERF-TOPSQL-001
version: 1.0.0

domain: performance
purpose: Top SQL por elapsed/CPU/reads/gets/executions sobre una ventana AWR

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [DBA_HIST_SQLSTAT, DBA_HIST_SNAPSHOT]
privileges_required: [SELECT on DBA_HIST_SQLSTAT, SELECT on DBA_HIST_SNAPSHOT]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 60
max_rows: 100
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true

license_requirements: [Diagnostics Pack]

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_medium.sh, tests/test_awr_top_sql.sh, tests/test_awr_no_sql_text_by_default.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT q.sql_id,
       q.plan_hash_value,
       SUM(q.executions_delta)                                              AS executions,
       SUM(q.elapsed_time_delta) / 1e6                                       AS elapsed_sec,
       SUM(q.cpu_time_delta) / 1e6                                           AS cpu_sec,
       SUM(q.buffer_gets_delta)                                              AS buffer_gets,
       SUM(q.disk_reads_delta)                                               AS disk_reads,
       SUM(q.rows_processed_delta)                                          AS rows_processed
FROM   dba_hist_sqlstat q
JOIN   dba_hist_snapshot s
       ON  s.snap_id = q.snap_id
       AND s.instance_number = q.instance_number
WHERE  s.end_interval_time BETWEEN :window_start AND :window_end
GROUP  BY q.sql_id, q.plan_hash_value
ORDER  BY elapsed_sec DESC
FETCH FIRST 20 ROWS ONLY;                 -- 12c+; usar ROWNUM <= 20 en 10g/11g
```

Nunca selecciona `SQL_TEXT`/`SQL_FULLTEXT` por defecto (ver `docs/PHASE_3_ORACLE_PERFORMANCE.md#sql-text-policy`) — sólo `SQL_ID` + `PLAN_HASH_VALUE` + métricas agregadas. El agente ordena por `elapsed_sec`/`cpu_sec`/`disk_reads`/`buffer_gets`/`executions` según qué skill lo invoque (`performance/sql-elapsed`, `performance/sql-cpu`, `performance/sql-io`, `performance/sql-executions` reutilizan esta misma query, cambiando sólo el `ORDER BY` en el Task Package — no son variantes SQL distintas, es la misma evidencia ordenada distinto).

# Notes by version

`DBA_HIST_SQLSTAT` disponible desde 10g. `PLAN_HASH_VALUE` presente en todas las versiones del rango. Sin diferencias estructurales relevantes.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`ANY_CONTAINER` — ver razonamiento de `Q-PERF-WAIT-AWR-001`. `database_role_scope: PRIMARY` — actividad SQL de usuario, mínima en standby en mount.

# License notes

Diagnostics Pack. Sin confirmación, cae a `Q-PERF-TOPSQL-CURRENT-001` (`V$SQL`/`V$SQLSTATS`, cumulativo desde parse, sin licencia).

# Sanitization notes

`sql_id`/`plan_hash_value` → KEEP (no son SQL text). Ninguna columna de esta query expone bind values ni SQL text — ver `# 10. SQL TEXT POLICY` en `docs/PHASE_3_ORACLE_PERFORMANCE.md`.

# Evolution via `/change query`

Habilitar `SQL_TEXT`/`SQL_FULLTEXT` sólo mediante `/change policy` explícito con sanitización adicional — nunca por defecto.

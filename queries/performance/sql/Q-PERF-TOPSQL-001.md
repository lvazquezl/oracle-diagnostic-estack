---
query_id: Q-PERF-TOPSQL-001
version: 1.1.0

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

variants:
  - variant_id: Q-PERF-TOPSQL-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10g-11g)"
  - variant_id: Q-PERF-TOPSQL-001-V2
    label: modern_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_12plus, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_medium.sh, tests/test_awr_top_sql.sh, tests/test_awr_no_sql_text_by_default.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10g-11g)

```sql
SELECT *
FROM (
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
)
WHERE  ROWNUM <= 20;
```

# Statement / procedure (read-only) — Variant V2 (modern_12plus, 12.1+)

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
FETCH  FIRST 20 ROWS ONLY;
```

Nunca selecciona `SQL_TEXT`/`SQL_FULLTEXT` por defecto (ver `docs/PHASE_3_ORACLE_PERFORMANCE.md#sql-text-policy`) — sólo `SQL_ID` + `PLAN_HASH_VALUE` + métricas agregadas. El agente ordena por `elapsed_sec`/`cpu_sec`/`disk_reads`/`buffer_gets`/`executions` según qué skill lo invoque (`performance/sql-elapsed`, `performance/sql-cpu`, `performance/sql-io`, `performance/sql-executions` reutilizan esta misma query, cambiando sólo el `ORDER BY` en el Task Package — no son variantes SQL distintas, es la misma evidencia ordenada distinto).

# Notes by version

`DBA_HIST_SQLSTAT` disponible desde 10g. `PLAN_HASH_VALUE` presente en todas las versiones del rango. Sin diferencias estructurales relevantes.

**PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING**: mismo defecto/corrección que `Q-PERF-BLOCKING-001` — `FETCH FIRST` con `min_version` 10.2 sin variante legacy real, detectado por `tests/test_no_fetch_first_in_pre12c_queries.sh`. El bind `:window_start`/`:window_end` se preserva idéntico en ambas variantes.

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

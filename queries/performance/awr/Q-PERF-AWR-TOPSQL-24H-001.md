---
query_id: Q-PERF-AWR-TOPSQL-24H-001
version: 1.0.0

domain: performance
purpose: Top 20 SQL por tiempo de las últimas 24 h según AWR (sql_id y métricas, nunca texto SQL)

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [DBA_HIST_SQLSTAT, DBA_HIST_SNAPSHOT]
privileges_required: [SELECT on DBA_HIST_SQLSTAT, SELECT on DBA_HIST_SNAPSHOT]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 20
max_rows: 20
max_output_bytes: 32768

sensitivity: LOW
sanitization_required: true

license_requirements: [Diagnostics Pack]

execution_mode: READ_ONLY

variants:
  - variant_id: Q-PERF-AWR-TOPSQL-24H-001-V1
    label: legacy_rownum
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_rownum, 10.2–11.2)"
  - variant_id: Q-PERF-AWR-TOPSQL-24H-001-V2
    label: modern_fetch_first
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_fetch_first, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_every_logical_query_has_variant.sh, tests/test_collector_factory.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_rownum, 10.2–11.2)

```sql
SELECT *
FROM  (SELECT q.sql_id, q.plan_hash_value,
              SUM(q.executions_delta)                 AS executions,
              ROUND(SUM(q.elapsed_time_delta) / 1e6, 3) AS elapsed_sec,
              ROUND(SUM(q.cpu_time_delta) / 1e6, 3)     AS cpu_sec,
              SUM(q.buffer_gets_delta)                AS buffer_gets,
              SUM(q.disk_reads_delta)                 AS disk_reads,
              SUM(q.rows_processed_delta)             AS rows_processed
       FROM   dba_hist_sqlstat q
       JOIN   dba_hist_snapshot s
              ON  s.dbid = q.dbid AND s.snap_id = q.snap_id AND s.instance_number = q.instance_number
       WHERE  s.end_interval_time >= SYSTIMESTAMP - INTERVAL '1' DAY
       GROUP  BY q.sql_id, q.plan_hash_value
       ORDER  BY SUM(q.elapsed_time_delta) DESC)
WHERE  ROWNUM <= 20;
```

# Statement / procedure (read-only) — Variant V2 (modern_fetch_first, 12.1+)

```sql
SELECT q.con_id, q.sql_id, q.plan_hash_value,
       SUM(q.executions_delta)                 AS executions,
       ROUND(SUM(q.elapsed_time_delta) / 1e6, 3) AS elapsed_sec,
       ROUND(SUM(q.cpu_time_delta) / 1e6, 3)     AS cpu_sec,
       SUM(q.buffer_gets_delta)                AS buffer_gets,
       SUM(q.disk_reads_delta)                 AS disk_reads,
       SUM(q.rows_processed_delta)             AS rows_processed
FROM   dba_hist_sqlstat q
JOIN   dba_hist_snapshot s
       ON  s.dbid = q.dbid AND s.snap_id = q.snap_id AND s.instance_number = q.instance_number
WHERE  s.end_interval_time >= SYSTIMESTAMP - INTERVAL '1' DAY
GROUP  BY q.con_id, q.sql_id, q.plan_hash_value
ORDER  BY SUM(q.elapsed_time_delta) DESC
FETCH  FIRST 20 ROWS ONLY;
```

Usa las columnas `*_DELTA` de `DBA_HIST_SQLSTAT` (ya son deltas por intervalo). V2 agrega `con_id` (en un CDB el mismo `sql_id` aparece por contenedor). Complementa `Q-PERF-TOPSQL-CURRENT-001` (acumulado del shared pool) con la ventana de 24 h.

# Notes by version

`DBA_HIST_SQLSTAT` con columnas `*_DELTA` desde 10g; `CON_ID` y `FETCH FIRST` desde 12.1 (V2).

# Notes by platform

Ninguna diferencia.

# Container / role scope notes

`ANY_CONTAINER`: desde `CDB$ROOT` AWR describe la instancia completa. `PRIMARY`: en un standby no se generan snapshots AWR locales (salvo configuración remota de AWR).

# Cost classification rationale

`MEDIUM`: lee snapshots AWR de una ventana fija (24 h) o ASH en memoria (60 min), agrega en la base y acota filas.

# License notes

**Requiere Oracle Diagnostics Pack.** El gateway sólo la ejecuta si el target declara `license_status.diagnostics_pack = CONFIRMED` (confirmación humana del contrato; `CONTROL_MANAGEMENT_PACK_ACCESS` no prueba la licencia). En la ruta humana exige `--license-confirmed diagnostics_pack --confirmed-by <revisor>`.

# Sanitization notes

`sql_id` → KEEP (tipo `sql_id`, nunca texto SQL); números → KEEP.

# Evolution via `/change query`

CHG-ESTACK-AWR-LICENSED-001 — creada para el lote B4 (AWR/ASH con ventana fija, sin binds).

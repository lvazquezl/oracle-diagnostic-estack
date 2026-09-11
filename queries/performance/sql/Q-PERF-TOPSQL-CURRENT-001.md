---
query_id: Q-PERF-TOPSQL-CURRENT-001
version: 1.1.0

domain: performance
purpose: Top SQL por métricas acumuladas desde el parse — ruta estándar sin Diagnostics Pack

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$SQLSTATS]
privileges_required: [SELECT on V$SQLSTATS]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 30
max_rows: 100
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-PERF-TOPSQL-CURRENT-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10g-11g)"
  - variant_id: Q-PERF-TOPSQL-CURRENT-001-V2
    label: modern_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_12plus, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_medium.sh, tests/test_performance_without_diagnostic_pack.sh, tests/test_standard_path_top_sql_metrics.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10g-11g)

```sql
SELECT *
FROM (
  SELECT s.sql_id,
         s.plan_hash_value,
         s.executions,
         s.elapsed_time / 1e6      AS elapsed_sec,
         s.cpu_time / 1e6          AS cpu_sec,
         s.buffer_gets,
         s.disk_reads,
         s.rows_processed
  FROM   v$sqlstats s
  WHERE  s.executions > 0
  ORDER  BY elapsed_sec DESC
)
WHERE  ROWNUM <= 20;
```

# Statement / procedure (read-only) — Variant V2 (modern_12plus, 12.1+)

```sql
SELECT s.sql_id,
       s.plan_hash_value,
       s.executions,
       s.elapsed_time / 1e6      AS elapsed_sec,
       s.cpu_time / 1e6          AS cpu_sec,
       s.buffer_gets,
       s.disk_reads,
       s.rows_processed
FROM   v$sqlstats s
WHERE  s.executions > 0
ORDER  BY elapsed_sec DESC
FETCH  FIRST 20 ROWS ONLY;
```

`V$SQLSTATS` acumula desde que el cursor fue parseado por primera vez (sobrevive a la salida de `V$SQL` del shared pool a diferencia de `V$SQL`, por eso se prefiere aquí); no tiene ventana temporal explícita — refleja "desde que este SQL_ID existe en memoria", no una ventana comparable a AWR/Statspack. El agente lo declara así al reportar el hallazgo (`time_window: "cumulative_since_parse"`, no una ventana solicitada por el DBA).

# Notes by version

`V$SQLSTATS` disponible desde 10g. Sin diferencias estructurales relevantes 10g–23ai en las columnas usadas aquí.

**PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING**: mismo defecto/corrección que `Q-PERF-BLOCKING-001` — `FETCH FIRST` con `min_version` 10.2 sin variante legacy real, detectado por `tests/test_no_fetch_first_in_pre12c_queries.sh`.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`ANY_CONTAINER` — vista dinámica de instancia. `database_role_scope: PRIMARY` — igual razón que el resto del catálogo `performance/sql/*`.

# License notes

Ninguna — esta es explícitamente la alternativa no licenciada a `Q-PERF-TOPSQL-001`.

# Sanitization notes

`sql_id`/`plan_hash_value` → KEEP. Nunca selecciona `SQL_TEXT`/`SQL_FULLTEXT` de `V$SQLSTATS` por defecto — misma política que `Q-PERF-TOPSQL-001`.

# Evolution via `/change query`

Ninguno previsto.

---
query_id: Q-PERF-PLAN-HIST-001
version: 1.0.0

domain: performance
purpose: Historial de PLAN_HASH_VALUE por SQL_ID sobre una ventana AWR, para detección de plan regression

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [DBA_HIST_SQLSTAT, DBA_HIST_SNAPSHOT]
privileges_required: [SELECT on DBA_HIST_SQLSTAT, SELECT on DBA_HIST_SNAPSHOT]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 30
max_rows: 100
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: true

license_requirements: [Diagnostics Pack]

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_medium.sh, tests/test_plan_regression.sh, tests/test_multiple_plan_hashes.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT q.sql_id,
       q.plan_hash_value,
       MIN(s.begin_interval_time)   AS first_seen,
       MAX(s.end_interval_time)     AS last_seen,
       SUM(q.executions_delta)      AS executions,
       SUM(q.elapsed_time_delta) / NULLIF(SUM(q.executions_delta), 0) / 1e6 AS elapsed_per_exec_sec
FROM   dba_hist_sqlstat q
JOIN   dba_hist_snapshot s
       ON  s.snap_id = q.snap_id
       AND s.instance_number = q.instance_number
WHERE  q.sql_id = :sql_id
  AND  s.end_interval_time BETWEEN :window_start AND :window_end
GROUP  BY q.sql_id, q.plan_hash_value
ORDER  BY first_seen;
```

Se invoca con un `sql_id` específico (típicamente uno ya identificado como relevante por `Q-PERF-TOPSQL-001`), no de forma exploratoria sobre todo el catálogo — mantiene el costo acotado. Si la agrupación devuelve más de un `plan_hash_value` distinto para el mismo `sql_id` en la ventana, es la señal de entrada para `performance/plan-regression`.

# Notes by version

`DBA_HIST_SQLSTAT` disponible desde 10g — sin diferencias estructurales relevantes para las columnas usadas aquí.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`ANY_CONTAINER` — ver razonamiento de `Q-PERF-WAIT-AWR-001`. `database_role_scope: PRIMARY`.

# License notes

Diagnostics Pack. Sin AWR histórico no hay forma confiable de reconstruir el historial de `plan_hash_value` en el tiempo — sin fallback no licenciado; el hallazgo de plan regression queda `LICENSE_RESTRICTED` si no hay AWR disponible (a diferencia de wait events/top SQL, que sí tienen ruta estándar).

# Sanitization notes

Todos los campos → KEEP (agregados numéricos y `sql_id`/`plan_hash_value`, no SQL text).

# Evolution via `/change query`

Ninguno previsto.

---
query_id: Q-PERF-SHAREDPOOL-001
version: 1.0.0

domain: performance
purpose: Distribución de memoria libre/usada dentro del shared pool y row cache (dictionary cache) hit ratio

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$SGASTAT, V$ROWCACHE]
privileges_required: [SELECT on V$SGASTAT, SELECT on V$ROWCACHE]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 30
max_output_bytes: 8192

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_low.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT (SELECT bytes FROM v$sgastat WHERE pool = 'shared pool' AND name = 'free memory')          AS shared_pool_free_bytes,
       (SELECT SUM(bytes) FROM v$sgastat WHERE pool = 'shared pool')                                AS shared_pool_total_bytes,
       (SELECT SUM(gets) FROM v$rowcache)                                                            AS rowcache_gets,
       (SELECT SUM(getmisses) FROM v$rowcache)                                                       AS rowcache_getmisses,
       ROUND(1 - (SELECT SUM(getmisses) FROM v$rowcache) / NULLIF((SELECT SUM(gets) FROM v$rowcache), 0), 4) AS rowcache_hit_ratio
FROM   dual;
```

# Notes by version

`V$SGASTAT`/`V$ROWCACHE` estables 10g–23ai en las columnas usadas.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`ANY_CONTAINER`. `database_role_scope: ANY` — estructural.

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP.

# Evolution via `/change query`

Ninguno previsto.

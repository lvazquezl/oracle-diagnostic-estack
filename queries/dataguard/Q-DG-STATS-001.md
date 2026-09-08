---
query_id: Q-DG-STATS-001
version: 1.0.0

domain: dataguard
purpose: Transport lag y apply lag — dos métricas distintas, nunca sinónimos (# 13, # 56, # 57 del prompt de Fase 5)

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: STANDBY

objects_accessed: [V$DATAGUARD_STATS]
privileges_required: [SELECT on V$DATAGUARD_STATS]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 20
max_output_bytes: 8192

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_dataguard_stats_query.sh, tests/test_transport_lag.sh, tests/test_apply_lag.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT name, value, unit
FROM   v$dataguard_stats
WHERE  name IN ('transport lag', 'apply lag');
```

Se filtran explícitamente a las dos métricas relevantes — nunca `SELECT *` sobre la vista completa, que incluye otras métricas no usadas por el catálogo actual.

# Notes by version

`V$DATAGUARD_STATS` disponible desde 10g. Las filas `transport lag`/`apply lag` con ese nombre exacto estables desde 11g; en 10g el nombre de métrica puede variar levemente por patch — el skill trata cualquier discrepancia de nombre como `UNKNOWN` en vez de asumir un mapeo no verificado.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`. `database_role_scope: STANDBY` — el lag sólo tiene sentido medido desde el standby.

# Cost classification rationale

`LOW` — 2 filas de una vista ya agregada por Oracle.

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP (métricas agregadas, no identifican datos de aplicación).

# Evolution via `/change query`

Ampliar a otras métricas de `V$DATAGUARD_STATS` (ej. `estimated startup time`) vía `/change query` cuando un skill lo requiera explícitamente.

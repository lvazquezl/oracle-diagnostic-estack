---
query_id: Q-PERF-LIBCACHE-001
version: 1.0.0

domain: performance
purpose: Reloads, invalidaciones y gethit ratio de Library Cache por namespace

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$LIBRARYCACHE]
privileges_required: [SELECT on V$LIBRARYCACHE]

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
SELECT namespace,
       gets,
       gethits,
       ROUND(gethitratio, 4)  AS gethitratio,
       pins,
       pinhits,
       ROUND(pinhitratio, 4)  AS pinhitratio,
       reloads,
       invalidations
FROM   v$librarycache
ORDER  BY reloads DESC;
```

# Notes by version

`V$LIBRARYCACHE` estable 10g–23ai en las columnas usadas.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`ANY_CONTAINER` — library cache es de instancia. `database_role_scope: ANY` — estructural, válido en Primary y Standby.

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP.

# Evolution via `/change query`

Ninguno previsto.

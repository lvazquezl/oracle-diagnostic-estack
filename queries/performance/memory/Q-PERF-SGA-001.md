---
query_id: Q-PERF-SGA-001
version: 1.0.0

domain: performance
purpose: Tamaño y componentes actuales de la SGA

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$SGA, V$SGAINFO, V$SGASTAT]
privileges_required: [SELECT on V$SGA, SELECT on V$SGAINFO, SELECT on V$SGASTAT]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 50
max_output_bytes: 16384

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_low.sh, tests/test_sga_version_awareness.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT (SELECT SUM(value) FROM v$sga)                                              AS sga_total_bytes,
       (SELECT bytes FROM v$sgainfo WHERE name = 'Maximum SGA Size')                AS sga_max_bytes,
       (SELECT bytes FROM v$sgainfo WHERE name = 'Free SGA Memory Available')       AS sga_free_bytes,
       (SELECT SUM(bytes) FROM v$sgastat WHERE pool = 'shared pool')                AS shared_pool_bytes,
       (SELECT SUM(bytes) FROM v$sgastat WHERE name = 'buffer_cache')               AS buffer_cache_bytes,
       (SELECT SUM(bytes) FROM v$sgastat WHERE pool = 'large pool')                 AS large_pool_bytes,
       (SELECT SUM(bytes) FROM v$sgastat WHERE pool = 'java pool')                  AS java_pool_bytes
FROM   dual;
```

# Notes by version

`V$SGA`/`V$SGASTAT` disponibles en toda la ventana declarada. `V$SGAINFO` disponible desde 9i, sin cambios relevantes 10g–23ai. `streams pool` (cuando existe) se lee vía `V$SGASTAT` con `pool = 'streams pool'` — no incluido en el SELECT base para mantener la query acotada; el skill lo agrega opcionalmente cuando `streams_pool_size` > 0 en `V$PARAMETER`.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`ANY_CONTAINER` — la SGA es de instancia, no `CON_ID`-scoped. `database_role_scope: ANY` — la configuración/asignación de memoria es válida de leer tanto en Primary como en Standby (a diferencia de las queries de actividad, esto es estructural).

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP (tamaños en bytes, sin datos de aplicación).

# Evolution via `/change query`

Agregar `streams pool`/componentes adicionales vía `/change query` si un skill lo requiere de forma sistemática.

---
query_id: Q-PERF-PGA-001
version: 1.0.0

domain: performance
purpose: Uso, workareas y over-allocation de PGA agregada

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$PGASTAT]
privileges_required: [SELECT on V$PGASTAT]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 30
max_output_bytes: 8192

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_low.sh, tests/test_pga_version_awareness.sh, tests/test_pga_limit_not_used_before_supported_version.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT MAX(DECODE(name, 'aggregate PGA target parameter', value))       AS pga_aggregate_target,
       MAX(DECODE(name, 'total PGA inuse', value))                      AS total_pga_inuse,
       MAX(DECODE(name, 'total PGA allocated', value))                  AS total_pga_allocated,
       MAX(DECODE(name, 'over allocation count', value))                AS over_allocation_count,
       MAX(DECODE(name, 'total freeable PGA memory', value))            AS freeable_pga
FROM   v$pgastat
WHERE  name IN ('aggregate PGA target parameter', 'total PGA inuse', 'total PGA allocated',
                'over allocation count', 'total freeable PGA memory');
```

`PGA_AGGREGATE_LIMIT` (parámetro 12c+) se lee por separado desde `V$PARAMETER` (`name = 'pga_aggregate_limit'`) por el skill, nunca asumiendo su existencia en el `SELECT` base — filtrar `V$PGASTAT`/`V$PARAMETER` por `name` string no produce error si la fila no existe en una versión donde el parámetro no aplica (a diferencia de referenciar una columna inexistente), por lo que esta query es segura sin necesidad de variantes por versión — ver `docs/QUERY_VARIANTS.md`. `workarea executions - optimal/onepass/multipass` se leen igual, vía `V$SQL_WORKAREA_HISTOGRAM` en el skill cuando se requiere ese desglose (fuera de esta query base).

# Notes by version

`V$PGASTAT` disponible desde 9i. `PGA_AGGREGATE_LIMIT` (como parámetro, no como fila de `V$PGASTAT`) sólo existe desde 12.1 — el skill `performance/pga` declara explícitamente `NOT_APPLICABLE` para ese campo en 10g/11g, nunca inventa un valor.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`ANY_CONTAINER` — PGA es de instancia. `database_role_scope: ANY` — configuración/uso de PGA es válida de leer en Primary y Standby.

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP.

# Evolution via `/change query`

Agregar `V$SQL_WORKAREA_HISTOGRAM` (onepass/multipass) como query separada vía `/change query` si `performance/pga` lo requiere de forma sistemática en vez de sólo cuando el DBA lo pida.

---
query_id: Q-PERF-PLAN-001
version: 1.0.0

domain: performance
purpose: Plan de ejecución actual (shared pool) de un SQL_ID específico

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$SQL_PLAN]
privileges_required: [SELECT on V$SQL_PLAN]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 200
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_low.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT p.id,
       p.parent_id,
       p.operation,
       p.options,
       p.object_name,
       p.object_type,
       p.cardinality,
       p.cost,
       p.access_predicates,
       p.filter_predicates
FROM   v$sql_plan p
WHERE  p.sql_id = :sql_id
  AND  p.plan_hash_value = :plan_hash_value
ORDER  BY p.id;
```

Predicados (`access_predicates`/`filter_predicates`) pueden contener literales de la aplicación si el SQL no usa bind variables — se enmascaran por política de sanitización antes de exponerse al modelo (ver `# Sanitization notes`), nunca se envían crudos.

# Notes by version

`V$SQL_PLAN` disponible desde 10g. Columnas de operaciones paralelas (`PX_*`, `distribution`) presentes en toda la ventana declarada, sin gate de versión adicional para las columnas usadas aquí.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`ANY_CONTAINER` — vista dinámica de shared pool, no restringida a `CDB$ROOT`. `database_role_scope: PRIMARY` — el shared pool de un standby refleja su propia actividad de apply/lectura, no comparable 1:1 al plan de un SQL de aplicación en primary; se declara explícitamente si se consulta en standby.

# License notes

Ninguna.

# Sanitization notes

`access_predicates`/`filter_predicates` → MASK si contienen literales que parecen valores de aplicación (heurística de `sanitizers/data-classification-policy.md`); `operation`/`options`/`object_name`/`object_type`/`cardinality`/`cost` → KEEP.

# Evolution via `/change query`

Ninguno previsto.

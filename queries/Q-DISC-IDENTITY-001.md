---
query_id: Q-DISC-IDENTITY-001
version: 2.0.0

domain: oracle
purpose: Identificar versión, edición y rol de la base de datos

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$INSTANCE, V$DATABASE]
privileges_required: [SELECT on V$INSTANCE, SELECT on V$DATABASE]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 5
max_output_bytes: 4096

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_version_awareness.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT i.instance_name,
       i.version_full,           -- 19c+: version_full; 10g-18c: usar i.version
       d.name          AS db_name,
       d.database_role,
       d.cdb,
       d.open_mode
FROM   v$instance i, v$database d;
```

# Notes by version

- `V$INSTANCE.VERSION_FULL` sólo existe desde 18c; en 10g–12c usar `V$INSTANCE.VERSION`.
- `V$DATABASE.CDB` sólo existe desde 12c; en versiones anteriores se asume `NO` (NON-CDB) sin necesidad de leer la columna.

# Notes by platform

Ninguna diferencia — es una query SQL pura, no depende del OS.

# Sanitization notes

`db_name` → MASK por defecto (puede revelar nombre de cliente/aplicación); `instance_name` → MASK; `version_full`/`database_role`/`cdb`/`open_mode` → KEEP (no sensibles).

# Evolution via `/change query`

Cambios de columnas por nueva versión Oracle vía `/change compatibility`.

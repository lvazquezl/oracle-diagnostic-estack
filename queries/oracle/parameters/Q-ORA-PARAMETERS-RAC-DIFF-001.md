---
query_id: Q-ORA-PARAMETERS-RAC-DIFF-001
version: 1.0.0
domain: oracle
purpose: Parámetros divergentes entre instancias RAC

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [rac]
container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [GV$PARAMETER]
privileges_required: [SELECT on GV$PARAMETER]

risk_class: R0
cost_class: MEDIUM
timeout_seconds: 30
max_rows: 1000
max_output_bytes: 262144

sensitivity: MEDIUM
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_rac_standalone_detection.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT name, COUNT(DISTINCT value) AS distinct_values, COUNT(*) AS instance_count
FROM   gv$parameter
GROUP  BY name
HAVING COUNT(DISTINCT value) > 1
ORDER  BY name;
```

# Notes by version

Sin diferencias estructurales relevantes.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`MEDIUM`: agregación sobre `GV$` cruzando todas las instancias — escala con `número_de_parámetros × número_de_instancias`.

# License notes

Ninguna.

# Sanitization notes

`value` → condicional según el parámetro; `name` → KEEP.

# Evolution via `/change query`

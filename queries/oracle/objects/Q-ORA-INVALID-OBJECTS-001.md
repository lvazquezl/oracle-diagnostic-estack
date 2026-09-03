---
query_id: Q-ORA-INVALID-OBJECTS-001
version: 1.0.0
domain: oracle
purpose: Objetos inválidos por owner/tipo, priorizando schemas de sistema

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_OBJECTS]
privileges_required: [SELECT on DBA_OBJECTS]

risk_class: R0
cost_class: LOW
timeout_seconds: 20
max_rows: 500
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT owner, object_type, object_name,
       CASE WHEN owner IN ('SYS','SYSTEM') THEN 'SYSTEM' ELSE 'APPLICATION' END AS category
FROM   dba_objects
WHERE  status = 'INVALID'
ORDER  BY category, owner, object_type;
```

# Notes by version

Sin diferencias estructurales relevantes.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW`: el conjunto de objetos inválidos es típicamente pequeño respecto al total de `DBA_OBJECTS`.

# License notes

Ninguna.

# Sanitization notes

`owner`/`object_name` → MASK por defecto salvo que sea `SYS`/`SYSTEM` (nombres de sistema, no sensibles).

# Evolution via `/change query`

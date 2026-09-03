---
query_id: Q-ORA-RESOURCE-LIMITS-001
version: 1.0.0
domain: oracle
purpose: Uso pico vs. límite de recursos de instancia (processes, sessions, open_cursors, ...)

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [V$RESOURCE_LIMIT]
privileges_required: [SELECT on V$RESOURCE_LIMIT]

risk_class: R0
cost_class: LOW
timeout_seconds: 10
max_rows: 50
max_output_bytes: 16384

sensitivity: LOW
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT resource_name, current_utilization, max_utilization, limit_value
FROM   v$resource_limit
WHERE  resource_name IN ('processes','sessions','open_cursors','enqueue_locks','dml_locks')
ORDER  BY resource_name;
```

# Notes by version

`V$RESOURCE_LIMIT` estable desde 9i.

# Notes by platform

Ninguna.

# Container / role scope notes

Límites de instancia física — `NOT_APPLICABLE` a tenancy.

# Cost classification rationale

`LOW`: vista pequeña, diseñada exactamente para este propósito.

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP.

# Evolution via `/change query`

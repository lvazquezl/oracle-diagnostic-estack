---
query_id: Q-ORA-PROCESSES-SUMMARY-001
version: 1.0.0
domain: oracle
purpose: Resumen de procesos Oracle vs. límite configurado

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [V$PROCESS, V$PARAMETER]
privileges_required: [SELECT on V$PROCESS, SELECT on V$PARAMETER]

risk_class: R0
cost_class: LOW
timeout_seconds: 10
max_rows: 5
max_output_bytes: 4096

sensitivity: LOW
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT (SELECT COUNT(*) FROM v$process) AS process_count,
       (SELECT value FROM v$parameter WHERE name='processes') AS processes_limit;
```

# Notes by version

Sin diferencias estructurales relevantes.

# Notes by platform

Ninguna — el modelo de proceso subyacente (proceso OS vs. thread) no afecta esta query.

# Container / role scope notes

Procesos son de instancia física — `NOT_APPLICABLE`.

# Cost classification rationale

`LOW`: dos subqueries de una sola fila.

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP.

# Evolution via `/change query`

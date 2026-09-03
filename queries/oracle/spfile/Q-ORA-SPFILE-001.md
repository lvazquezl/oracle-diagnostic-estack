---
query_id: Q-ORA-SPFILE-001
version: 1.0.0
domain: oracle
purpose: Existencia de SPFILE y parámetros modificados en memoria sin persistir

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [V$SPPARAMETER, V$PARAMETER]
privileges_required: [SELECT on V$SPPARAMETER, SELECT on V$PARAMETER]

risk_class: R0
cost_class: LOW
timeout_seconds: 10
max_rows: 500
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT (SELECT COUNT(*) FROM v$spparameter WHERE value IS NOT NULL) AS spfile_params_count,
       p.name, p.value, p.ismodified
FROM   v$parameter p
WHERE  p.ismodified = 'MODIFIED';
```

Si `spfile_params_count = 0`, no hay SPFILE en uso (instancia arrancada con PFILE).

# Notes by version

Sin diferencias estructurales relevantes 10g–23ai.

# Notes by platform

Ninguna — la ruta física del SPFILE difiere por plataforma pero no se lee aquí.

# Container / role scope notes

SPFILE es de instancia física — `NOT_APPLICABLE` a tenancy.

# Cost classification rationale

`LOW`: subquery de conteo + filtro acotado.

# License notes

Ninguna.

# Sanitization notes

`value` → condicional según el parámetro modificado.

# Evolution via `/change query`

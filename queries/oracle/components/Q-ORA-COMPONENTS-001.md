---
query_id: Q-ORA-COMPONENTS-001
version: 1.0.0
domain: oracle
purpose: Estado y versión de componentes registrados

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_REGISTRY]
privileges_required: [SELECT on DBA_REGISTRY]

risk_class: R0
cost_class: LOW
timeout_seconds: 10
max_rows: 100
max_output_bytes: 32768

sensitivity: LOW
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT comp_id, comp_name, version, status
FROM   dba_registry
ORDER  BY status, comp_name;
```

# Notes by version

`CDB_REGISTRY` disponible desde 12c como alternativa por PDB.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW`: número fijo y pequeño de componentes.

# License notes

Un componente `VALID` con `OPTION OFF` es evidencia útil para `policies/licensing-awareness-policy.md` (confirma que la feature no está en uso), pero esta query no determina licenciamiento por sí sola.

# Sanitization notes

Todos los campos → KEEP (nombres de componente Oracle estándar, no sensibles).

# Evolution via `/change query`

---
query_id: Q-SEC-ROLE-GRANTS-001
version: 1.0.0

domain: security
purpose: >
  Roles otorgados a usuarios/roles (direct grants + admin option) — base para privilege
  inheritance awareness (# 10 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_ROLE_PRIVS]
privileges_required: [SELECT on DBA_ROLE_PRIVS]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 15
max_rows: 500
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_security_roles.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT grantee, granted_role, admin_option, default_role
FROM   dba_role_privs
ORDER  BY grantee, granted_role;
```

# Notes by version

`DBA_ROLE_PRIVS` estable desde 10g — sin cambios estructurales conocidos.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`MEDIUM` — puede tener miles de filas en ambientes con muchos roles/usuarios.

# License notes

Ninguna.

# Sanitization notes

`grantee`/`granted_role` → MASK por defecto salvo entradas Oracle-maintained conocidas.

# Evolution via `/change query`

N/A.

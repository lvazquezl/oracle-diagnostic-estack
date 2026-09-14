---
query_id: Q-SEC-OBJECT-PRIVILEGES-001
version: 1.0.0

domain: security
purpose: Object privileges otorgados directamente a usuarios/roles (excluyendo PUBLIC) — object-privileges analysis (# 10 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_TAB_PRIVS]
privileges_required: [SELECT on DBA_TAB_PRIVS]

risk_class: R0
cost_class: HIGH

timeout_seconds: 20
max_rows: 500
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_security_object_privileges.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT grantee, owner, table_name, privilege, grantable
FROM   dba_tab_privs
WHERE  grantee != 'PUBLIC'
ORDER  BY grantee, owner, table_name;
```

`table_name` es cualquier objeto con privilegios de objeto otorgables (tabla, vista,
procedimiento, paquete, tipo) — no sólo tablas, es el nombre de columna real de la vista.

# Notes by version

`DBA_TAB_PRIVS` estable desde 10g.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`HIGH` — `DBA_TAB_PRIVS` puede tener decenas de miles de filas en esquemas de aplicación
grandes; `max_rows: 500` y `time_window` acotan el alcance (# 59 del prompt).

# License notes

Ninguna.

# Sanitization notes

`grantee`/`owner` → MASK por defecto salvo Oracle-maintained conocido.

# Evolution via `/change query`

N/A.

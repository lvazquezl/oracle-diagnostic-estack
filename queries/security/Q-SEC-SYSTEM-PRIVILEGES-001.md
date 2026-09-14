---
query_id: Q-SEC-SYSTEM-PRIVILEGES-001
version: 1.0.0

domain: security
purpose: >
  System privileges otorgados directamente a usuarios/roles (excluyendo PUBLIC, ver
  Q-SEC-PUBLIC-SYSTEM-GRANTS-001) — base de dangerous/powerful privilege detection (# 10, # 11
  del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_SYS_PRIVS]
privileges_required: [SELECT on DBA_SYS_PRIVS]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 15
max_rows: 500
max_output_bytes: 131072

sensitivity: HIGH
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_security_system_privileges.sh, tests/test_security_powerful_privileges.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT grantee, privilege, admin_option
FROM   dba_sys_privs
WHERE  grantee != 'PUBLIC'
ORDER  BY grantee, privilege;
```

`grantee != 'PUBLIC'` es deliberado — PUBLIC grants se certifican por separado
(`Q-SEC-PUBLIC-SYSTEM-GRANTS-001`) porque requieren una clasificación distinta
(`ORACLE_REQUIRED_DEFAULT/APPLICATION_REQUIRED/CUSTOM/UNKNOWN`, `# 12` del prompt) que no aplica
a grants a usuarios/roles individuales.

# Notes by version

`DBA_SYS_PRIVS` estable desde 10g.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`MEDIUM` — puede tener miles de filas.

# License notes

Ninguna.

# Sanitization notes

`grantee` → MASK por defecto salvo Oracle-maintained conocido.

# Evolution via `/change query`

N/A.

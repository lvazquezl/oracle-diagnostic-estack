---
query_id: Q-SEC-PUBLIC-SYSTEM-GRANTS-001
version: 1.0.0

domain: security
purpose: System privileges otorgados a PUBLIC — PUBLIC exposure analysis (# 12 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_SYS_PRIVS]
privileges_required: [SELECT on DBA_SYS_PRIVS]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 200
max_output_bytes: 65536

sensitivity: HIGH
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_security_public_grants.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT privilege
FROM   dba_sys_privs
WHERE  grantee = 'PUBLIC'
ORDER  BY privilege;
```

`grantee = 'PUBLIC'` es un literal fijo, no un token de usuario — sin necesidad de sanitización.
Clasificación posterior (`ORACLE_REQUIRED_DEFAULT/APPLICATION_REQUIRED/CUSTOM/UNKNOWN`) vía
catálogo interno del skill `security/public-grants`, nunca inventada por heurística de nombre.

# Notes by version

Estable desde 10g.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW` — PUBLIC rara vez tiene más de unas pocas docenas de system privileges.

# License notes

Ninguna.

# Sanitization notes

`privilege` es un nombre de privilegio Oracle estándar → KEEP.

# Evolution via `/change query`

N/A.

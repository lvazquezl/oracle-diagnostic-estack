---
query_id: Q-SEC-ROLE-SYSTEM-PRIVILEGES-001
version: 1.0.0

domain: security
purpose: System privileges otorgados a roles disponibles para la sesión — privilege inheritance awareness (# 10 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [ROLE_SYS_PRIVS]
privileges_required: [SELECT on ROLE_SYS_PRIVS (o rol activo con visibilidad equivalente)]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 15
max_rows: 500
max_output_bytes: 131072

sensitivity: HIGH
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_security_system_privileges.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT role, privilege, admin_option
FROM   role_sys_privs
ORDER  BY role, privilege;
```

Usada junto con `Q-SEC-ROLE-GRANTS-001`/`Q-SEC-NESTED-ROLE-GRANTS-001` para resolver
`grant_path: VIA_ROLE` con `role_chain` completo — nunca se asume que un usuario sin grant
directo carece del privilegio.

# Notes by version

Estable desde 10g.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`MEDIUM`.

# License notes

Ninguna.

# Sanitization notes

`role` → KEEP/MASK según convención de nombrado del cliente.

# Evolution via `/change query`

N/A.

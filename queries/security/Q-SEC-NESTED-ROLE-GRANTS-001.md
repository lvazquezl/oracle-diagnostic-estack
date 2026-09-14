---
query_id: Q-SEC-NESTED-ROLE-GRANTS-001
version: 1.0.0

domain: security
purpose: Nested roles (roles otorgados a roles) — evita análisis superficial de sólo grants directos (# 10 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [ROLE_ROLE_PRIVS]
privileges_required: [SELECT on ROLE_ROLE_PRIVS (o rol activo con visibilidad equivalente)]

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
SELECT role, granted_role, admin_option
FROM   role_role_privs
ORDER  BY role, granted_role;
```

`ROLE_ROLE_PRIVS` muestra los roles otorgados a los roles disponibles para la sesión actual —
usada junto con `Q-SEC-ROLE-GRANTS-001` para construir la cadena de role chain completa
(`grant_path: VIA_ROLE`) sin asumir sólo grants directos.

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

`role`/`granted_role` → KEEP/MASK según convención de nombrado del cliente.

# Evolution via `/change query`

N/A.

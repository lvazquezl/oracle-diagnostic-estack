---
query_id: Q-SEC-PROXY-AUTHENTICATION-001
version: 1.0.0

domain: security
purpose: Proxy authentication awareness (CONNECT THROUGH) — nunca credenciales (# 118 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [PROXY_USERS]
privileges_required: [SELECT on PROXY_USERS (o rol activo con visibilidad equivalente)]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 200
max_output_bytes: 65536

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_security_admin_privileges.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT proxy, client, authentication, authorization_constraint
FROM   proxy_users
ORDER  BY proxy, client;
```

# Notes by version

`PROXY_USERS` estable desde versiones antiguas (proxy authentication vía OCI existe desde 9i) —
certificado desde 10g (mínimo soportado por el catálogo).

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW`.

# License notes

Ninguna.

# Sanitization notes

`proxy`/`client` → MASK por defecto.

# Evolution via `/change query`

N/A.

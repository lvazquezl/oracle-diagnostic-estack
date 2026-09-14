---
query_id: Q-SEC-PUBLIC-OBJECT-GRANTS-001
version: 1.0.0

domain: security
purpose: Object privileges otorgados a PUBLIC — PUBLIC exposure analysis (# 12 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_TAB_PRIVS]
privileges_required: [SELECT on DBA_TAB_PRIVS]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 15
max_rows: 500
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_security_public_grants.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT owner, table_name, privilege
FROM   dba_tab_privs
WHERE  grantee = 'PUBLIC'
ORDER  BY owner, table_name, privilege;
```

Privilegios de objeto a PUBLIC (ej. `EXECUTE ANY PROCEDURE` a paquetes UTL_* sin restricción) son
un vector clásico de superficie de ataque — clasificados igual que
`Q-SEC-PUBLIC-SYSTEM-GRANTS-001`, `revoke_recommended` nunca `true` sin dependency analysis.

# Notes by version

Estable desde 10g.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`MEDIUM` — Oracle otorga cientos de grants a PUBLIC por defecto en una instalación estándar.

# License notes

Ninguna.

# Sanitization notes

`owner` → MASK por defecto salvo Oracle-maintained conocido.

# Evolution via `/change query`

N/A.

---
query_id: Q-SEC-ROLE-SYSTEM-PRIVILEGES-001
version: 2.0.0

domain: security
purpose: System privileges otorgados a TODOS los roles de la base (no sólo a los de la sesión) — privilege inheritance awareness (# 10 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_SYS_PRIVS, DBA_ROLES]
privileges_required: [SELECT on DBA_SYS_PRIVS, SELECT on DBA_ROLES]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 15
max_rows: 500
max_output_bytes: 131072

sensitivity: HIGH
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-ROLE-SYSTEM-PRIVILEGES-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g)"
  - variant_id: Q-SEC-ROLE-SYSTEM-PRIVILEGES-001-V2
    label: modern_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_12plus)"

tests: [tests/test_no_write_operations.sh, tests/test_security_system_privileges.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g)

```sql
SELECT sp.grantee AS role, sp.privilege, sp.admin_option
FROM   dba_sys_privs sp
JOIN   dba_roles r ON r.role = sp.grantee
ORDER  BY sp.grantee, sp.privilege;
```

# Statement / procedure (read-only) — Variant V2 (modern_12plus)

```sql
SELECT sp.grantee AS role, r.oracle_maintained, sp.privilege, sp.admin_option
FROM   dba_sys_privs sp
JOIN   dba_roles r ON r.role = sp.grantee
ORDER  BY sp.grantee, sp.privilege;
```

Usada junto con `Q-SEC-ROLE-GRANTS-001`/`Q-SEC-NESTED-ROLE-GRANTS-001` para resolver `grant_path: VIA_ROLE` con `role_chain` completo. `ROLE_SYS_PRIVS` (1.0.0) sólo ve los roles habilitados en la sesión: con la cuenta de diagnóstico de mínimo privilegio devolvía 0 filas (LAB19S, 2026-10-01).

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

CHG-ESTACK-SEC-QUERIES-001 — 2.0.0: `DBA_SYS_PRIVS` ⋈ `DBA_ROLES` en lugar de `ROLE_SYS_PRIVS` (vista limitada a la sesión). V2 agrega `oracle_maintained` (12.1+) para separar roles de Oracle de roles del cliente.

N/A.

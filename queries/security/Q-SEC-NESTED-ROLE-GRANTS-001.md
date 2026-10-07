---
query_id: Q-SEC-NESTED-ROLE-GRANTS-001
version: 3.0.0

domain: security
purpose: Nested roles de TODA la base (roles otorgados a roles) — evita análisis superficial de sólo grants directos (# 10 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_ROLE_PRIVS, DBA_ROLES, CDB_ROLE_PRIVS, CDB_ROLES]
privileges_required: [SELECT on DBA_ROLE_PRIVS, SELECT on DBA_ROLES, SELECT on CDB_ROLE_PRIVS, SELECT on CDB_ROLES]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 15
max_rows: 500
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-NESTED-ROLE-GRANTS-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g)"
  - variant_id: Q-SEC-NESTED-ROLE-GRANTS-001-V2
    label: cdb_custom_roles_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_custom_roles_12plus, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_security_roles.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g)

```sql
SELECT rp.grantee AS role, rp.granted_role, rp.admin_option
FROM   dba_role_privs rp
JOIN   dba_roles r ON r.role = rp.grantee
ORDER  BY rp.grantee, rp.granted_role;
```

# Statement / procedure (read-only) — Variant V2 (cdb_custom_roles_12plus, 12.1+)

```sql
SELECT rp.con_id, rp.grantee AS role, r.oracle_maintained, rp.granted_role, rp.admin_option
FROM   cdb_role_privs rp
JOIN   cdb_roles r ON r.con_id = rp.con_id AND r.role = rp.grantee
WHERE  r.oracle_maintained = 'N'
ORDER  BY rp.con_id, rp.grantee, rp.granted_role;
```

Construye la cadena de roles completa (`grant_path: VIA_ROLE`) para todos los roles de la base. `ROLE_ROLE_PRIVS` (1.0.0) sólo veía los roles habilitados en la sesión (LAB19S: 1 fila con la cuenta de diagnóstico, 29 con una cuenta amplia).

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

CHG-ESTACK-SEC-QUERIES-001 — 2.0.0: `DBA_ROLE_PRIVS` ⋈ `DBA_ROLES` en lugar de `ROLE_ROLE_PRIVS`. V2 agrega `oracle_maintained` (12.1+).

N/A.

3.0.0 CHG-ESTACK-PDB-COVERAGE-001: V2 (12.1+) lee `CDB_ROLE_PRIVS`/`CDB_ROLES` con `con_id` y se limita a los roles **propios** que reciben otros roles (incluidos roles de Oracle como DBA). V1 sin cambios.

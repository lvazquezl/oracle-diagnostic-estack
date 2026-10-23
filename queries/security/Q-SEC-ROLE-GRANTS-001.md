---
query_id: Q-SEC-ROLE-GRANTS-001
version: 2.0.0

domain: security
purpose: >
  Roles otorgados a usuarios/roles (direct grants + admin option) — base para privilege
  inheritance awareness (# 10 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_ROLE_PRIVS, DBA_ROLES, CDB_ROLE_PRIVS, CDB_USERS, CDB_ROLES]
privileges_required: [SELECT on DBA_ROLE_PRIVS, SELECT on DBA_ROLES, SELECT on CDB_ROLE_PRIVS, SELECT on CDB_USERS, SELECT on CDB_ROLES]

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
  - variant_id: Q-SEC-ROLE-GRANTS-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_ROLE_PRIVS)"
  - variant_id: Q-SEC-ROLE-GRANTS-001-V2
    label: cdb_aware_121
    oracle_versions: {min: "12.1", max: "12.1.0.1"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_121, 12.1–12.1.0.1: CDB_ROLE_PRIVS con con_id)"
  - variant_id: Q-SEC-ROLE-GRANTS-001-V3
    label: cdb_aware_12102plus
    oracle_versions: {min: "12.1.0.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V3 (cdb_aware_12102plus, 12.1.0.2–23.0: CDB_ROLE_PRIVS, solo grantees propios y roles de Oracle por nombre)"

tests: [tests/test_no_write_operations.sh, tests/test_security_roles.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_ROLE_PRIVS)

```sql
SELECT p.grantee, CASE WHEN EXISTS (SELECT 1 FROM dba_roles r WHERE r.role = p.grantee) THEN 'ROLE' ELSE 'USER' END AS grantee_kind, p.granted_role, p.admin_option, p.default_role
FROM   dba_role_privs p
ORDER  BY p.grantee, p.granted_role;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_121, 12.1–12.1.0.1: CDB_ROLE_PRIVS con con_id)

```sql
SELECT p.con_id, p.grantee, CASE WHEN EXISTS (SELECT 1 FROM cdb_roles r WHERE r.con_id = p.con_id AND r.role = p.grantee) THEN 'ROLE' ELSE 'USER' END AS grantee_kind, p.granted_role, p.admin_option, p.default_role
FROM   cdb_role_privs p
ORDER  BY p.con_id, p.grantee, p.granted_role;
```

# Statement / procedure (read-only) — Variant V3 (cdb_aware_12102plus, 12.1.0.2–23.0: CDB_ROLE_PRIVS, solo grantees propios y roles de Oracle por nombre)

```sql
SELECT p.con_id, p.grantee, CASE WHEN EXISTS (SELECT 1 FROM cdb_roles r WHERE r.con_id = p.con_id AND r.role = p.grantee) THEN 'ROLE' ELSE 'USER' END AS grantee_kind,
       CASE WHEN r.oracle_maintained = 'Y' THEN p.granted_role ELSE 'CUSTOM' END AS oracle_role,
       CASE WHEN r.oracle_maintained = 'Y' THEN NULL ELSE p.granted_role END AS granted_role,
       p.admin_option, p.default_role
FROM   cdb_role_privs p
JOIN   cdb_roles r ON r.con_id = p.con_id AND r.role = p.granted_role
WHERE  NOT EXISTS (SELECT 1 FROM cdb_users u WHERE u.con_id = p.con_id AND u.username = p.grantee AND u.oracle_maintained = 'Y')
AND    NOT EXISTS (SELECT 1 FROM cdb_roles r WHERE r.con_id = p.con_id AND r.role = p.grantee AND r.oracle_maintained = 'Y')
ORDER  BY p.con_id, p.grantee, oracle_role, granted_role;
```

# Notes by version

`ORACLE_MAINTAINED` existe desde 12.1.0.2: V3 excluye grantees de Oracle y nombra los roles de Oracle concedidos (por ejemplo `DBA`), que son lo que importa para el riesgo.

# Notes by platform

Ninguna.

# Container / role scope notes

V2/V3 cubren los contenedores visibles por `CONTAINER_DATA`.

# Cost classification rationale

`MEDIUM` — puede tener miles de filas en ambientes con muchos roles/usuarios.

# License notes

Ninguna.

# Sanitization notes

`grantee` y los roles propios se enmascaran. `oracle_role` solo lleva el nombre de un rol mantenido por Oracle (lo garantiza el SQL); un rol propio sale como `CUSTOM` en `oracle_role` y enmascarado en `granted_role`.

# Evolution via `/change query`

N/A.

2.0.0 CHG-ESTACK-B7-SECURITY-COVERAGE-001: 2.0.0: `CDB_ROLE_PRIVS` por contenedor; grantees de Oracle excluidos y roles de Oracle por nombre desde 12.1.0.2.

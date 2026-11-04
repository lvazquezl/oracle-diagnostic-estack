---
query_id: Q-SEC-SYSTEM-PRIVILEGES-001
version: 2.0.0

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

objects_accessed: [DBA_SYS_PRIVS, DBA_ROLES, CDB_SYS_PRIVS, CDB_USERS, CDB_ROLES]
privileges_required: [SELECT on DBA_SYS_PRIVS, SELECT on DBA_ROLES, SELECT on CDB_SYS_PRIVS, SELECT on CDB_USERS, SELECT on CDB_ROLES]

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
  - variant_id: Q-SEC-SYSTEM-PRIVILEGES-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_SYS_PRIVS)"
  - variant_id: Q-SEC-SYSTEM-PRIVILEGES-001-V2
    label: cdb_aware_121
    oracle_versions: {min: "12.1", max: "12.1.0.1"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_121, 12.1–12.1.0.1: CDB_SYS_PRIVS con con_id)"
  - variant_id: Q-SEC-SYSTEM-PRIVILEGES-001-V3
    label: cdb_aware_12102plus
    oracle_versions: {min: "12.1.0.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V3 (cdb_aware_12102plus, 12.1.0.2–23.0: CDB_SYS_PRIVS, solo grantees propios)"

tests: [tests/test_no_write_operations.sh, tests/test_security_system_privileges.sh, tests/test_security_powerful_privileges.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_SYS_PRIVS)

```sql
SELECT p.grantee, CASE WHEN EXISTS (SELECT 1 FROM dba_roles r WHERE r.role = p.grantee) THEN 'ROLE' ELSE 'USER' END AS grantee_kind, p.privilege, p.admin_option
FROM   dba_sys_privs p
WHERE  grantee != 'PUBLIC'
ORDER  BY p.grantee, p.privilege;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_121, 12.1–12.1.0.1: CDB_SYS_PRIVS con con_id)

```sql
SELECT p.con_id, p.grantee, CASE WHEN EXISTS (SELECT 1 FROM cdb_roles r WHERE r.con_id = p.con_id AND r.role = p.grantee) THEN 'ROLE' ELSE 'USER' END AS grantee_kind, p.privilege, p.admin_option
FROM   cdb_sys_privs p
WHERE  grantee != 'PUBLIC'
ORDER  BY p.con_id, p.grantee, p.privilege;
```

# Statement / procedure (read-only) — Variant V3 (cdb_aware_12102plus, 12.1.0.2–23.0: CDB_SYS_PRIVS, solo grantees propios)

```sql
SELECT p.con_id, p.grantee, CASE WHEN EXISTS (SELECT 1 FROM cdb_roles r WHERE r.con_id = p.con_id AND r.role = p.grantee) THEN 'ROLE' ELSE 'USER' END AS grantee_kind, p.privilege, p.admin_option
FROM   cdb_sys_privs p
WHERE  grantee != 'PUBLIC'
AND    NOT EXISTS (SELECT 1 FROM cdb_users u WHERE u.con_id = p.con_id AND u.username = p.grantee AND u.oracle_maintained = 'Y')
AND    NOT EXISTS (SELECT 1 FROM cdb_roles r WHERE r.con_id = p.con_id AND r.role = p.grantee AND r.oracle_maintained = 'Y')
ORDER  BY p.con_id, p.grantee, p.privilege;
```

# Notes by version

`ORACLE_MAINTAINED` existe desde 12.1.0.2: V3 excluye los grantees de Oracle; los privilegios de los roles propios ya los cubre `Q-SEC-ROLE-SYSTEM-PRIVILEGES-001`.

# Notes by platform

Ninguna.

# Container / role scope notes

V2/V3 cubren los contenedores visibles por `CONTAINER_DATA`. `PUBLIC` se certifica aparte.

# Cost classification rationale

`MEDIUM` — puede tener miles de filas.

# License notes

Ninguna.

# Sanitization notes

`grantee` se enmascara; `privilege` es un término de Oracle.

# Evolution via `/change query`

N/A.

2.0.0 CHG-ESTACK-B7-SECURITY-COVERAGE-001: 2.0.0: `CDB_SYS_PRIVS` por contenedor, tipo de grantee, grantees de Oracle excluidos desde 12.1.0.2.

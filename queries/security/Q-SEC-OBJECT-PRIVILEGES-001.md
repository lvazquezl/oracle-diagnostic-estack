---
query_id: Q-SEC-OBJECT-PRIVILEGES-001
version: 2.0.0

domain: security
purpose: Object privileges otorgados directamente a usuarios/roles (excluyendo PUBLIC) — object-privileges analysis (# 10 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_TAB_PRIVS, DBA_ROLES, CDB_TAB_PRIVS, CDB_USERS, CDB_ROLES]
privileges_required: [SELECT on DBA_TAB_PRIVS, SELECT on DBA_ROLES, SELECT on CDB_TAB_PRIVS, SELECT on CDB_USERS, SELECT on CDB_ROLES]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 20
max_rows: 500
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-OBJECT-PRIVILEGES-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_TAB_PRIVS, agregado por grantee)"
  - variant_id: Q-SEC-OBJECT-PRIVILEGES-001-V2
    label: cdb_aware_121
    oracle_versions: {min: "12.1", max: "12.1.0.1"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_121, 12.1–12.1.0.1: CDB_TAB_PRIVS con con_id)"
  - variant_id: Q-SEC-OBJECT-PRIVILEGES-001-V3
    label: cdb_aware_12102plus
    oracle_versions: {min: "12.1.0.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V3 (cdb_aware_12102plus, 12.1.0.2–23.0: CDB_TAB_PRIVS, solo grantees propios)"

tests: [tests/test_no_write_operations.sh, tests/test_security_object_privileges.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_TAB_PRIVS, agregado por grantee)

```sql
SELECT p.grantee, CASE WHEN EXISTS (SELECT 1 FROM dba_roles r WHERE r.role = p.grantee) THEN 'ROLE' ELSE 'USER' END AS grantee_kind, p.privilege, p.grantable, COUNT(*) AS object_count
FROM   dba_tab_privs p
WHERE  grantee != 'PUBLIC'
GROUP  BY p.grantee, p.privilege, p.grantable
ORDER  BY p.grantee, p.privilege;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_121, 12.1–12.1.0.1: CDB_TAB_PRIVS con con_id)

```sql
SELECT p.con_id, p.grantee, CASE WHEN EXISTS (SELECT 1 FROM cdb_roles r WHERE r.con_id = p.con_id AND r.role = p.grantee) THEN 'ROLE' ELSE 'USER' END AS grantee_kind, p.privilege, p.grantable, COUNT(*) AS object_count
FROM   cdb_tab_privs p
WHERE  grantee != 'PUBLIC'
GROUP  BY p.con_id, p.grantee, p.privilege, p.grantable
ORDER  BY p.con_id, p.grantee, p.privilege;
```

# Statement / procedure (read-only) — Variant V3 (cdb_aware_12102plus, 12.1.0.2–23.0: CDB_TAB_PRIVS, solo grantees propios)

```sql
SELECT p.con_id, p.grantee, CASE WHEN EXISTS (SELECT 1 FROM cdb_roles r WHERE r.con_id = p.con_id AND r.role = p.grantee) THEN 'ROLE' ELSE 'USER' END AS grantee_kind, p.privilege, p.grantable, COUNT(*) AS object_count
FROM   cdb_tab_privs p
WHERE  grantee != 'PUBLIC'
AND    NOT EXISTS (SELECT 1 FROM cdb_users u WHERE u.con_id = p.con_id AND u.username = p.grantee AND u.oracle_maintained = 'Y')
AND    NOT EXISTS (SELECT 1 FROM cdb_roles r WHERE r.con_id = p.con_id AND r.role = p.grantee AND r.oracle_maintained = 'Y')
GROUP  BY p.con_id, p.grantee, p.privilege, p.grantable
ORDER  BY p.con_id, p.grantee, p.privilege;
```

# Notes by version

`ORACLE_MAINTAINED` existe desde 12.1.0.2: V3 excluye los grantees de Oracle (usuarios y roles). V1/V2 no pueden distinguirlos y pueden llegar al tope de filas.

# Notes by platform

Ninguna.

# Container / role scope notes

V2/V3 cubren los contenedores visibles por `CONTAINER_DATA`. `PUBLIC` se certifica aparte (`Q-SEC-PUBLIC-OBJECT-GRANTS-001`).

# Cost classification rationale

`HIGH` — `DBA_TAB_PRIVS` puede tener decenas de miles de filas en esquemas de aplicación
grandes; `max_rows: 500` y `time_window` acotan el alcance (# 59 del prompt).

# License notes

Ninguna.

# Sanitization notes

Agregado por grantee (enmascarado), tipo de grantee, privilegio y `grantable`: dueños y objetos no salen de la base.

# Evolution via `/change query`

N/A.

2.0.0 CHG-ESTACK-B7-SECURITY-COVERAGE-001: 2.0.0: agregado por grantee y privilegio, `CDB_TAB_PRIVS` por contenedor, grantees de Oracle excluidos desde 12.1.0.2.

---
query_id: Q-SEC-PUBLIC-OBJECT-GRANTS-001
version: 2.0.0

domain: security
purpose: Object privileges otorgados a PUBLIC — PUBLIC exposure analysis (# 12 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_TAB_PRIVS, CDB_TAB_PRIVS, CDB_USERS]
privileges_required: [SELECT on DBA_TAB_PRIVS, SELECT on CDB_TAB_PRIVS, SELECT on CDB_USERS]

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
  - variant_id: Q-SEC-PUBLIC-OBJECT-GRANTS-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_TAB_PRIVS, agregado por dueño y privilegio)"
  - variant_id: Q-SEC-PUBLIC-OBJECT-GRANTS-001-V2
    label: cdb_aware_121
    oracle_versions: {min: "12.1", max: "12.1.0.1"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_121, 12.1–12.1.0.1: CDB_TAB_PRIVS con con_id)"
  - variant_id: Q-SEC-PUBLIC-OBJECT-GRANTS-001-V3
    label: cdb_aware_12102plus
    oracle_versions: {min: "12.1.0.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V3 (cdb_aware_12102plus, 12.1.0.2–23.0: CDB_TAB_PRIVS: dueños de Oracle agregados, propios por dueño)"

tests: [tests/test_no_write_operations.sh, tests/test_security_public_grants.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_TAB_PRIVS, agregado por dueño y privilegio)

```sql
SELECT owner, privilege, COUNT(*) AS object_count
FROM   dba_tab_privs
WHERE  grantee = 'PUBLIC'
GROUP  BY owner, privilege
ORDER  BY owner, privilege;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_121, 12.1–12.1.0.1: CDB_TAB_PRIVS con con_id)

```sql
SELECT con_id, owner, privilege, COUNT(*) AS object_count
FROM   cdb_tab_privs
WHERE  grantee = 'PUBLIC'
GROUP  BY con_id, owner, privilege
ORDER  BY con_id, owner, privilege;
```

# Statement / procedure (read-only) — Variant V3 (cdb_aware_12102plus, 12.1.0.2–23.0: CDB_TAB_PRIVS: dueños de Oracle agregados, propios por dueño)

```sql
SELECT p.con_id, CASE WHEN u.oracle_maintained = 'Y' THEN NULL ELSE p.owner END AS owner,
       NVL(u.oracle_maintained, 'N') AS owner_oracle_maintained, p.privilege, COUNT(*) AS object_count
FROM   cdb_tab_privs p
LEFT   JOIN cdb_users u ON u.con_id = p.con_id AND u.username = p.owner
WHERE  p.grantee = 'PUBLIC'
GROUP  BY p.con_id, CASE WHEN u.oracle_maintained = 'Y' THEN NULL ELSE p.owner END, NVL(u.oracle_maintained, 'N'), p.privilege
ORDER  BY 1, 3, 2, 4;
```

# Notes by version

`ORACLE_MAINTAINED` existe desde 12.1.0.2: V3 agrega en una fila por privilegio los grants a `PUBLIC` de esquemas de Oracle (decenas de miles) y detalla por dueño los de esquemas propios, que son el riesgo.

# Notes by platform

Ninguna.

# Container / role scope notes

V2/V3 cubren los contenedores visibles por `CONTAINER_DATA`.

# Cost classification rationale

`MEDIUM` — Oracle otorga cientos de grants a PUBLIC por defecto en una instalación estándar.

# License notes

Ninguna.

# Sanitization notes

Solo conteos por dueño (enmascarado; vacío si es de Oracle) y privilegio. Los objetos no salen de la base.

# Evolution via `/change query`

N/A.

2.0.0 CHG-ESTACK-B7-SECURITY-COVERAGE-001: 2.0.0: agregado por dueño y privilegio; esquemas de Oracle agregados; `CDB_TAB_PRIVS` por contenedor.

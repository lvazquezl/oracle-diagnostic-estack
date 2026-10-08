---
query_id: Q-SEC-DIRECTORIES-001
version: 4.0.0

domain: security
purpose: Directory objects y sus grants — directories, nunca navega filesystem (# 38 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_DIRECTORIES, DBA_TAB_PRIVS, CDB_DIRECTORIES, CDB_TAB_PRIVS, CDB_USERS, CDB_ROLES]
privileges_required: [SELECT on DBA_DIRECTORIES, SELECT on DBA_TAB_PRIVS, SELECT on CDB_DIRECTORIES, SELECT on CDB_TAB_PRIVS, SELECT on CDB_USERS, SELECT on CDB_ROLES]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 200
max_output_bytes: 65536

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-DIRECTORIES-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2)"
  - variant_id: Q-SEC-DIRECTORIES-001-V2
    label: cdb_aware_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_12plus, 12.1+: CDB_* con con_id)"

tests: [tests/test_no_write_operations.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2)

```sql
SELECT d.directory_name, d.directory_path, p.grantee, p.privilege
FROM   dba_directories d
LEFT   JOIN dba_tab_privs p
       ON  p.owner = d.owner AND p.table_name = d.directory_name
ORDER  BY d.directory_name, p.grantee, p.privilege;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_12plus, 12.1+: CDB_* con con_id)

```sql
SELECT d.con_id, d.directory_name, p.grantee,
       COALESCE(u.oracle_maintained, r.oracle_maintained) AS grantee_oracle_maintained,
       p.privilege
FROM   cdb_directories d
LEFT   JOIN cdb_tab_privs p
       ON  p.con_id = d.con_id AND p.owner = d.owner AND p.table_name = d.directory_name
LEFT   JOIN cdb_users u ON u.con_id = p.con_id AND u.username = p.grantee
LEFT   JOIN cdb_roles r ON r.con_id = p.con_id AND r.role = p.grantee
ORDER  BY d.con_id, d.directory_name, p.grantee, p.privilege;
```

Una fila por grant de cada directorio (o una por directorio sin grants). La 1.0.0 tenía dos sentencias y no resolvía. `directory_path` es una ruta del servidor: el collector del gateway no la expone; en ejecución humana se enmascara.

# Notes by version

Ambas vistas estables desde 10g.

# Notes by platform

`directory_path` es un path de filesystem del servidor — se reporta como metadata, nunca se
accede a su contenido (`# 38` del prompt).

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW`.

# License notes

Ninguna.

# Sanitization notes

`directory_path` → MASK (puede revelar convención de filesystem interna). `grantee` → MASK por
defecto.

# Evolution via `/change query`

CHG-ESTACK-SEC-QUERIES-001 — 2.0.0: directorios y grants en una sola sentencia (`LEFT JOIN`).

N/A.

3.0.0 CHG-ESTACK-PDB-COVERAGE-001: V2 (12.1+) lee `CDB_DIRECTORIES`/`CDB_TAB_PRIVS` con `con_id` y **ya no selecciona `directory_path`** (el gateway nunca lo expuso; ahora tampoco sale de la base).

4.0.0 CHG-ESTACK-ASSESSMENT-ACCURACY-001: V2 agrega `grantee_oracle_maintained` (usuario o rol de Oracle frente a propio): un grant de `READ`/`WRITE` a una cuenta propia es lo que importa revisar (FND-0013 de ANA-20261007-001).

---
query_id: Q-SEC-DB-LINKS-001
version: 2.0.0

domain: security
purpose: Database links — metadata, nunca credenciales ni conexión (# 37 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_DB_LINKS, CDB_DB_LINKS]
privileges_required: [SELECT on DBA_DB_LINKS, SELECT on CDB_DB_LINKS]

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
  - variant_id: Q-SEC-DB-LINKS-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_DB_LINKS)"
  - variant_id: Q-SEC-DB-LINKS-001-V2
    label: cdb_aware_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_12plus, 12.1–23.0: CDB_DB_LINKS con con_id)"

tests: [tests/test_no_write_operations.sh, tests/test_no_secrets.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_DB_LINKS)

```sql
SELECT owner, CASE WHEN owner = 'PUBLIC' THEN 'PUBLIC' ELSE 'PRIVATE' END AS link_scope,
       SUBSTR(db_link, 1, INSTR(db_link || '.', '.') - 1) AS db_link,
       CASE WHEN username IS NULL THEN 'CONNECTED_USER' ELSE 'FIXED_USER' END AS link_auth,
       CASE WHEN host IS NULL THEN 'NONE' WHEN INSTR(host, '(') > 0 THEN 'CONNECT_DESCRIPTOR'
            WHEN INSTR(host, '/') > 0 OR INSTR(host, ':') > 0 THEN 'EASY_CONNECT' ELSE 'NET_SERVICE_NAME' END AS target_kind
FROM   dba_db_links
ORDER  BY owner, db_link;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_12plus, 12.1–23.0: CDB_DB_LINKS con con_id)

```sql
SELECT con_id, owner, CASE WHEN owner = 'PUBLIC' THEN 'PUBLIC' ELSE 'PRIVATE' END AS link_scope,
       SUBSTR(db_link, 1, INSTR(db_link || '.', '.') - 1) AS db_link,
       CASE WHEN username IS NULL THEN 'CONNECTED_USER' ELSE 'FIXED_USER' END AS link_auth,
       CASE WHEN host IS NULL THEN 'NONE' WHEN INSTR(host, '(') > 0 THEN 'CONNECT_DESCRIPTOR'
            WHEN INSTR(host, '/') > 0 OR INSTR(host, ':') > 0 THEN 'EASY_CONNECT' ELSE 'NET_SERVICE_NAME' END AS target_kind
FROM   cdb_db_links
ORDER  BY con_id, owner, db_link;
```

# Notes by version

`DBA_DB_LINKS` es estable; `CDB_DB_LINKS` existe desde 12.1.

# Notes by platform

Ninguna.

# Container / role scope notes

V2 cubre los contenedores visibles por `CONTAINER_DATA`.

# Cost classification rationale

`LOW`.

# License notes

Ninguna.

# Sanitization notes

`host` y `username` nunca salen de la base: se reducen a `target_kind` (descriptor, Easy Connect, nombre de servicio o ninguno) y `link_auth` (usuario conectado o fijo). `owner` y el nombre del link (sin dominio) se enmascaran; `link_scope` (`PUBLIC`/`PRIVATE`) conserva si el link es público, que el enmascarado del dueño ocultaría. Nunca se lee una credencial ni se abre el link.

# Evolution via `/change query`

N/A.

2.0.0 CHG-ESTACK-B7-SECURITY-COVERAGE-001: 2.0.0: sin `host` ni `username`; clasificación en la base; `CDB_DB_LINKS` por contenedor; `link_scope` (validación en el lab).

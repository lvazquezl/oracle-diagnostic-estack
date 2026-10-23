---
query_id: Q-SEC-ENCRYPTED-TABLESPACES-001
version: 2.0.0

domain: security
purpose: Tablespaces con TDE tablespace encryption — tablespace-encryption (# 33 del prompt de Fase 8).

supported_oracle_versions: [11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_TABLESPACES, CDB_TABLESPACES, V$TABLESPACE, V$ENCRYPTED_TABLESPACES]
privileges_required: [SELECT on DBA_TABLESPACES, SELECT on CDB_TABLESPACES, SELECT on V$TABLESPACE, SELECT on V$ENCRYPTED_TABLESPACES]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 200
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-ENCRYPTED-TABLESPACES-001-V1
    label: legacy_11g
    oracle_versions: {min: "11.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_11g, 11.2–11.2: DBA_TABLESPACES)"
  - variant_id: Q-SEC-ENCRYPTED-TABLESPACES-001-V2
    label: cdb_aware_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_12plus, 12.1–23.0: CDB_TABLESPACES con con_id)"

tests: [tests/test_no_write_operations.sh, tests/test_tablespace_encryption.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_11g, 11.2–11.2: DBA_TABLESPACES)

```sql
SELECT t.tablespace_name,
       CASE WHEN e.ts# IS NOT NULL THEN 'ENCRYPTED' ELSE 'UNENCRYPTED' END AS classification,
       CASE WHEN e.ts# IS NULL THEN NULL WHEN e.encryptionalg IN ('AES128', 'AES192', 'AES256', '3DES168', 'ARIA128', 'ARIA192', 'ARIA256', 'SEED128', 'GOST256') THEN e.encryptionalg ELSE 'OTHER' END AS encryptionalg
FROM   dba_tablespaces t
LEFT   JOIN v$tablespace v ON v.name = t.tablespace_name
LEFT   JOIN v$encrypted_tablespaces e ON e.ts# = v.ts#
ORDER  BY t.tablespace_name;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_12plus, 12.1–23.0: CDB_TABLESPACES con con_id)

```sql
SELECT t.con_id, t.tablespace_name,
       CASE WHEN e.ts# IS NOT NULL THEN 'ENCRYPTED' ELSE 'UNENCRYPTED' END AS classification,
       CASE WHEN e.ts# IS NULL THEN NULL WHEN e.encryptionalg IN ('AES128', 'AES192', 'AES256', '3DES168', 'ARIA128', 'ARIA192', 'ARIA256', 'SEED128', 'GOST256') THEN e.encryptionalg ELSE 'OTHER' END AS encryptionalg
FROM   cdb_tablespaces t
LEFT   JOIN v$tablespace v ON v.con_id = t.con_id AND v.name = t.tablespace_name
LEFT   JOIN v$encrypted_tablespaces e ON e.con_id = v.con_id AND e.ts# = v.ts#
ORDER  BY t.con_id, t.tablespace_name;
```

# Notes by version

TDE de tablespace existe desde 11.2; `CON_ID` en las vistas `V$` y `CDB_TABLESPACES` desde 12.1.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

V2 cubre los contenedores visibles por `CONTAINER_DATA`.

# Cost classification rationale

`LOW`.

# License notes

Igual que `Q-SEC-TDE-WALLET-001` — Advanced Security Option donde aplique.

# Sanitization notes

`tablespace_name` se enmascara. `encryptionalg` es un enum cerrado (un valor desconocido sale como `OTHER`).

# Evolution via `/change query`

N/A.

2.0.0 CHG-ESTACK-B7-SECURITY-COVERAGE-001: 2.0.0: `CDB_TABLESPACES` por contenedor; join por `con_id`; algoritmo como enum cerrado.

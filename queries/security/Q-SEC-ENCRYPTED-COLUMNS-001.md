---
query_id: Q-SEC-ENCRYPTED-COLUMNS-001
version: 2.0.0

domain: security
purpose: Columnas con TDE column encryption — tde-awareness, complementa tablespace-encryption (# 31 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_ENCRYPTED_COLUMNS, CDB_ENCRYPTED_COLUMNS]
privileges_required: [SELECT on DBA_ENCRYPTED_COLUMNS, SELECT on CDB_ENCRYPTED_COLUMNS]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 500
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-ENCRYPTED-COLUMNS-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_ENCRYPTED_COLUMNS, agregado por dueño y algoritmo)"
  - variant_id: Q-SEC-ENCRYPTED-COLUMNS-001-V2
    label: cdb_aware_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_12plus, 12.1–23.0: CDB_ENCRYPTED_COLUMNS con con_id)"

tests: [tests/test_no_write_operations.sh, tests/test_tablespace_encryption.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_ENCRYPTED_COLUMNS, agregado por dueño y algoritmo)

```sql
SELECT owner, encryption_alg, COUNT(*) AS encrypted_columns
FROM  (SELECT owner, CASE WHEN encryption_alg LIKE 'AES 128%' THEN 'AES128' WHEN encryption_alg LIKE 'AES 192%' THEN 'AES192' WHEN encryption_alg LIKE 'AES 256%' THEN 'AES256' WHEN encryption_alg LIKE '3 Key Triple DES 168%' THEN '3DES168' ELSE 'OTHER' END AS encryption_alg FROM dba_encrypted_columns)
GROUP  BY owner, encryption_alg
ORDER  BY owner, encryption_alg;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_12plus, 12.1–23.0: CDB_ENCRYPTED_COLUMNS con con_id)

```sql
SELECT con_id, owner, encryption_alg, COUNT(*) AS encrypted_columns
FROM  (SELECT con_id, owner, CASE WHEN encryption_alg LIKE 'AES 128%' THEN 'AES128' WHEN encryption_alg LIKE 'AES 192%' THEN 'AES192' WHEN encryption_alg LIKE 'AES 256%' THEN 'AES256' WHEN encryption_alg LIKE '3 Key Triple DES 168%' THEN '3DES168' ELSE 'OTHER' END AS encryption_alg FROM cdb_encrypted_columns)
GROUP  BY con_id, owner, encryption_alg
ORDER  BY con_id, owner, encryption_alg;
```

# Notes by version

TDE por columna existe desde 10.2; `CDB_ENCRYPTED_COLUMNS` desde 12.1.

# Notes by platform

Ninguna.

# Container / role scope notes

V2 cubre los contenedores visibles por `CONTAINER_DATA`.

# Cost classification rationale

`LOW`.

# License notes

Advanced Security Option donde aplique.

# Sanitization notes

Tablas y columnas no salen: solo el conteo por dueño (enmascarado) y algoritmo (enum cerrado; texto de Oracle reducido en la base).

# Evolution via `/change query`

N/A.

2.0.0 CHG-ESTACK-B7-SECURITY-COVERAGE-001: 2.0.0: agregado por dueño y algoritmo, `CDB_ENCRYPTED_COLUMNS` por contenedor.

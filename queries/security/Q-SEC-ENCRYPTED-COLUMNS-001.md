---
query_id: Q-SEC-ENCRYPTED-COLUMNS-001
version: 1.0.0

domain: security
purpose: Columnas con TDE column encryption — tde-awareness, complementa tablespace-encryption (# 31 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_ENCRYPTED_COLUMNS]
privileges_required: [SELECT on DBA_ENCRYPTED_COLUMNS]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 500
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_tablespace_encryption.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT owner, table_name, column_name, encryption_alg
FROM   dba_encrypted_columns
ORDER  BY owner, table_name, column_name;
```

# Notes by version

`DBA_ENCRYPTED_COLUMNS` verificada disponible desde 10.2 (WebSearch, TDE column encryption
10gR2) — anterior a TDE tablespace encryption (11.2). Certificada en todo el rango del catálogo.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW`.

# License notes

Advanced Security Option donde aplique.

# Sanitization notes

`owner`/`table_name`/`column_name` → MASK por defecto — pueden revelar estructura/nombres de
esquema de aplicación. Nunca se selecciona el valor encriptado ni la clave.

# Evolution via `/change query`

N/A.

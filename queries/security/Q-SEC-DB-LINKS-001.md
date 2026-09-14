---
query_id: Q-SEC-DB-LINKS-001
version: 1.0.0

domain: security
purpose: Database links — metadata, nunca credenciales ni conexión (# 37 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_DB_LINKS]
privileges_required: [SELECT on DBA_DB_LINKS]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 200
max_output_bytes: 65536

sensitivity: HIGH
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_no_secrets.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT owner, db_link, username, host
FROM   dba_db_links
ORDER  BY owner, db_link;
```

Nunca se recupera la contraseña del db link (no expuesta por esta vista de todas formas) ni se
intenta conectar a través de él.

# Notes by version

`DBA_DB_LINKS` estable desde 10g.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW`.

# License notes

Ninguna.

# Sanitization notes

`owner`/`username` → MASK por defecto. `host` → MASK (puede revelar topología de red interna).

# Evolution via `/change query`

N/A.

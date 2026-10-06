---
query_id: Q-SEC-DIRECTORIES-001
version: 2.0.0

domain: security
purpose: Directory objects y sus grants — directories, nunca navega filesystem (# 38 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_DIRECTORIES, DBA_TAB_PRIVS]
privileges_required: [SELECT on DBA_DIRECTORIES, SELECT on DBA_TAB_PRIVS]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 200
max_output_bytes: 65536

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT d.directory_name, d.directory_path, p.grantee, p.privilege
FROM   dba_directories d
LEFT   JOIN dba_tab_privs p
       ON  p.owner = d.owner AND p.table_name = d.directory_name
ORDER  BY d.directory_name, p.grantee, p.privilege;
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

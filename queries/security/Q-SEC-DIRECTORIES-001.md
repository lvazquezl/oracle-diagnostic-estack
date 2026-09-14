---
query_id: Q-SEC-DIRECTORIES-001
version: 1.0.0

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
SELECT owner, directory_name, directory_path
FROM   dba_directories
ORDER  BY directory_name;
```

```sql
SELECT grantee, table_name AS directory_name, privilege
FROM   dba_tab_privs
WHERE  table_name IN (SELECT directory_name FROM dba_directories)
ORDER  BY table_name, grantee;
```

Dos statements — el primero inventaría los objetos `DIRECTORY`, el segundo sus grants (`DBA_
TAB_PRIVS` también cubre privilegios sobre objetos `DIRECTORY`, no sólo tablas — mismo mecanismo
que `Q-SEC-OBJECT-PRIVILEGES-001`). Nunca se navega el filesystem detrás del path.

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

N/A.

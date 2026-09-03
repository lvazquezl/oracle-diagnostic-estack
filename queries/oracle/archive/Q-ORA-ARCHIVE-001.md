---
query_id: Q-ORA-ARCHIVE-001
version: 1.1.0
domain: oracle
purpose: Configuración y estado de destinos de archivado

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$ARCHIVE_DEST, V$ARCHIVE_DEST_STATUS, V$ARCHIVED_LOG]
privileges_required: [SELECT on V$ARCHIVE_DEST, SELECT on V$ARCHIVE_DEST_STATUS, SELECT on V$ARCHIVED_LOG]

risk_class: R0
cost_class: LOW
timeout_seconds: 15
max_rows: 100
max_output_bytes: 65536

sensitivity: MEDIUM
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT d.dest_id, d.destination, s.status, s.error,
       (SELECT MAX(completion_time) FROM v$archived_log a WHERE a.dest_id = d.dest_id) AS last_archived
FROM   v$archive_dest d, v$archive_dest_status s
WHERE  d.dest_id = s.dest_id AND d.status != 'INACTIVE';
```

# Notes by version

Sin diferencias estructurales relevantes.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER` (corregido en Compatibility Hardening — era `CDB_ROOT`, valor inválido para 10g/11g donde Multitenant no existe; `V$ARCHIVE_DEST`/`V$ARCHIVE_DEST_STATUS`/`V$ARCHIVED_LOG` son CDB-wide, no `CON_ID`-scoped, y devuelven el mismo resultado desde `CDB$ROOT`, cualquier PDB o un target `NON_CDB`); el rol se restringe a `PRIMARY` porque el patrón de archivado activo es del sitio que genera redo.

# Cost classification rationale

`LOW`: número pequeño de destinos configurados (típicamente < 10).

# License notes

Ninguna.

# Sanitization notes

`destination` → MASK por defecto (puede revelar hostname/ruta remota).

# Evolution via `/change query`

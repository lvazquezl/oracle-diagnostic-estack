---
query_id: Q-ORA-REDO-001
version: 1.1.0
domain: oracle
purpose: Configuración de grupos y miembros de redo log

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$LOG, V$LOGFILE]
privileges_required: [SELECT on V$LOG, SELECT on V$LOGFILE]

risk_class: R0
cost_class: LOW
timeout_seconds: 10
max_rows: 200
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT l.thread#, l.group#, l.bytes, l.status,
       (SELECT COUNT(*) FROM v$logfile f WHERE f.group# = l.group#) AS member_count
FROM   v$log l
ORDER  BY l.thread#, l.group#;
```

# Notes by version

Sin diferencias estructurales relevantes.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER` (corregido en Compatibility Hardening — era `CDB_ROOT`, valor inválido para 10g/11g donde Multitenant no existe). Redo es CDB-wide, no `CON_ID`-scoped: `V$LOG`/`V$LOGFILE` devuelven el mismo resultado desde `CDB$ROOT`, cualquier PDB o un target `NON_CDB`.

# Cost classification rationale

`LOW`: número pequeño de grupos.

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP.

# Evolution via `/change query`

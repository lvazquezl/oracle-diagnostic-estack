---
query_id: Q-ORA-DB-STATE-001
version: 1.1.0
domain: oracle
purpose: Flags globales de V$DATABASE no cubiertos por discovery (flashback, guard, protection)

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$DATABASE]
privileges_required: [SELECT on V$DATABASE]

risk_class: R0
cost_class: LOW
timeout_seconds: 10
max_rows: 1
max_output_bytes: 4096

sensitivity: LOW
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT flashback_on, guard_status, protection_mode, protection_level,
       remote_archive, switchover_status
FROM   v$database;
```

# Notes by version

`FLASHBACK_ON`/`GUARD_STATUS` desde 10g. Sin cambios estructurales relevantes hasta 23ai.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER` (corregido en Compatibility Hardening — era `CDB_ROOT`, valor inválido para 10g/11g donde Multitenant no existe). `V$DATABASE` es CDB-wide, no `CON_ID`-scoped: devuelve el mismo resultado desde `CDB$ROOT`, cualquier PDB o un target `NON_CDB`.

# Cost classification rationale

`LOW`: una sola fila.

# License notes

Ninguna (Flashback Database no requiere Diagnostics/Tuning Pack).

# Sanitization notes

Todos los campos → KEEP (flags de estado, no identificadores).

# Evolution via `/change query`

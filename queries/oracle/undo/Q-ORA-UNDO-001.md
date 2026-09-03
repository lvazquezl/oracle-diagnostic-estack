---
query_id: Q-ORA-UNDO-001
version: 1.0.0
domain: oracle
purpose: Configuración y uso del tablespace UNDO activo

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$PARAMETER, DBA_TABLESPACES, V$UNDOSTAT]
privileges_required: [SELECT on V$PARAMETER, SELECT on DBA_TABLESPACES, SELECT on V$UNDOSTAT]

risk_class: R0
cost_class: LOW
timeout_seconds: 15
max_rows: 100
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
SELECT (SELECT value FROM v$parameter WHERE name='undo_tablespace') AS undo_tablespace,
       (SELECT value FROM v$parameter WHERE name='undo_retention') AS undo_retention,
       (SELECT MAX(tuned_undoretention) FROM v$undostat
        WHERE begin_time >= SYSDATE - 1/24) AS tuned_undoretention_last_hour;
```

# Notes by version

`V$UNDOSTAT` estable desde 9i; `undo_management` relevante como parámetro sólo hasta 11g.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER` — desde 18c puede haber PDB local undo, interpretado por el skill.

# Cost classification rationale

`LOW`: subqueries de una sola fila cada una.

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP.

# Evolution via `/change query`

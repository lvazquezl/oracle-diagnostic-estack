---
query_id: Q-ORA-CONTROLFILE-001
version: 1.1.0
domain: oracle
purpose: Multiplexado de controlfile y uso de record sections

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$CONTROLFILE, V$CONTROLFILE_RECORD_SECTION]
privileges_required: [SELECT on V$CONTROLFILE, SELECT on V$CONTROLFILE_RECORD_SECTION]

risk_class: R0
cost_class: LOW
timeout_seconds: 10
max_rows: 100
max_output_bytes: 32768

sensitivity: LOW
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT (SELECT COUNT(*) FROM v$controlfile) AS copies,
       type, records_used, records_total
FROM   v$controlfile_record_section
ORDER  BY records_used/NULLIF(records_total,0) DESC;
```

# Notes by version

Sin diferencias estructurales relevantes 10g–23ai.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER` (corregido en Compatibility Hardening — era `CDB_ROOT`, valor inválido para 10g/11g donde Multitenant no existe). El controlfile es una estructura física de instancia, no `CON_ID`-scoped: `V$CONTROLFILE`/`V$CONTROLFILE_RECORD_SECTION` devuelven el mismo resultado desde `CDB$ROOT`, cualquier PDB o un target `NON_CDB`.

# Cost classification rationale

`LOW`: número fijo y pequeño de record sections.

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP (no incluye rutas de archivo en esta query).

# Evolution via `/change query`

---
query_id: Q-DBA-TBS-DATAFILES-001
version: 1.0.0

domain: oracle
purpose: Detalle de datafiles y autoextend por tablespace

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_DATA_FILES]
privileges_required: [SELECT on DBA_DATA_FILES]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 20
max_rows: 2000
max_output_bytes: 524288

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT tablespace_name, file_name, bytes, autoextensible, maxbytes, increment_by
FROM   dba_data_files
ORDER  BY tablespace_name, file_name;
```

# Notes by version

Sin diferencias estructurales relevantes 10g–23ai.

# Notes by platform

`file_name` usa convención de ruta por plataforma (`/` vs `\`) o notación ASM (`+DATA/...`) — el collector no la reinterpreta, la reporta tal cual (sanitizada).

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`MEDIUM`: puede escalar a miles de datafiles en ambientes grandes — `max_rows` más generoso que otras queries de este dominio.

# License notes

Ninguna.

# Sanitization notes

`tablespace_name`/`file_name` → MASK por defecto.

# Evolution via `/change query`

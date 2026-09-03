---
query_id: Q-ORA-TEMP-001
version: 1.0.0
domain: oracle
purpose: Uso agregado y configuración de tempfiles

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_TEMP_FILES, DBA_TEMP_FREE_SPACE]
privileges_required: [SELECT on DBA_TEMP_FILES, SELECT on DBA_TEMP_FREE_SPACE]

risk_class: R0
cost_class: LOW
timeout_seconds: 15
max_rows: 200
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
SELECT f.tablespace_name, f.file_name, f.bytes, f.autoextensible, f.maxbytes,
       fs.tablespace_size, fs.free_space
FROM   dba_temp_files f, dba_temp_free_space fs
WHERE  f.tablespace_name = fs.tablespace_name;
```

# Notes by version

`DBA_TEMP_FREE_SPACE` estable desde 10g.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER` — el modo de TEMP (compartido/local por PDB) se interpreta en el skill, no en la query.

# Cost classification rationale

`LOW`: número pequeño de tempfiles.

# License notes

Ninguna.

# Sanitization notes

`file_name` → MASK por defecto.

# Evolution via `/change query`

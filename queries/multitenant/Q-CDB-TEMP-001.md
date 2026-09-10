---
query_id: Q-CDB-TEMP-001
version: 1.0.0

domain: multitenant
purpose: Uso de TEMP por PDB — presión de tempfile scoped por contenedor cuando la versión lo permite

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: CDB_ROOT_ONLY
database_role_scope: ANY

objects_accessed: [CDB_TEMP_FILES, GV$TEMP_SPACE_HEADER]
privileges_required: [SELECT on CDB_TEMP_FILES, SELECT on GV$TEMP_SPACE_HEADER]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 200
max_output_bytes: 32768

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_pdb_temp.sh, tests/test_multitenant_container_scope.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT f.con_id,
       f.tablespace_name,
       f.bytes            AS allocated_bytes,
       h.bytes_used,
       h.bytes_free
FROM   cdb_temp_files f
LEFT   JOIN gv$temp_space_header h
       ON  h.con_id = f.con_id AND h.tablespace_name = f.tablespace_name AND h.file_id = f.file_id
WHERE  f.con_id > 1
ORDER  BY f.con_id, f.tablespace_name;
```

`GV$TEMP_SPACE_HEADER` da uso real (`bytes_used`/`bytes_free`) por tempfile; `CDB_TEMP_FILES` da la asignación (`bytes`). El skill (`multitenant/pdb-temp`) correlaciona con `oracle-performance-analyst` si hay waits TEMP asociados (`# 18` del prompt) — esta query sólo aporta el lado de capacidad, no waits.

# Notes by version

`CDB_TEMP_FILES` desde 12.1 (mirror de `DBA_TEMP_FILES`, ya certificada en Oracle Core). `GV$TEMP_SPACE_HEADER` con `con_id` desde 12.1.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`CDB_ROOT_ONLY`. `database_role_scope: ANY`. `WHERE con_id > 1` excluye TEMP de CDB$ROOT (cubierto por `Q-ORA-TEMP-001` de Oracle Core si se necesita a nivel root).

# Cost classification rationale

`LOW` — acotado al número de tempfiles por PDB, típicamente pocos por contenedor.

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP (rutas de archivo no se seleccionan, sólo métricas).

# Evolution via `/change query`

N/A — vistas estables.

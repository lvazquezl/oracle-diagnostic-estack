---
query_id: Q-CDB-TEMP-001
version: 2.0.0

domain: multitenant
purpose: Uso de TEMP por PDB — presión de tempfile scoped por contenedor cuando la versión lo permite

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: CDB_ROOT_ONLY
database_role_scope: ANY

objects_accessed: [CDB_TEMP_FILES, CDB_TABLESPACES, GV$SORT_SEGMENT]
privileges_required: [SELECT on CDB_TEMP_FILES, SELECT on CDB_TABLESPACES, SELECT on GV$SORT_SEGMENT]

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
       f.allocated_bytes,
       s.used_blocks * t.block_size                      AS bytes_used,
       f.allocated_bytes - s.used_blocks * t.block_size  AS bytes_free
FROM   (SELECT con_id, tablespace_name, SUM(bytes) AS allocated_bytes
        FROM   cdb_temp_files
        WHERE  con_id > 1
        GROUP  BY con_id, tablespace_name) f
JOIN   cdb_tablespaces t
       ON  t.con_id = f.con_id AND t.tablespace_name = f.tablespace_name
LEFT   JOIN (SELECT con_id, tablespace_name, SUM(used_blocks) AS used_blocks
             FROM   gv$sort_segment
             GROUP  BY con_id, tablespace_name) s
       ON  s.con_id = f.con_id AND s.tablespace_name = f.tablespace_name
ORDER  BY f.con_id, f.tablespace_name;
```

**2.0.0 (`CHG-ESTACK-CDB-TEMP-USAGE-001`, breaking: una fila por tablespace TEMP de cada PDB, no por tempfile).**
- **Qué falló:** la 1.0.0 leía el uso de `GV$TEMP_SPACE_HEADER`, que **desde `CDB$ROOT` sólo expone el root**. Lo confirmó el DBA en el lab 19c (sólo `CON_ID` 1), y por eso el uso de las PDB llegaba `NULL` (`CHG-ESTACK-ORA19C-LAB-003`).
- **Uso:** `GV$SORT_SEGMENT`, que desde root sí expone las PDB (confirmado: `CON_ID` 1 y 3). `USED_BLOCKS × BLOCK_SIZE` del tablespace (`CDB_TABLESPACES`). `GV$` porque en RAC cada instancia tiene su propio segmento de ordenamiento: la suma es el uso total.
- **Libre:** `allocated_bytes − bytes_used`.
- **Sin segmento de ordenamiento** (TEMP sin uso desde el arranque de la instancia), `bytes_used`/`bytes_free` quedan `NULL`: la skill lo reporta `UNKNOWN`, nunca `LOW`.

`GV$TEMP_SPACE_HEADER` da uso real (`bytes_used`/`bytes_free`) por tempfile; `CDB_TEMP_FILES` da la asignación (`bytes`). El skill (`multitenant/pdb-temp`) correlaciona con `oracle-performance-analyst` si hay waits TEMP asociados (`# 18` del prompt) — esta query sólo aporta el lado de capacidad, no waits.

# Notes by version

`CDB_TEMP_FILES`/`CDB_TABLESPACES` desde 12.1. `GV$SORT_SEGMENT` con `CON_ID` desde 12.1.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`CDB_ROOT_ONLY`. `database_role_scope: ANY`. `WHERE con_id > 1` excluye TEMP de CDB$ROOT (cubierto por `Q-ORA-TEMP-001` de Oracle Core si se necesita a nivel root).

# Cost classification rationale

`LOW` — acotado al número de tablespaces TEMP por PDB.

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP (rutas de archivo no se seleccionan, sólo métricas).

# Evolution via `/change query`

N/A — vistas estables.

---
query_id: Q-ORA-TEMP-HWM-001
version: 1.0.0

domain: oracle
purpose: Pico de uso de TEMP desde el arranque por contenedor y tablespace temporal: segmento de ordenamiento, uso actual, máximo usado, ordenamiento más grande, tamaño asignado y máximo con autoextend

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [GV$SORT_SEGMENT, DBA_TABLESPACES, DBA_TEMP_FILES, CDB_TABLESPACES, CDB_TEMP_FILES]
privileges_required: [SELECT on GV$SORT_SEGMENT, SELECT on DBA_TABLESPACES, SELECT on DBA_TEMP_FILES, SELECT on CDB_TABLESPACES, SELECT on CDB_TEMP_FILES]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 200
max_output_bytes: 32768

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-ORA-TEMP-HWM-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_*)"
  - variant_id: Q-ORA-TEMP-HWM-001-V2
    label: cdb_aware_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_12plus, 12.1–23.0: CDB_* por contenedor)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_collector_factory.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_*)

```sql
SELECT s.tablespace_name,
       ROUND(SUM(s.total_blocks) * t.block_size / 1048576, 1) AS sort_segment_mb,
       ROUND(SUM(s.used_blocks) * t.block_size / 1048576, 1) AS used_mb,
       ROUND(SUM(s.max_used_blocks) * t.block_size / 1048576, 1) AS max_used_mb,
       ROUND(MAX(s.max_sort_blocks) * t.block_size / 1048576, 1) AS max_sort_mb,
       (SELECT ROUND(SUM(f.bytes) / 1048576, 1) FROM dba_temp_files f WHERE f.tablespace_name = s.tablespace_name) AS allocated_mb,
       (SELECT ROUND(SUM(GREATEST(f.bytes, NVL(f.maxbytes, 0))) / 1048576, 1) FROM dba_temp_files f WHERE f.tablespace_name = s.tablespace_name) AS max_size_mb
FROM   gv$sort_segment s
JOIN   dba_tablespaces t ON t.tablespace_name = s.tablespace_name
GROUP  BY s.tablespace_name, t.block_size
ORDER  BY s.tablespace_name;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_12plus, 12.1–23.0: CDB_* por contenedor)

```sql
SELECT s.con_id, s.tablespace_name,
       ROUND(SUM(s.total_blocks) * t.block_size / 1048576, 1) AS sort_segment_mb,
       ROUND(SUM(s.used_blocks) * t.block_size / 1048576, 1) AS used_mb,
       ROUND(SUM(s.max_used_blocks) * t.block_size / 1048576, 1) AS max_used_mb,
       ROUND(MAX(s.max_sort_blocks) * t.block_size / 1048576, 1) AS max_sort_mb,
       (SELECT ROUND(SUM(f.bytes) / 1048576, 1) FROM cdb_temp_files f WHERE f.con_id = s.con_id AND f.tablespace_name = s.tablespace_name) AS allocated_mb,
       (SELECT ROUND(SUM(GREATEST(f.bytes, NVL(f.maxbytes, 0))) / 1048576, 1) FROM cdb_temp_files f WHERE f.con_id = s.con_id AND f.tablespace_name = s.tablespace_name) AS max_size_mb
FROM   gv$sort_segment s
JOIN   cdb_tablespaces t ON t.con_id = s.con_id AND t.tablespace_name = s.tablespace_name
GROUP  BY s.con_id, s.tablespace_name, t.block_size
ORDER  BY s.con_id, s.tablespace_name;
```

# Notes by version

`MAX_USED_BLOCKS` y `MAX_SORT_BLOCKS` existen desde 10.2. `GV$SORT_SEGMENT.CON_ID` desde 12.1.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

Los máximos son desde el arranque de cada instancia: con pocas horas de uptime, el pico puede no ser representativo (cruzar con `uptime_hours`). Un tablespace temporal sin uso desde el arranque no tiene segmento y no aparece. En RAC cada instancia tiene su segmento: `max_used_mb` suma los picos de cada instancia (cota superior, no simultánea). Desde `CDB$ROOT`, `GV$SORT_SEGMENT` expone las PDB (verificado en el lab, `CHG-ESTACK-CDB-TEMP-USAGE-001`).

# Cost classification rationale

`LOW` — una fila por tablespace temporal e instancia.

# License notes

Ninguna.

# Sanitization notes

`tablespace_name` se enmascara. Nombres y rutas de tempfiles nunca se seleccionan: solo MB.

# Evolution via `/change query`

1.0.0 CHG-ESTACK-C-NEW-QUERIES-001: creación (lote C, cobertura del assessment).

---
query_id: Q-CDB-TABLESPACES-001
version: 1.0.0

domain: multitenant
purpose: Uso de tablespaces por PDB (used/free/autoextend/status/contents) — capacidad lógica de PDB, nunca capacidad física ASM subyacente

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: CDB_ROOT_ONLY
database_role_scope: ANY

objects_accessed: [CDB_TABLESPACE_USAGE_METRICS, CDB_TABLESPACES, CDB_DATA_FILES]
privileges_required: [SELECT on CDB_TABLESPACE_USAGE_METRICS, SELECT on CDB_TABLESPACES, SELECT on CDB_DATA_FILES]

risk_class: R0
cost_class: LOW

timeout_seconds: 20
max_rows: 500
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_pdb_tablespaces.sh, tests/test_multitenant_container_scope.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT m.con_id,
       m.tablespace_name,
       m.used_percent,
       m.used_space,
       m.tablespace_size,
       t.status,
       t.contents,
       CASE WHEN d.autoextensible = 'YES' THEN 'YES' ELSE 'NO' END AS autoextend
FROM   cdb_tablespace_usage_metrics m
JOIN   cdb_tablespaces t
       ON  t.con_id = m.con_id AND t.tablespace_name = m.tablespace_name
LEFT   JOIN cdb_data_files d
       ON  d.con_id = m.con_id AND d.tablespace_name = m.tablespace_name AND ROWNUM = 1
WHERE  m.con_id > 1
ORDER  BY m.con_id, m.tablespace_name;
```

Reutiliza el mismo modelo de `Q-DBA-TBS-USAGE-001` (Oracle Core, `DBA_TABLESPACE_USAGE_METRICS`) extendido a `CDB_*` con `con_id`. `t.contents` (`PERMANENT`/`TEMPORARY`/`UNDO`) distingue el tipo de tablespace — `multitenant/pdb-temp`/`pdb-undo` filtran por este campo en vez de duplicar la query. No agrega datafiles (`# 17`: no agregar datafiles).

# Notes by version

`CDB_TABLESPACE_USAGE_METRICS`/`CDB_TABLESPACES`/`CDB_DATA_FILES` disponibles desde 12.1 (mismas columnas base que sus contrapartes `DBA_*`, ya certificadas en Oracle Core, + `con_id`).

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`CDB_ROOT_ONLY`. `database_role_scope: ANY`. `WHERE con_id > 1` excluye tablespaces internos de CDB$ROOT del alcance de este análisis por-PDB (CDB$ROOT se cubre, si es necesario, reutilizando `Q-DBA-TBS-USAGE-001` directamente sobre el root).

# Cost classification rationale

`LOW` — acotado al número de tablespaces por PDB × número de PDBs, típicamente decenas a cientos, no miles.

# License notes

Ninguna.

# Sanitization notes

`tablespace_name` → KEEP (no sensible, nombres estándar). Métricas numéricas → KEEP.

# Evolution via `/change query`

Ampliación a nivel de datafile individual (rutas, autoextend por archivo) sólo vía `/change query` si un skill lo requiere — hoy `autoextend` se resume a nivel tablespace.

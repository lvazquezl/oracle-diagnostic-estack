---
query_id: Q-RMAN-BACKUP-SET-001
version: 1.0.0

domain: rman
purpose: Inventario de backup sets (tipo, nivel, controlfile/SPFILE incluido, tiempos, tamaño de piezas) — base de freshness/completeness

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$BACKUP_SET]
privileges_required: [SELECT on V$BACKUP_SET]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 20
max_rows: 500
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

# Verificado vía WebFetch (docs.oracle.com .../19/refrn/V-BACKUP_SET.html): RECID, STAMP,
# SET_STAMP, SET_COUNT, BACKUP_TYPE ('D'=full/incremental level 0*, 'I'=incremental, 'L'=archivelog),
# CONTROLFILE_INCLUDED, INCREMENTAL_LEVEL, PIECES, START_TIME, COMPLETION_TIME, ELAPSED_SECONDS,
# BLOCK_SIZE, ..., CON_ID (RAW GUID también presente). Vista pre-10g, certificada 10g-23ai. CON_ID
# aparece sólo 12.1+ (multitenant) — mismo patrón verificado que en la hardening de
# PDB_PLUG_IN_VIOLATIONS (Fase 6): nunca seleccionar una columna 12.1+ en una variante que declara
# soporte desde 10g. Dos variantes explícitas en vez de una SELECT * genérica, para que
# rman/multitenant-awareness tenga CDB/PDB backup scope real desde 12.1+ sin degradar la variante
# legacy (# 29 del prompt).
variants:
  - variant_id: Q-RMAN-BACKUP-SET-001-V1
    label: legacy_pre_multitenant
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: NOT_APPLICABLE
    sql_block: "Variant V1 (legacy_pre_multitenant, 10g-11g)"
  - variant_id: Q-RMAN-BACKUP-SET-001-V2
    label: multitenant_aware
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (multitenant_aware, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_backup_inventory_query.sh, tests/test_rman_query_version_compatibility.sh, tests/test_cdb_backup_awareness.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh, tests/test_rman_modern_variant_12c.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_pre_multitenant, 10g-11g)

```sql
SELECT *
FROM (
  SELECT recid, set_stamp, backup_type, incremental_level, controlfile_included,
         pieces, start_time, completion_time, elapsed_seconds
  FROM   v$backup_set
  ORDER  BY completion_time DESC
)
WHERE  ROWNUM <= 500;
```

# Statement / procedure (read-only) — Variant V2 (multitenant_aware, 12.1+)

```sql
SELECT recid, set_stamp, backup_type, incremental_level, controlfile_included,
       pieces, start_time, completion_time, elapsed_seconds, con_id
FROM   v$backup_set
ORDER  BY completion_time DESC
FETCH  FIRST 500 ROWS ONLY;
```

# Notes by version

`BACKUP_TYPE`: `D` = full o incremental level 0, `I` = incremental level 1, `L` = archivelog — el nivel real (0 vs. full) se distingue por `INCREMENTAL_LEVEL` (`NULL` = full, `0`/`1` = incremental), nunca por heurística de nombre de tag (`# 9` del prompt). `CON_ID` (0=whole CDB/non-CDB, 1=root, n=PDB) sólo en V2 — un target 10g/11g/12c non-CDB no tiene esa columna; V1 nunca la selecciona.

**PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING**: V1 (legacy_pre_multitenant, 10g-11g) usaba `FETCH FIRST ... ROWS ONLY` — sintaxis 12.1+, incompatible con su propio rango declarado. Corregido a `ROWNUM` sobre inline view ya ordenado. V2 (12.1+) no requirió cambios — `FETCH FIRST` es válido en su rango real. El split legacy/modern por columnas (`CON_ID`) ya existente se mantuvo sin rehacer (`# 10` del prompt de este hardening).

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

V1 `NOT_APPLICABLE` (Multitenant no existe). V2 `ANY_CONTAINER` — `CON_ID` discrimina el contenedor dueño del backup cuando aplica. `database_role_scope: ANY`.

# Cost classification rationale

`MEDIUM` — el histórico de backup sets crece con el tiempo; `FETCH FIRST 500 ROWS ONLY` y `time_window` opcional acotan (`# 35` del prompt).

# License notes

Ninguna.

# Sanitization notes

Ninguna columna directamente identificable — `V$BACKUP_PIECE` (query separada) es donde viven los `HANDLE` sensibles.

# Evolution via `/change query`

N/A — vista estable.

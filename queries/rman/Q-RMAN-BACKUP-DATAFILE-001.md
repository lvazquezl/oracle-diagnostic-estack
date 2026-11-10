---
query_id: Q-RMAN-BACKUP-DATAFILE-001
version: 2.0.0

domain: rman
purpose: Cobertura de backup de datafiles por contenedor: datafiles sin ningún backup, sin full/level 0 y el peor atraso del último backup — evidencia de restore readiness

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$DATAFILE, V$BACKUP_DATAFILE]
privileges_required: [SELECT on V$DATAFILE, SELECT on V$BACKUP_DATAFILE]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 20
max_rows: 200
max_output_bytes: 32768

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-RMAN-BACKUP-DATAFILE-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2: una fila para la base)"
  - variant_id: Q-RMAN-BACKUP-DATAFILE-001-V2
    label: cdb_aware_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_12plus, 12.1–23.0: una fila por contenedor)"

tests: [tests/test_no_write_operations.sh, tests/test_rman_query_version_compatibility.sh, tests/test_restore_readiness_missing_controlfile.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh, tests/test_rman_modern_variant_12c.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2: una fila para la base)

```sql
SELECT COUNT(*) AS datafiles,
       SUM(CASE WHEN b.last_backup IS NULL THEN 1 ELSE 0 END) AS datafiles_never_backed_up,
       SUM(CASE WHEN b.last_full IS NULL THEN 1 ELSE 0 END) AS datafiles_without_full,
       ROUND((SYSDATE - MIN(b.last_backup)) * 24, 2) AS max_hours_since_backup,
       ROUND((SYSDATE - MIN(b.last_full)) * 24, 2) AS max_hours_since_full
FROM   v$datafile d
LEFT   JOIN (SELECT file#, MAX(completion_time) AS last_backup,
                    MAX(CASE WHEN NVL(incremental_level, 0) = 0 THEN completion_time END) AS last_full
             FROM   v$backup_datafile
             WHERE  file# > 0
             GROUP  BY file#) b
       ON  b.file# = d.file#;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_12plus, 12.1–23.0: una fila por contenedor)

```sql
SELECT d.con_id,
       COUNT(*) AS datafiles,
       SUM(CASE WHEN b.last_backup IS NULL THEN 1 ELSE 0 END) AS datafiles_never_backed_up,
       SUM(CASE WHEN b.last_full IS NULL THEN 1 ELSE 0 END) AS datafiles_without_full,
       ROUND((SYSDATE - MIN(b.last_backup)) * 24, 2) AS max_hours_since_backup,
       ROUND((SYSDATE - MIN(b.last_full)) * 24, 2) AS max_hours_since_full
FROM   v$datafile d
LEFT   JOIN (SELECT file#, MAX(completion_time) AS last_backup,
                    MAX(CASE WHEN NVL(incremental_level, 0) = 0 THEN completion_time END) AS last_full
             FROM   v$backup_datafile
             WHERE  file# > 0
             GROUP  BY file#) b
       ON  b.file# = d.file#
GROUP  BY d.con_id
ORDER  BY d.con_id;
```

# Notes by version

`V$DATAFILE.CON_ID` desde 12.1. `INCREMENTAL_LEVEL` es nulo en un backup full no incremental y 0 en un level 0: ambos cuentan como full.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

Desde `CDB$ROOT` cubre todos los contenedores (incluida `PDB$SEED`). En un standby, los backups hechos en el primario no aparecen salvo catálogo compartido: un conteo alto de `datafiles_never_backed_up` en un standby no implica falta de backup.

# Cost classification rationale

`MEDIUM` — agrega `V$BACKUP_DATAFILE` (registros del controlfile) por datafile; devuelve una fila por contenedor.

# License notes

Ninguna.

# Sanitization notes

Solo conteos y horas por contenedor; nombres de archivo, `CHECKPOINT_CHANGE#` y fechas absolutas nunca se seleccionan. No cubre copias imagen (`V$DATAFILE_COPY`) ni backups registrados solo en un catálogo RMAN: se declaran como limitación.

# Evolution via `/change query`

2.0.0 CHG-ESTACK-B8-OPS-COVERAGE-001: de la lista de backups por datafile a la cobertura agregada por contenedor.

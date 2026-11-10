---
query_id: Q-RMAN-ARCHIVED-LOG-COVERAGE-001
version: 2.0.0

domain: rman
purpose: Cobertura de backup de archivelogs por thread de la encarnación actual: generados en 24 h, en disco, sin backup, antigüedad del más viejo sin backup y del último archivado — nunca mezcla threads

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$ARCHIVED_LOG, V$DATABASE]
privileges_required: [SELECT on V$ARCHIVED_LOG, SELECT on V$DATABASE]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 20
max_rows: 32
max_output_bytes: 16384

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-RMAN-ARCHIVED-LOG-COVERAGE-001-V1
    label: all_versions
    oracle_versions: {min: "10.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (all_versions, 10.2–23.0: agregado por THREAD#)"

tests: [tests/test_no_write_operations.sh, tests/test_rman_query_version_compatibility.sh, tests/test_dataguard_backup_offload_awareness.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh, tests/test_rman_modern_variant_12c.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (all_versions, 10.2–23.0: agregado por THREAD#)

```sql
SELECT thread# AS thread_no,
       SUM(CASE WHEN completed > SYSDATE - 1 THEN 1 ELSE 0 END) AS logs_last_24h,
       SUM(on_disk) AS logs_on_disk,
       SUM(CASE WHEN on_disk = 1 AND backups = 0 THEN 1 ELSE 0 END) AS logs_not_backed_up,
       ROUND((SYSDATE - MIN(CASE WHEN on_disk = 1 AND backups = 0 THEN completed END)) * 24, 2) AS hours_since_oldest_not_backed_up,
       ROUND((SYSDATE - MAX(completed)) * 24, 2) AS hours_since_last_archived
FROM  (SELECT thread#, sequence#, MAX(completion_time) AS completed, MAX(backup_count) AS backups,
              MAX(CASE WHEN deleted = 'NO' AND status = 'A' THEN 1 ELSE 0 END) AS on_disk
       FROM   v$archived_log
       WHERE  standby_dest = 'NO'
         AND  resetlogs_change# = (SELECT resetlogs_change# FROM v$database)
       GROUP  BY thread#, sequence#)
GROUP  BY thread#
ORDER  BY thread#;
```

# Notes by version

Columnas estables desde 10.2. Una sola variante: el agregado no usa `FETCH FIRST`.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`V$ARCHIVED_LOG` es de la CDB: en una CDB las filas son de todo el contenedor raíz (no hay archivelogs por PDB). `database_role_scope: ANY`; en un standby las copias recibidas se excluyen con `standby_dest = 'NO'` solo para los destinos remotos del primario.

# Cost classification rationale

`MEDIUM` — recorre los registros del controlfile de archivelogs (miles en un ambiente activo), pero agrega en la base y devuelve una fila por thread.

# License notes

Ninguna.

# Sanitization notes

Solo conteos y horas por thread. `NAME` (ruta del archivelog) y las fechas absolutas nunca se seleccionan. Cada secuencia se cuenta una vez aunque tenga varias copias locales; nunca mezcla threads: `THREAD#` agrupa y las secuencias solo se comparan dentro del mismo thread. Solo la encarnación actual (`RESETLOGS_CHANGE#` de `V$DATABASE`).

# Evolution via `/change query`

2.0.0 CHG-ESTACK-B8-OPS-COVERAGE-001: agregado por thread en la base (sin rutas ni fechas, sin lista por secuencia), incluye la cobertura de `Q-RMAN-ARCHIVELOG-BACKUP-001` (`BACKUP_COUNT`).

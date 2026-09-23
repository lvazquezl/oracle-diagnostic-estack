---
query_id: Q-RMAN-BACKUP-FRESHNESS-001
version: 1.0.0

domain: rman
purpose: Frescura de backups por categoría (full/level 0, incremental, archivelog, controlfile, SPFILE) como horas desde el último backup registrado — antigüedad calculada en la base, nunca fechas absolutas

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$BACKUP_DATAFILE, V$BACKUP_SET, V$BACKUP_SPFILE]
privileges_required: [SELECT on V$BACKUP_DATAFILE, SELECT on V$BACKUP_SET, SELECT on V$BACKUP_SPFILE]

risk_class: R0
cost_class: LOW

timeout_seconds: 20
max_rows: 10
max_output_bytes: 4096

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

# CHG-ESTACK-ORA19C-LAB-004 (lote 2 RMAN, opción C): las vistas V$BACKUP_* exponen fechas DATE (hora
# local del servidor, sin zona horaria). En vez de exportarlas, la base calcula la antigüedad contra
# SYSDATE (mismo reloj): no hay conversión de zona ni fecha absoluta que interpretar. Sin Top-N ni
# CON_ID: la misma sentencia es válida 10g-23ai (variante única con max explícito, # 5 de Fase 7).
variants:
  - variant_id: Q-RMAN-BACKUP-FRESHNESS-001-V1
    label: all_versions
    oracle_versions: {min: "10.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (all_versions, 10g-23ai)"

tests: [tests/test_no_write_operations.sh, tests/test_rman_query_version_compatibility.sh, tests/test_rman_query_cost.sh, tests/test_sql_static_validator.sh, tests/test_p15_oracle_lab_adapter.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (all_versions, 10g-23ai)

```sql
SELECT 'FULL_OR_LEVEL0' AS backup_kind, COUNT(*) AS record_count,
       ROUND((SYSDATE - MAX(completion_time)) * 24, 2) AS hours_since_last
FROM   v$backup_datafile
WHERE  file# > 0 AND NVL(incremental_level, 0) = 0
UNION ALL
SELECT 'INCREMENTAL', COUNT(*), ROUND((SYSDATE - MAX(completion_time)) * 24, 2)
FROM   v$backup_datafile
WHERE  file# > 0 AND incremental_level > 0
UNION ALL
SELECT 'ARCHIVELOG', COUNT(*), ROUND((SYSDATE - MAX(completion_time)) * 24, 2)
FROM   v$backup_set
WHERE  backup_type = 'L'
UNION ALL
SELECT 'CONTROLFILE', COUNT(*), ROUND((SYSDATE - MAX(completion_time)) * 24, 2)
FROM   v$backup_set
WHERE  controlfile_included IN ('YES', 'SBY')
UNION ALL
SELECT 'SPFILE', COUNT(*), ROUND((SYSDATE - MAX(completion_time)) * 24, 2)
FROM   v$backup_spfile;
```

Siempre 5 filas, una por categoría. Una categoría sin backups registrados devuelve `record_count = 0` y `hours_since_last = NULL`: la ausencia es explícita, nunca una fila faltante.

- `FULL_OR_LEVEL0` / `INCREMENTAL` se derivan de `V$BACKUP_DATAFILE` (`FILE# > 0` excluye el controlfile) por `INCREMENTAL_LEVEL`: `NULL`/`0` = full o level 0, `> 0` = incremental. Un backup set que sólo contiene controlfile/SPFILE (p. ej. autobackup) **no** cuenta como full (# 9 de Fase 7: nunca por heurística de TAG).
- `ARCHIVELOG` se deriva de `V$BACKUP_SET` con `BACKUP_TYPE = 'L'` (backup sets de archivelogs). **No** de `V$BACKUP_REDOLOG`: esa vista no tiene `COMPLETION_TIME` (Oracle Database Reference 19c, verificado en la validación en el lab: la primera versión de esta query falló en Oracle real).
- `record_count` cuenta registros (datafiles × backups, backup sets de archivelog, sets con controlfile, backups de SPFILE), no jobs.

# Notes by version

Todas las vistas y columnas son pre-10g (`compatibility/oracle-dictionary/views.yaml`); `SYSDATE`, `NVL`, `ROUND`, `UNION ALL` y agregados son SQL estándar de Oracle en todo el rango. No usa `FETCH FIRST`/`OFFSET` ni `CON_ID`.

# Notes by platform

Ninguna. `SYSDATE` y las fechas de las vistas vienen del mismo reloj del servidor: la antigüedad no depende de la zona horaria del cliente ni de la del servidor. Imprecisión conocida: si hubo un cambio de horario de verano entre el backup y la colección, la antigüedad puede diferir ±1 h (irrelevante para ventanas de frescura en horas/días).

# Container / role scope notes

`ANY_CONTAINER`, como el resto de `Q-RMAN-*`. Desde `CDB$ROOT` o una non-CDB se ven los backups de toda la base. **Desde una PDB las vistas `V$BACKUP_*` se filtran a ese contenedor** y el resultado puede subestimar la frescura: el gateway lab lo ejecuta desde `CDB$ROOT` (`CHG-ESTACK-ORA19C-LAB-002`/`-003`). `database_role_scope: ANY`: el controlfile de un standby registra sus propios backups.

# Cost classification rationale

`LOW`: 5 agregados sobre vistas del controlfile, acotadas por `CONTROL_FILE_RECORD_KEEP_TIME`; salida fija de 5 filas.

# License notes

Ninguna: vistas `V$` de RMAN estándar, sin Diagnostics/Tuning Pack ni Recovery Catalog.

# Sanitization notes

Todos los campos → KEEP (`backup_kind` es un literal de la query, `record_count` y `hours_since_last` son números). No se leen `HANDLE`, `TAG`, rutas ni nombres de datafile.

# Limitations

Mide backups **registrados** en el controlfile, aunque sus piezas se hayan borrado o marcado `EXPIRED` después; la disponibilidad real para restore es `rman/restore-readiness`. No reemplaza un Recovery Catalog con historia más larga que `CONTROL_FILE_RECORD_KEEP_TIME`.

# Evolution via `/change query`

Una fecha absoluta (para timelines de RCA) requiere un tipo de campo con zona declarada (`CHG-REQ-LAB-RMAN-TIMESTAMPS`, opción A/D), nunca una conversión implícita.

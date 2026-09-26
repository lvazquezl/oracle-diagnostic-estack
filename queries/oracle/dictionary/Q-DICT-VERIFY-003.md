---
query_id: Q-DICT-VERIFY-003
version: 1.0.0

domain: oracle
purpose: "Verificación del diccionario del e-stack contra el catálogo real (parte 3/5: V$ARCHIVED_LOG.SEQUENCE# … V$DATABASE.NAME) — la base compara y devuelve sólo discrepancias"

supported_oracle_versions: [19c]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_TAB_COLUMNS]
privileges_required: [SELECT on DBA_TAB_COLUMNS]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 30
max_rows: 120
max_output_bytes: 16384

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

# GENERADO por scripts/dict_verify/generate.py desde compatibility/oracle-dictionary/views.yaml — NO editar a mano.
# CHG-ESTACK-ORA19C-LAB-006. La lista embebida es la del diccionario para 19c; otra versión requiere su propia
# variante generada (CHG-REQ-LAB-MULTIVERSION).
variants:
  - variant_id: Q-DICT-VERIFY-003-V1
    label: oracle_19c
    oracle_versions: {min: "19.0", max: "19.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (oracle_19c, generated)"

tests: [tests/test_no_write_operations.sh, tests/test_sql_static_validator.sh, tests/test_dict_verify_queries_match_dictionary.sh, tests/test_p15_oracle_lab_adapter.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (oracle_19c, generated)

```sql
WITH s AS (SELECT 'V$ARCHIVED_LOG.SEQUENCE# V$ARCHIVED_LOG.THREAD# V$ARCHIVE_DEST.* V$ARCHIVE_DEST.AFFIRM V$ARCHIVE_DEST.ARCHIVER V$ARCHIVE_DEST.DEST_ID V$ARCHIVE_DEST.DEST_NAME V$ARCHIVE_DEST.STATUS V$ARCHIVE_DEST.TARGET V$ARCHIVE_DEST.TRANSMIT_MODE V$ARCHIVE_DEST.VALID_NOW V$ARCHIVE_DEST_STATUS.* V$ARCHIVE_DEST_STATUS.DEST_ID V$ARCHIVE_DEST_STATUS.ERROR V$ARCHIVE_DEST_STATUS.RECOVERY_MODE V$ARCHIVE_DEST_STATUS.STATUS V$ARCHIVE_GAP.* V$ARCHIVE_GAP.HIGH_SEQUENCE# V$ARCHIVE_GAP.LOW_SEQUENCE# V$ARCHIVE_GAP.THREAD# V$ASM_DISK.* V$ASM_DISK.FAILGROUP V$ASM_DISK.HEADER_STATUS V$ASM_DISK.MODE_STATUS V$ASM_DISK.MOUNT_STATUS V$ASM_DISK.PATH V$ASM_DISK.READ_ERRS V$ASM_DISK.STATE V$ASM_DISK.WRITE_ERRS V$ASM_DISKGROUP.* V$ASM_DISKGROUP_STAT.* V$ASM_OPERATION.* V$BACKUP_DATAFILE.* V$BACKUP_DATAFILE.BLOCKS V$BACKUP_DATAFILE.BLOCK_SIZE V$BACKUP_DATAFILE.CHECKPOINT_TIME V$BACKUP_DATAFILE.COMPLETION_TIME V$BACKUP_DATAFILE.FILE# V$BACKUP_DATAFILE.INCREMENTAL_LEVEL V$BACKUP_DATAFILE.USED_CHANGE_TRACKING V$BACKUP_DEVICE.* V$BACKUP_DEVICE.DEVICE_NAME V$BACKUP_DEVICE.DEVICE_TYPE V$BACKUP_DEVICE.PHYSICAL_DEVICE_NAME V$BACKUP_PIECE.* V$BACKUP_PIECE.BYTES V$BACKUP_PIECE.COMPLETION_TIME V$BACKUP_PIECE.DEVICE_TYPE V$BACKUP_PIECE.HANDLE V$BACKUP_PIECE.RECID V$BACKUP_PIECE.SET_STAMP V$BACKUP_PIECE.STATUS V$BACKUP_PIECE.TAG V$BACKUP_REDOLOG.* V$BACKUP_REDOLOG.COMPLETION_TIME V$BACKUP_REDOLOG.FIRST_TIME V$BACKUP_REDOLOG.NEXT_TIME V$BACKUP_REDOLOG.SEQUENCE# V$BACKUP_REDOLOG.THREAD# V$BACKUP_SET.* V$BACKUP_SET.BACKUP_TYPE V$BACKUP_SET.COMPLETION_TIME V$BACKUP_SET.CONTROLFILE_INCLUDED V$BACKUP_SET.CON_ID V$BACKUP_SET.ELAPSED_SECONDS V$BACKUP_SET.INCREMENTAL_LEVEL V$BACKUP_SET.PIECES V$BACKUP_SET.RECID V$BACKUP_SET.SET_STAMP V$BACKUP_SET.START_TIME V$BACKUP_SPFILE.* V$BACKUP_SPFILE.COMPLETION_TIME V$BACKUP_SPFILE.MODIFICATION_TIME V$BACKUP_SPFILE.RECID V$BACKUP_SPFILE.SET_STAMP V$CONTAINERS.* V$CONTAINERS.CON_ID V$CONTAINERS.NAME V$CONTAINERS.OPEN_MODE V$CONTROLFILE.* V$CONTROLFILE_RECORD_SECTION.* V$CONTROLFILE_RECORD_SECTION.RECORDS_TOTAL V$CONTROLFILE_RECORD_SECTION.RECORDS_USED V$CONTROLFILE_RECORD_SECTION.RECORD_SIZE V$CONTROLFILE_RECORD_SECTION.TYPE V$DATABASE.* V$DATABASE.CDB V$DATABASE.DATABASE_ROLE V$DATABASE.DB_UNIQUE_NAME V$DATABASE.FLASHBACK_ON V$DATABASE.FORCE_LOGGING V$DATABASE.GUARD_STATUS V$DATABASE.LOG_MODE V$DATABASE.NAME' AS l FROM dual),
e AS (SELECT REGEXP_SUBSTR(l, '[^ ]+', 1, LEVEL) AS p FROM s CONNECT BY LEVEL <= REGEXP_COUNT(l, '[^ ]+')),
x AS (SELECT SUBSTR(p, 1, INSTR(p, '.') - 1) AS view_name, SUBSTR(p, INSTR(p, '.') + 1) AS column_name,
             REPLACE(SUBSTR(p, 1, INSTR(p, '.') - 1), 'V$', 'V_$') AS object_name FROM e)
SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM dba_tab_columns d WHERE d.owner IN ('SYS', 'AUDSYS', 'PERFSTAT') AND d.table_name = x.object_name)
            THEN 'VIEW_NOT_FOUND' ELSE 'COLUMN_NOT_FOUND' END AS finding,
       x.view_name, x.column_name, CAST(1 AS NUMBER(10)) AS tokens
FROM   x
WHERE  NOT EXISTS (SELECT 1 FROM dba_tab_columns d WHERE d.owner IN ('SYS', 'AUDSYS', 'PERFSTAT') AND d.table_name = x.object_name
                   AND (x.column_name = '*' OR d.column_name = x.column_name))
UNION ALL
SELECT 'CHECKED', '*', '*', CAST(COUNT(*) AS NUMBER(10)) FROM x;
```

Parte 3 de 5: 94 tokens `VISTA.COLUMNA` (o `VISTA.*` = la vista misma) sobre 18 vistas. Devuelve una fila
por token **no encontrado** (`VIEW_NOT_FOUND` si la vista no existe para los owners `SYS`, `AUDSYS`, `PERFSTAT`; si no,
`COLUMN_NOT_FOUND`) y siempre una fila `CHECKED` con el total de tokens verificados. Un diccionario correcto responde
sólo la fila `CHECKED`.

- `V$X`/`GV$X` se buscan por su objeto real `V_$X`/`GV_$X` (las `V$` son sinónimos públicos).
- La comparación ocurre en la base: la respuesta nunca contiene el catálogo, sólo discrepancias.

# Notes by version

Generada para 19c (`min_version` ≤ 19 en el diccionario). `REGEXP_SUBSTR`/`REGEXP_COUNT` existen desde 11g.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`. El lab la ejecuta desde `CDB$ROOT`, donde viven los objetos de `SYS`.

# Cost classification rationale

`MEDIUM`: 94 búsquedas por nombre en el catálogo (`owner`, `table_name`), sin datos de aplicación.

# License notes

Ninguna.

# Sanitization notes

`finding`, `view_name` y `column_name` son **enums** cuyos valores permitidos son exactamente los de esta parte del
diccionario: KEEP sin riesgo, y cualquier otro valor se descarta. `tokens` es un entero.

# Limitations

Sólo verifica que lo declarado exista (no detecta columnas reales ausentes de listas exhaustivas). No incluye
tokens que el guard de solo lectura rechazaría por contener palabras reservadas (hoy: `V$LOCK`).

# Evolution via `/change query`

Se regenera con `python3 -m scripts.dict_verify.generate --write` al cambiar el diccionario.

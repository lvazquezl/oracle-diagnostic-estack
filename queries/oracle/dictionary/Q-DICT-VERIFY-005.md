---
query_id: Q-DICT-VERIFY-005
version: 1.0.0

domain: oracle
purpose: "Verificación del diccionario del e-stack contra el catálogo real (parte 5/5: V$RECOVERY_FILE_DEST.NAME … V$UNDOSTAT.*) — la base compara y devuelve sólo discrepancias"

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
  - variant_id: Q-DICT-VERIFY-005-V1
    label: oracle_19c
    oracle_versions: {min: "19.0", max: "19.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (oracle_19c, generated)"

tests: [tests/test_no_write_operations.sh, tests/test_sql_static_validator.sh, tests/test_dict_verify_queries_match_dictionary.sh, tests/test_p15_oracle_lab_adapter.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (oracle_19c, generated)

```sql
WITH s AS (SELECT 'V$RECOVERY_FILE_DEST.NAME V$RECOVERY_FILE_DEST.NUMBER_OF_FILES V$RECOVERY_FILE_DEST.SPACE_LIMIT V$RECOVERY_FILE_DEST.SPACE_RECLAIMABLE V$RECOVERY_FILE_DEST.SPACE_USED V$RECOVERY_PROGRESS.* V$RESOURCE_LIMIT.* V$RMAN_BACKUP_JOB_DETAILS.* V$RMAN_BACKUP_JOB_DETAILS.COMPRESSION_RATIO V$RMAN_BACKUP_JOB_DETAILS.CON_ID V$RMAN_BACKUP_JOB_DETAILS.ELAPSED_SECONDS V$RMAN_BACKUP_JOB_DETAILS.END_TIME V$RMAN_BACKUP_JOB_DETAILS.INPUT_BYTES V$RMAN_BACKUP_JOB_DETAILS.INPUT_BYTES_PER_SEC V$RMAN_BACKUP_JOB_DETAILS.INPUT_TYPE V$RMAN_BACKUP_JOB_DETAILS.OUTPUT_BYTES V$RMAN_BACKUP_JOB_DETAILS.OUTPUT_BYTES_PER_SEC V$RMAN_BACKUP_JOB_DETAILS.SESSION_KEY V$RMAN_BACKUP_JOB_DETAILS.START_TIME V$RMAN_BACKUP_JOB_DETAILS.STATUS V$RMAN_CONFIGURATION.* V$RMAN_CONFIGURATION.CONF# V$RMAN_CONFIGURATION.CON_ID V$RMAN_CONFIGURATION.NAME V$RMAN_CONFIGURATION.VALUE V$RMAN_OUTPUT.* V$RMAN_OUTPUT.CON_ID V$RMAN_OUTPUT.GUID V$RMAN_OUTPUT.OUTPUT V$RMAN_OUTPUT.RECID V$RMAN_OUTPUT.SESSION_RECID V$RMAN_OUTPUT.SID V$RMAN_STATUS.* V$RMAN_STATUS.CON_ID V$RMAN_STATUS.END_TIME V$RMAN_STATUS.INPUT_BYTES V$RMAN_STATUS.OBJECT_TYPE V$RMAN_STATUS.OPERATION V$RMAN_STATUS.OUTPUT_BYTES V$RMAN_STATUS.OUTPUT_DEVICE_TYPE V$RMAN_STATUS.RECID V$RMAN_STATUS.ROW_TYPE V$RMAN_STATUS.SESSION_RECID V$RMAN_STATUS.SESSION_STAMP V$RMAN_STATUS.SID V$RMAN_STATUS.STAMP V$RMAN_STATUS.START_TIME V$RMAN_STATUS.STATUS V$ROWCACHE.* V$RSRCPDBMETRIC.* V$RSRCPDBMETRIC.AVG_ACTIVE_PARALLEL_SERVERS V$RSRCPDBMETRIC.AVG_CPU_UTILIZATION V$RSRCPDBMETRIC.AVG_QUEUED_PARALLEL_SERVERS V$RSRCPDBMETRIC.AVG_RUNNING_SESSIONS V$RSRCPDBMETRIC.AVG_WAITING_SESSIONS V$RSRCPDBMETRIC.CON_ID V$RSRCPDBMETRIC.CPU_CONSUMED_TIME V$RSRCPDBMETRIC.CPU_UTILIZATION_LIMIT V$RSRCPDBMETRIC.CPU_WAIT_TIME V$RSRCPDBMETRIC.IOMBPS V$RSRCPDBMETRIC.IOPS V$RSRCPDBMETRIC.NUM_CPUS V$RSRCPDBMETRIC.PARALLEL_SERVERS_LIMIT V$RSRCPDBMETRIC.PGA_BYTES V$RSRCPDBMETRIC.PLAN_NAME V$RSRCPDBMETRIC.RUNNING_SESSIONS_LIMIT V$RSRCPDBMETRIC.SGA_BYTES V$SESSION.* V$SESSION.BLOCKING_SESSION V$SESSION.CON_ID V$SESSION.LAST_CALL_ET V$SESSION.SQL_ID V$SESSION.STATUS V$SESSION.TYPE V$SGA.* V$SGAINFO.* V$SGASTAT.* V$SORT_USAGE.* V$SPPARAMETER.* V$SQLSTATS.* V$SQL_PLAN.* V$STANDBY_LOG.* V$STANDBY_LOG.BYTES V$STANDBY_LOG.GROUPS V$STANDBY_LOG.STATUS V$STANDBY_LOG.THREAD# V$SYSSTAT.* V$SYSTEM_EVENT.* V$SYS_TIME_MODEL.* V$TABLESPACE.* V$TEMP_SPACE_HEADER.* V$UNDOSTAT.*' AS l FROM dual),
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

Parte 5 de 5: 92 tokens `VISTA.COLUMNA` (o `VISTA.*` = la vista misma) sobre 24 vistas. Devuelve una fila
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

`MEDIUM`: 92 búsquedas por nombre en el catálogo (`owner`, `table_name`), sin datos de aplicación.

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

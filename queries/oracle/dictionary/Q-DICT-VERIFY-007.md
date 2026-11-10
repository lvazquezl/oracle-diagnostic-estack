---
query_id: Q-DICT-VERIFY-007
version: 1.0.0

domain: oracle
purpose: "Verificación del diccionario del e-stack contra el catálogo real (parte 7/7: V$RMAN_BACKUP_JOB_DETAILS.STATUS … V$VERSION.BANNER) — la base compara y devuelve sólo discrepancias"

supported_oracle_versions: [19c]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_TAB_COLUMNS, DBA_SYNONYMS]
privileges_required: [SELECT on DBA_TAB_COLUMNS, SELECT on DBA_SYNONYMS]

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
  - variant_id: Q-DICT-VERIFY-007-V1
    label: oracle_19c
    oracle_versions: {min: "19.0", max: "19.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (oracle_19c, generated)"

tests: [tests/test_no_write_operations.sh, tests/test_sql_static_validator.sh, tests/test_dict_verify_queries_match_dictionary.sh, tests/test_p15_oracle_lab_adapter.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (oracle_19c, generated)

```sql
WITH s AS (SELECT 'V$RMAN_BACKUP_JOB_DETAILS.STATUS V$RMAN_CONFIGURATION.* V$RMAN_CONFIGURATION.CONF# V$RMAN_CONFIGURATION.CON_ID V$RMAN_CONFIGURATION.NAME V$RMAN_CONFIGURATION.VALUE V$RMAN_OUTPUT.* V$RMAN_OUTPUT.CON_ID V$RMAN_OUTPUT.GUID V$RMAN_OUTPUT.OUTPUT V$RMAN_OUTPUT.RECID V$RMAN_OUTPUT.SESSION_RECID V$RMAN_OUTPUT.SID V$RMAN_STATUS.* V$RMAN_STATUS.CON_ID V$RMAN_STATUS.END_TIME V$RMAN_STATUS.INPUT_BYTES V$RMAN_STATUS.OBJECT_TYPE V$RMAN_STATUS.OPERATION V$RMAN_STATUS.OUTPUT_BYTES V$RMAN_STATUS.OUTPUT_DEVICE_TYPE V$RMAN_STATUS.RECID V$RMAN_STATUS.ROW_TYPE V$RMAN_STATUS.SESSION_RECID V$RMAN_STATUS.SESSION_STAMP V$RMAN_STATUS.SID V$RMAN_STATUS.STAMP V$RMAN_STATUS.START_TIME V$RMAN_STATUS.STATUS V$ROWCACHE.* V$RSRCPDBMETRIC.* V$RSRCPDBMETRIC.AVG_ACTIVE_PARALLEL_SERVERS V$RSRCPDBMETRIC.AVG_CPU_UTILIZATION V$RSRCPDBMETRIC.AVG_QUEUED_PARALLEL_SERVERS V$RSRCPDBMETRIC.AVG_RUNNING_SESSIONS V$RSRCPDBMETRIC.AVG_WAITING_SESSIONS V$RSRCPDBMETRIC.CON_ID V$RSRCPDBMETRIC.CPU_CONSUMED_TIME V$RSRCPDBMETRIC.CPU_UTILIZATION_LIMIT V$RSRCPDBMETRIC.CPU_WAIT_TIME V$RSRCPDBMETRIC.IOMBPS V$RSRCPDBMETRIC.IOPS V$RSRCPDBMETRIC.NUM_CPUS V$RSRCPDBMETRIC.PARALLEL_SERVERS_LIMIT V$RSRCPDBMETRIC.PGA_BYTES V$RSRCPDBMETRIC.PLAN_NAME V$RSRCPDBMETRIC.RUNNING_SESSIONS_LIMIT V$RSRCPDBMETRIC.SGA_BYTES V$RSRC_PLAN.* V$RSRC_PLAN.CON_ID V$RSRC_PLAN.IS_TOP_PLAN V$RSRC_PLAN.NAME V$SESSION.* V$SESSION.BLOCKING_SESSION V$SESSION.CON_ID V$SESSION.LAST_CALL_ET V$SESSION.SQL_ID V$SESSION.STATUS V$SESSION.TYPE V$SGA.* V$SGAINFO.* V$SGASTAT.* V$SGA_DYNAMIC_COMPONENTS.* V$SGA_DYNAMIC_COMPONENTS.COMPONENT V$SGA_DYNAMIC_COMPONENTS.CURRENT_SIZE V$SGA_DYNAMIC_COMPONENTS.LAST_OPER_TIME V$SGA_DYNAMIC_COMPONENTS.LAST_OPER_TYPE V$SGA_DYNAMIC_COMPONENTS.MAX_SIZE V$SGA_DYNAMIC_COMPONENTS.MIN_SIZE V$SGA_DYNAMIC_COMPONENTS.OPER_COUNT V$SGA_DYNAMIC_COMPONENTS.USER_SPECIFIED_SIZE V$SORT_SEGMENT.* V$SORT_SEGMENT.CON_ID V$SORT_SEGMENT.TABLESPACE_NAME V$SORT_SEGMENT.TOTAL_BLOCKS V$SORT_SEGMENT.USED_BLOCKS V$SORT_USAGE.* V$SPPARAMETER.* V$SQLSTATS.* V$SQL_PLAN.* V$SQL_WORKAREA_HISTOGRAM.* V$SQL_WORKAREA_HISTOGRAM.MULTIPASSES_EXECUTIONS V$SQL_WORKAREA_HISTOGRAM.ONEPASS_EXECUTIONS V$SQL_WORKAREA_HISTOGRAM.OPTIMAL_EXECUTIONS V$STANDBY_LOG.* V$STANDBY_LOG.BYTES V$STANDBY_LOG.GROUP# V$STANDBY_LOG.STATUS V$STANDBY_LOG.THREAD# V$SYSSTAT.* V$SYSTEM_EVENT.* V$SYS_TIME_MODEL.* V$TABLESPACE.* V$TEMP_SPACE_HEADER.* V$UNDOSTAT.* V$UNDOSTAT.ACTIVEBLKS V$UNDOSTAT.BEGIN_TIME V$UNDOSTAT.CON_ID V$UNDOSTAT.EXPIREDBLKS V$UNDOSTAT.EXPSTEALCNT V$UNDOSTAT.MAXCONCURRENCY V$UNDOSTAT.MAXQUERYLEN V$UNDOSTAT.NOSPACEERRCNT V$UNDOSTAT.SSOLDERRCNT V$UNDOSTAT.TUNED_UNDORETENTION V$UNDOSTAT.UNDOBLKS V$UNDOSTAT.UNEXPIREDBLKS V$UNDOSTAT.UNXPSTEALCNT V$VERSION.* V$VERSION.BANNER' AS l FROM dual),
e AS (SELECT REGEXP_SUBSTR(l, '[^ ]+', 1, LEVEL) AS p FROM s CONNECT BY LEVEL <= REGEXP_COUNT(l, '[^ ]+')),
x AS (SELECT SUBSTR(p, 1, INSTR(p, '.') - 1) AS view_name, SUBSTR(p, INSTR(p, '.') + 1) AS column_name FROM e),
o AS (SELECT x.view_name, x.column_name, NVL(y.table_owner, '-') AS obj_owner, NVL(y.table_name, x.view_name) AS obj_name
      FROM x LEFT JOIN dba_synonyms y ON y.owner = 'PUBLIC' AND y.synonym_name = x.view_name AND y.table_owner IN ('SYS', 'AUDSYS', 'PERFSTAT'))
SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM dba_tab_columns d WHERE d.owner IN ('SYS', 'AUDSYS', 'PERFSTAT') AND d.table_name = o.obj_name
                             AND (o.obj_owner = '-' OR d.owner = o.obj_owner))
            THEN 'VIEW_NOT_FOUND' ELSE 'COLUMN_NOT_FOUND' END AS finding,
       o.view_name, o.column_name, CAST(1 AS NUMBER(10)) AS tokens
FROM   o
WHERE  NOT EXISTS (SELECT 1 FROM dba_tab_columns d WHERE d.owner IN ('SYS', 'AUDSYS', 'PERFSTAT') AND d.table_name = o.obj_name
                   AND (o.obj_owner = '-' OR d.owner = o.obj_owner) AND (o.column_name = '*' OR d.column_name = o.column_name))
UNION ALL
SELECT 'CHECKED', '*', '*', CAST(COUNT(*) AS NUMBER(10)) FROM o;
```

Parte 7 de 7: 110 tokens `VISTA.COLUMNA` (o `VISTA.*` = la vista misma) sobre 26 vistas. Devuelve una fila
por token **no encontrado** (`VIEW_NOT_FOUND` si la vista no existe para los owners `SYS`, `AUDSYS`, `PERFSTAT`; si no,
`COLUMN_NOT_FOUND`) y siempre una fila `CHECKED` con el total de tokens verificados. Un diccionario correcto responde
sólo la fila `CHECKED`.

- Cada nombre se resuelve por su sinónimo público (`DBA_SYNONYMS`, destino acotado a los mismos owners); sin sinónimo, se busca el objeto con ese nombre. Así `V$X` llega a su objeto real aunque no se llame `V_$X`.
- La comparación ocurre en la base: la respuesta nunca contiene el catálogo, sólo discrepancias.

# Notes by version

Generada para 19c (`min_version` ≤ 19 en el diccionario). `REGEXP_SUBSTR`/`REGEXP_COUNT` existen desde 11g.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`. El lab la ejecuta desde `CDB$ROOT`, donde viven los objetos de `SYS`.

# Cost classification rationale

`MEDIUM`: 110 búsquedas por nombre en el catálogo (`DBA_SYNONYMS`, `DBA_TAB_COLUMNS`), sin datos de aplicación.

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

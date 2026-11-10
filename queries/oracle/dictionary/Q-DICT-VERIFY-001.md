---
query_id: Q-DICT-VERIFY-001
version: 1.0.0

domain: oracle
purpose: "Verificación del diccionario del e-stack contra el catálogo real (parte 1/7: ALL_SOURCE.* … CDB_TEMP_FILES.TABLESPACE_NAME) — la base compara y devuelve sólo discrepancias"

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
  - variant_id: Q-DICT-VERIFY-001-V1
    label: oracle_19c
    oracle_versions: {min: "19.0", max: "19.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (oracle_19c, generated)"

tests: [tests/test_no_write_operations.sh, tests/test_sql_static_validator.sh, tests/test_dict_verify_queries_match_dictionary.sh, tests/test_p15_oracle_lab_adapter.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (oracle_19c, generated)

```sql
WITH s AS (SELECT 'ALL_SOURCE.* AUDIT_UNIFIED_ENABLED_POLICIES.* AUDIT_UNIFIED_POLICIES.* CDB_AUDIT_SESSION.* CDB_AUTOTASK_CLIENT.* CDB_AUTOTASK_CLIENT.CLIENT_NAME CDB_AUTOTASK_CLIENT.CON_ID CDB_AUTOTASK_CLIENT.STATUS CDB_AUTOTASK_JOB_HISTORY.* CDB_AUTOTASK_JOB_HISTORY.CLIENT_NAME CDB_AUTOTASK_JOB_HISTORY.CON_ID CDB_AUTOTASK_JOB_HISTORY.JOB_START_TIME CDB_AUTOTASK_JOB_HISTORY.JOB_STATUS CDB_AUTOTASK_WINDOW_CLIENTS.* CDB_AUTOTASK_WINDOW_CLIENTS.AUTOTASK_STATUS CDB_AUTOTASK_WINDOW_CLIENTS.CON_ID CDB_AUTOTASK_WINDOW_CLIENTS.OPTIMIZER_STATS CDB_AUTOTASK_WINDOW_CLIENTS.SEGMENT_ADVISOR CDB_AUTOTASK_WINDOW_CLIENTS.SQL_TUNE_ADVISOR CDB_DATA_FILES.* CDB_DB_LINKS.* CDB_DB_LINKS.CON_ID CDB_DB_LINKS.DB_LINK CDB_DB_LINKS.HOST CDB_DB_LINKS.OWNER CDB_DB_LINKS.USERNAME CDB_DIRECTORIES.* CDB_ENCRYPTED_COLUMNS.* CDB_ENCRYPTED_COLUMNS.CON_ID CDB_ENCRYPTED_COLUMNS.ENCRYPTION_ALG CDB_ENCRYPTED_COLUMNS.OWNER CDB_FEATURE_USAGE_STATISTICS.* CDB_FEATURE_USAGE_STATISTICS.CON_ID CDB_FEATURE_USAGE_STATISTICS.CURRENTLY_USED CDB_FEATURE_USAGE_STATISTICS.DETECTED_USAGES CDB_FEATURE_USAGE_STATISTICS.FIRST_USAGE_DATE CDB_FEATURE_USAGE_STATISTICS.LAST_SAMPLE_DATE CDB_FEATURE_USAGE_STATISTICS.LAST_USAGE_DATE CDB_FEATURE_USAGE_STATISTICS.NAME CDB_JOBS.* CDB_JOBS.BROKEN CDB_JOBS.CON_ID CDB_JOBS.FAILURES CDB_JOBS.LAST_DATE CDB_JOBS.SCHEMA_USER CDB_JOBS.THIS_DATE CDB_LOCKDOWN_PROFILES.* CDB_LOCKDOWN_PROFILES.CLAUSE CDB_LOCKDOWN_PROFILES.CLAUSE_OPTION CDB_LOCKDOWN_PROFILES.CON_ID CDB_LOCKDOWN_PROFILES.PROFILE_NAME CDB_LOCKDOWN_PROFILES.RULE CDB_LOCKDOWN_PROFILES.RULE_TYPE CDB_LOCKDOWN_PROFILES.STATUS CDB_OBJECTS.* CDB_PROFILES.* CDB_REGISTRY.* CDB_REGISTRY_SQLPATCH.* CDB_REGISTRY_SQLPATCH.ACTION CDB_REGISTRY_SQLPATCH.ACTION_TIME CDB_REGISTRY_SQLPATCH.CON_ID CDB_REGISTRY_SQLPATCH.PATCH_ID CDB_REGISTRY_SQLPATCH.PATCH_TYPE CDB_REGISTRY_SQLPATCH.STATUS CDB_REGISTRY_SQLPATCH.TARGET_VERSION CDB_ROLES.* CDB_ROLE_PRIVS.* CDB_SCHEDULER_JOBS.* CDB_SCHEDULER_JOBS.CON_ID CDB_SCHEDULER_JOBS.FAILURE_COUNT CDB_SCHEDULER_JOBS.JOB_NAME CDB_SCHEDULER_JOBS.LAST_START_DATE CDB_SCHEDULER_JOBS.OWNER CDB_SCHEDULER_JOBS.STATE CDB_SYS_PRIVS.* CDB_TABLESPACES.* CDB_TABLESPACES.BLOCK_SIZE CDB_TABLESPACES.CON_ID CDB_TABLESPACES.TABLESPACE_NAME CDB_TABLESPACE_USAGE_METRICS.* CDB_TAB_PRIVS.* CDB_TAB_STATISTICS.* CDB_TAB_STATISTICS.CON_ID CDB_TAB_STATISTICS.LAST_ANALYZED CDB_TAB_STATISTICS.OBJECT_TYPE CDB_TAB_STATISTICS.OWNER CDB_TAB_STATISTICS.STALE_STATS CDB_TAB_STATISTICS.STATTYPE_LOCKED CDB_TAB_STATISTICS.TABLE_NAME CDB_TEMP_FILES.* CDB_TEMP_FILES.BYTES CDB_TEMP_FILES.CON_ID CDB_TEMP_FILES.MAXBYTES CDB_TEMP_FILES.TABLESPACE_NAME' AS l FROM dual),
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

Parte 1 de 7: 94 tokens `VISTA.COLUMNA` (o `VISTA.*` = la vista misma) sobre 27 vistas. Devuelve una fila
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

`MEDIUM`: 94 búsquedas por nombre en el catálogo (`DBA_SYNONYMS`, `DBA_TAB_COLUMNS`), sin datos de aplicación.

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

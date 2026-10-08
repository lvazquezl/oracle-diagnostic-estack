---
query_id: Q-DICT-VERIFY-001
version: 1.0.0

domain: oracle
purpose: "Verificación del diccionario del e-stack contra el catálogo real (parte 1/5: ALL_SOURCE.* … DBA_SYS_PRIVS.GRANTEE) — la base compara y devuelve sólo discrepancias"

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
WITH s AS (SELECT 'ALL_SOURCE.* AUDIT_UNIFIED_ENABLED_POLICIES.* AUDIT_UNIFIED_POLICIES.* CDB_AUDIT_SESSION.* CDB_DATA_FILES.* CDB_DIRECTORIES.* CDB_LOCKDOWN_PROFILES.* CDB_LOCKDOWN_PROFILES.CLAUSE CDB_LOCKDOWN_PROFILES.CLAUSE_OPTION CDB_LOCKDOWN_PROFILES.CON_ID CDB_LOCKDOWN_PROFILES.PROFILE_NAME CDB_LOCKDOWN_PROFILES.RULE CDB_LOCKDOWN_PROFILES.RULE_TYPE CDB_LOCKDOWN_PROFILES.STATUS CDB_OBJECTS.* CDB_PROFILES.* CDB_REGISTRY.* CDB_ROLES.* CDB_ROLE_PRIVS.* CDB_SCHEDULER_JOBS.* CDB_SYS_PRIVS.* CDB_TABLESPACES.* CDB_TABLESPACE_USAGE_METRICS.* CDB_TAB_PRIVS.* CDB_TEMP_FILES.* CDB_UNIFIED_AUDIT_TRAIL.* CDB_USERS.* DBA_AUDIT_SESSION.* DBA_AUDIT_TRAIL.* DBA_CDB_RSRC_PLAN_DIRECTIVES.* DBA_CDB_RSRC_PLAN_DIRECTIVES.PARALLEL_SERVER_LIMIT DBA_CDB_RSRC_PLAN_DIRECTIVES.PLAN DBA_CDB_RSRC_PLAN_DIRECTIVES.PLUGGABLE_DATABASE DBA_CDB_RSRC_PLAN_DIRECTIVES.SHARES DBA_CDB_RSRC_PLAN_DIRECTIVES.UTILIZATION_LIMIT DBA_CONTAINER_DATA.* DBA_DATA_FILES.* DBA_DB_LINKS.* DBA_DB_LINKS.DB_LINK DBA_DB_LINKS.HOST DBA_DB_LINKS.OWNER DBA_DB_LINKS.USERNAME DBA_DIRECTORIES.* DBA_DIRECTORIES.DIRECTORY_NAME DBA_DIRECTORIES.DIRECTORY_PATH DBA_DIRECTORIES.OWNER DBA_DV_STATUS.* DBA_ENCRYPTED_COLUMNS.* DBA_ENCRYPTED_COLUMNS.COLUMN_NAME DBA_ENCRYPTED_COLUMNS.ENCRYPTION_ALG DBA_ENCRYPTED_COLUMNS.OWNER DBA_ENCRYPTED_COLUMNS.TABLE_NAME DBA_FREE_SPACE.* DBA_HIST_ACTIVE_SESS_HISTORY.* DBA_HIST_SNAPSHOT.* DBA_HIST_SQLSTAT.* DBA_HIST_SQL_PLAN.* DBA_HIST_SYSTEM_EVENT.* DBA_HIST_SYSTEM_EVENT.TIME_WAITED_MICRO_FG DBA_HIST_SYS_TIME_MODEL.* DBA_HOST_ACES.* DBA_JOBS.* DBA_NETWORK_ACLS.* DBA_OBJECTS.* DBA_OUTSTANDING_ALERTS.* DBA_PDB_SAVED_STATES.* DBA_PDB_SAVED_STATES.CON_ID DBA_PDB_SAVED_STATES.CON_NAME DBA_PDB_SAVED_STATES.CON_UID DBA_PDB_SAVED_STATES.GUID DBA_PDB_SAVED_STATES.INSTANCE_NAME DBA_PDB_SAVED_STATES.RESTRICTED DBA_PDB_SAVED_STATES.STATE DBA_PROFILES.* DBA_PROFILES.LIMIT DBA_PROFILES.PROFILE DBA_PROFILES.RESOURCE_NAME DBA_PROFILES.RESOURCE_TYPE DBA_REGISTRY.* DBA_ROLES.* DBA_ROLES.COMMON DBA_ROLES.ORACLE_MAINTAINED DBA_ROLES.ROLE DBA_ROLE_PRIVS.* DBA_ROLE_PRIVS.ADMIN_OPTION DBA_ROLE_PRIVS.COMMON DBA_ROLE_PRIVS.DEFAULT_ROLE DBA_ROLE_PRIVS.GRANTED_ROLE DBA_ROLE_PRIVS.GRANTEE DBA_SCHEDULER_JOBS.* DBA_SCHEDULER_JOB_RUN_DETAILS.* DBA_SOURCE.* DBA_SOURCE.LINE DBA_SOURCE.NAME DBA_SOURCE.OWNER DBA_SOURCE.TEXT DBA_SOURCE.TYPE DBA_SYNONYMS.* DBA_SYNONYMS.OWNER DBA_SYNONYMS.SYNONYM_NAME DBA_SYNONYMS.TABLE_NAME DBA_SYNONYMS.TABLE_OWNER DBA_SYS_PRIVS.* DBA_SYS_PRIVS.ADMIN_OPTION DBA_SYS_PRIVS.COMMON DBA_SYS_PRIVS.GRANTEE' AS l FROM dual),
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

Parte 1 de 5: 106 tokens `VISTA.COLUMNA` (o `VISTA.*` = la vista misma) sobre 51 vistas. Devuelve una fila
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

`MEDIUM`: 106 búsquedas por nombre en el catálogo (`DBA_SYNONYMS`, `DBA_TAB_COLUMNS`), sin datos de aplicación.

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

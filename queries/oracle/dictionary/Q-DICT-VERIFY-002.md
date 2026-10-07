---
query_id: Q-DICT-VERIFY-002
version: 1.0.0

domain: oracle
purpose: "Verificación del diccionario del e-stack contra el catálogo real (parte 2/5: DBA_SYS_PRIVS.COMMON … V$ARCHIVED_LOG.*) — la base compara y devuelve sólo discrepancias"

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
  - variant_id: Q-DICT-VERIFY-002-V1
    label: oracle_19c
    oracle_versions: {min: "19.0", max: "19.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (oracle_19c, generated)"

tests: [tests/test_no_write_operations.sh, tests/test_sql_static_validator.sh, tests/test_dict_verify_queries_match_dictionary.sh, tests/test_p15_oracle_lab_adapter.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (oracle_19c, generated)

```sql
WITH s AS (SELECT 'DBA_SYS_PRIVS.COMMON DBA_SYS_PRIVS.GRANTEE DBA_SYS_PRIVS.PRIVILEGE DBA_TABLESPACES.* DBA_TABLESPACE_USAGE_METRICS.* DBA_TAB_COLUMNS.* DBA_TAB_COLUMNS.COLUMN_NAME DBA_TAB_COLUMNS.OWNER DBA_TAB_COLUMNS.TABLE_NAME DBA_TAB_PRIVS.* DBA_TAB_PRIVS.COMMON DBA_TAB_PRIVS.GRANTABLE DBA_TAB_PRIVS.GRANTEE DBA_TAB_PRIVS.OWNER DBA_TAB_PRIVS.PRIVILEGE DBA_TAB_PRIVS.TABLE_NAME DBA_TEMP_FILES.* DBA_TEMP_FREE_SPACE.* DBA_UNDO_EXTENTS.* DBA_USERS.* DBA_USERS.ACCOUNT_STATUS DBA_USERS.AUTHENTICATION_TYPE DBA_USERS.COMMON DBA_USERS.CREATED DBA_USERS.EXPIRY_DATE DBA_USERS.LAST_LOGIN DBA_USERS.LOCK_DATE DBA_USERS.ORACLE_MAINTAINED DBA_USERS.PASSWORD_CHANGE_DATE DBA_USERS.PASSWORD_VERSIONS DBA_USERS.PROFILE DBA_USERS.USERNAME DBA_USERS.USER_ID DBA_USERS_WITH_DEFPWD.* DBA_USERS_WITH_DEFPWD.USERNAME GV$ACTIVE_SERVICES.* GV$ARCHIVE_DEST_STATUS.* GV$ASM_OPERATION.* GV$CLUSTER_INTERCONNECTS.* GV$DATAGUARD_PROCESS.* GV$GES_STATISTICS.* GV$INSTANCE.* GV$INSTANCE.INST_ID GV$INSTANCE_CACHE_TRANSFER.* GV$MANAGED_STANDBY.* GV$PARAMETER.* GV$SERVICES.* GV$SESSION.* GV$SORT_SEGMENT.* GV$SORT_SEGMENT.CON_ID GV$SORT_SEGMENT.INST_ID GV$SORT_SEGMENT.TABLESPACE_NAME GV$SORT_SEGMENT.USED_BLOCKS GV$SYSSTAT.* GV$SYSSTAT.INST_ID GV$SYSSTAT.NAME GV$SYSSTAT.VALUE GV$SYSTEM_PARAMETER.* GV$TEMP_SPACE_HEADER.* PDB_PLUG_IN_VIOLATIONS.* PDB_PLUG_IN_VIOLATIONS.ACTION PDB_PLUG_IN_VIOLATIONS.CAUSE PDB_PLUG_IN_VIOLATIONS.CON_ID PDB_PLUG_IN_VIOLATIONS.ERROR_NUMBER PDB_PLUG_IN_VIOLATIONS.LINE PDB_PLUG_IN_VIOLATIONS.MESSAGE PDB_PLUG_IN_VIOLATIONS.NAME PDB_PLUG_IN_VIOLATIONS.STATUS PDB_PLUG_IN_VIOLATIONS.TIME PDB_PLUG_IN_VIOLATIONS.TYPE PROXY_USERS.* PROXY_USERS.AUTHENTICATION PROXY_USERS.CLIENT PROXY_USERS.FLAGS PROXY_USERS.PROXY REDACTION_COLUMNS.* REDACTION_COLUMNS.COLUMN_NAME REDACTION_COLUMNS.FUNCTION_TYPE REDACTION_COLUMNS.OBJECT_NAME REDACTION_COLUMNS.OBJECT_OWNER REDACTION_POLICIES.* REDACTION_POLICIES.ENABLE REDACTION_POLICIES.OBJECT_NAME REDACTION_POLICIES.OBJECT_OWNER REDACTION_POLICIES.POLICY_NAME ROLE_ROLE_PRIVS.* ROLE_SYS_PRIVS.* ROLE_TAB_PRIVS.* STATS$SNAPSHOT.* STATS$SYSTEM_EVENT.* UNIFIED_AUDIT_TRAIL.* UNIFIED_AUDIT_TRAIL.ACTION_NAME UNIFIED_AUDIT_TRAIL.DBUSERNAME UNIFIED_AUDIT_TRAIL.EVENT_TIMESTAMP UNIFIED_AUDIT_TRAIL.OBJECT_NAME UNIFIED_AUDIT_TRAIL.OBJECT_SCHEMA UNIFIED_AUDIT_TRAIL.RETURN_CODE V$ACTIVE_INSTANCES.* V$ACTIVE_INSTANCES.CON_ID V$ACTIVE_INSTANCES.INST_NAME V$ACTIVE_INSTANCES.INST_NUMBER V$ACTIVE_SESSION_HISTORY.* V$ARCHIVED_LOG.*' AS l FROM dual),
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

Parte 2 de 5: 103 tokens `VISTA.COLUMNA` (o `VISTA.*` = la vista misma) sobre 39 vistas. Devuelve una fila
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

`MEDIUM`: 103 búsquedas por nombre en el catálogo (`DBA_SYNONYMS`, `DBA_TAB_COLUMNS`), sin datos de aplicación.

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

---
query_id: Q-DICT-VERIFY-002
version: 1.0.0

domain: oracle
purpose: "Verificación del diccionario del e-stack contra el catálogo real (parte 2/5: DBA_TAB_COLUMNS.OWNER … V$ARCHIVED_LOG.NEXT_TIME) — la base compara y devuelve sólo discrepancias"

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
WITH s AS (SELECT 'DBA_TAB_COLUMNS.OWNER DBA_TAB_COLUMNS.TABLE_NAME DBA_TAB_PRIVS.* DBA_TAB_PRIVS.COMMON DBA_TAB_PRIVS.GRANTABLE DBA_TAB_PRIVS.GRANTEE DBA_TAB_PRIVS.OWNER DBA_TAB_PRIVS.PRIVILEGE DBA_TAB_PRIVS.TABLE_NAME DBA_TEMP_FILES.* DBA_TEMP_FREE_SPACE.* DBA_UNDO_EXTENTS.* DBA_USERS.* DBA_USERS.ACCOUNT_STATUS DBA_USERS.AUTHENTICATION_TYPE DBA_USERS.COMMON DBA_USERS.CREATED DBA_USERS.EXPIRY_DATE DBA_USERS.LAST_LOGIN DBA_USERS.LOCK_DATE DBA_USERS.ORACLE_MAINTAINED DBA_USERS.PASSWORD_CHANGE_DATE DBA_USERS.PASSWORD_VERSIONS DBA_USERS.PROFILE DBA_USERS.USERNAME DBA_USERS.USER_ID DBA_USERS_WITH_DEFPWD.* DBA_USERS_WITH_DEFPWD.USERNAME GV$ACTIVE_SERVICES.* GV$ARCHIVE_DEST_STATUS.* GV$ASM_INSTANCE.* GV$ASM_OPERATION.* GV$CLUSTER_INTERCONNECTS.* GV$DATAGUARD_PROCESS.* GV$GCS_STATISTICS.* GV$GES_STATISTICS.* GV$INSTANCE.* GV$INSTANCE_CACHE_TRANSFER.* GV$MANAGED_STANDBY.* GV$PARAMETER.* GV$SERVICES.* GV$SESSION.* GV$SYSTEM_PARAMETER.* GV$TEMP_SPACE_HEADER.* PDB_PLUG_IN_VIOLATIONS.* PDB_PLUG_IN_VIOLATIONS.ACTION PDB_PLUG_IN_VIOLATIONS.CAUSE PDB_PLUG_IN_VIOLATIONS.CON_ID PDB_PLUG_IN_VIOLATIONS.ERROR_NUMBER PDB_PLUG_IN_VIOLATIONS.LINE PDB_PLUG_IN_VIOLATIONS.MESSAGE PDB_PLUG_IN_VIOLATIONS.NAME PDB_PLUG_IN_VIOLATIONS.STATUS PDB_PLUG_IN_VIOLATIONS.TIME PDB_PLUG_IN_VIOLATIONS.TYPE PROXY_USERS.* PROXY_USERS.AUTHENTICATION PROXY_USERS.AUTHORIZATION_CONSTRAINT PROXY_USERS.CLIENT PROXY_USERS.PROXY REDACTION_COLUMNS.* REDACTION_COLUMNS.COLUMN_NAME REDACTION_COLUMNS.FUNCTION_TYPE REDACTION_COLUMNS.OBJECT_NAME REDACTION_COLUMNS.OBJECT_OWNER REDACTION_COLUMNS.POLICY_NAME REDACTION_POLICIES.* REDACTION_POLICIES.ENABLE REDACTION_POLICIES.OBJECT_NAME REDACTION_POLICIES.OBJECT_OWNER REDACTION_POLICIES.POLICY_NAME ROLE_ROLE_PRIVS.* ROLE_SYS_PRIVS.* ROLE_TAB_PRIVS.* STATS$SNAPSHOT.* STATS$SYSTEM_EVENT.* UNIFIED_AUDIT_TRAIL.* UNIFIED_AUDIT_TRAIL.ACTION_NAME UNIFIED_AUDIT_TRAIL.DBUSERNAME UNIFIED_AUDIT_TRAIL.EVENT_TIMESTAMP UNIFIED_AUDIT_TRAIL.OBJECT_NAME UNIFIED_AUDIT_TRAIL.OBJECT_SCHEMA UNIFIED_AUDIT_TRAIL.RETURN_CODE V$ACTIVE_INSTANCES.* V$ACTIVE_INSTANCES.CON_ID V$ACTIVE_INSTANCES.INST_NAME V$ACTIVE_INSTANCES.INST_NUMBER V$ACTIVE_SESSION_HISTORY.* V$ARCHIVED_LOG.* V$ARCHIVED_LOG.APPLIED V$ARCHIVED_LOG.ARCHIVED V$ARCHIVED_LOG.BACKUP_COUNT V$ARCHIVED_LOG.DELETED V$ARCHIVED_LOG.FIRST_TIME V$ARCHIVED_LOG.NAME V$ARCHIVED_LOG.NEXT_TIME' AS l FROM dual),
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

Parte 2 de 5: 96 tokens `VISTA.COLUMNA` (o `VISTA.*` = la vista misma) sobre 36 vistas. Devuelve una fila
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

`MEDIUM`: 96 búsquedas por nombre en el catálogo (`owner`, `table_name`), sin datos de aplicación.

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

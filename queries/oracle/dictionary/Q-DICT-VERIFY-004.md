---
query_id: Q-DICT-VERIFY-004
version: 1.0.0

domain: oracle
purpose: "Verificación del diccionario del e-stack contra el catálogo real (parte 4/5: V$DATABASE.OPEN_MODE … V$RECOVERY_FILE_DEST.*) — la base compara y devuelve sólo discrepancias"

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
  - variant_id: Q-DICT-VERIFY-004-V1
    label: oracle_19c
    oracle_versions: {min: "19.0", max: "19.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (oracle_19c, generated)"

tests: [tests/test_no_write_operations.sh, tests/test_sql_static_validator.sh, tests/test_dict_verify_queries_match_dictionary.sh, tests/test_p15_oracle_lab_adapter.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (oracle_19c, generated)

```sql
WITH s AS (SELECT 'V$DATABASE.OPEN_MODE V$DATABASE.PROTECTION_LEVEL V$DATABASE.PROTECTION_MODE V$DATABASE.REMOTE_ARCHIVE V$DATABASE.SWITCHOVER_STATUS V$DATAFILE.* V$DATAGUARD_PROCESS.* V$DATAGUARD_PROCESS.ACTION V$DATAGUARD_PROCESS.BLOCK# V$DATAGUARD_PROCESS.BLOCK_COUNT V$DATAGUARD_PROCESS.CLIENT_PID V$DATAGUARD_PROCESS.CLIENT_ROLE V$DATAGUARD_PROCESS.NAME V$DATAGUARD_PROCESS.PID V$DATAGUARD_PROCESS.ROLE V$DATAGUARD_PROCESS.SEQUENCE# V$DATAGUARD_PROCESS.THREAD# V$DATAGUARD_PROCESS.TYPE V$DATAGUARD_STATS.* V$DATAGUARD_STATS.APPLY_LAG V$DATAGUARD_STATS.NAME V$DATAGUARD_STATS.TRANSPORT_LAG V$DATAGUARD_STATS.UNIT V$DATAGUARD_STATS.VALUE V$DATAGUARD_STATUS.* V$DIAG_INFO.* V$ENCRYPTED_TABLESPACES.* V$ENCRYPTED_TABLESPACES.ENCRYPTEDTS V$ENCRYPTED_TABLESPACES.ENCRYPTIONALG V$ENCRYPTED_TABLESPACES.TS# V$ENCRYPTION_WALLET.* V$ENCRYPTION_WALLET.STATUS V$ENCRYPTION_WALLET.WALLET_TYPE V$ENCRYPTION_WALLET.WRL_PARAMETER V$FILESTAT.* V$FLASH_RECOVERY_AREA_USAGE.* V$FLASH_RECOVERY_AREA_USAGE.FILE_TYPE V$FLASH_RECOVERY_AREA_USAGE.NUMBER_OF_FILES V$FLASH_RECOVERY_AREA_USAGE.PERCENT_SPACE_RECLAIMABLE V$FLASH_RECOVERY_AREA_USAGE.PERCENT_SPACE_USED V$INSTANCE.* V$INSTANCE.ACTIVE_STATE V$INSTANCE.DATABASE_STATUS V$INSTANCE.HOST_NAME V$INSTANCE.INSTANCE_NAME V$INSTANCE.INSTANCE_NUMBER V$INSTANCE.INSTANCE_ROLE V$INSTANCE.SHUTDOWN_PENDING V$INSTANCE.STARTUP_TIME V$INSTANCE.STATUS V$INSTANCE.VERSION V$INSTANCE.VERSION_FULL V$LIBRARYCACHE.* V$LOG.* V$LOGFILE.* V$LOG_HISTORY.* V$MANAGED_STANDBY.* V$MANAGED_STANDBY.BLOCK# V$MANAGED_STANDBY.BLOCKS V$MANAGED_STANDBY.CLIENT_PID V$MANAGED_STANDBY.CLIENT_PROCESS V$MANAGED_STANDBY.PID V$MANAGED_STANDBY.PROCESS V$MANAGED_STANDBY.SEQUENCE# V$MANAGED_STANDBY.STATUS V$MANAGED_STANDBY.THREAD# V$OPTION.* V$OPTION.PARAMETER V$OPTION.VALUE V$PARAMETER.* V$PDBS.* V$PDBS.APPLICATION_PDB V$PDBS.APPLICATION_ROOT V$PDBS.APPLICATION_SEED V$PDBS.CON_ID V$PDBS.LOCAL_UNDO V$PDBS.NAME V$PDBS.OPEN_MODE V$PDBS.OPEN_TIME V$PDBS.PROXY_PDB V$PDBS.RECOVERY_STATUS V$PDBS.RESTRICTED V$PDBS.TOTAL_SIZE V$PGASTAT.* V$PGASTAT.PGA_AGGREGATE_LIMIT_ROW V$PQ_SYSSTAT.* V$PROCESS.* V$PWFILE_USERS.* V$PWFILE_USERS.COMMON V$PWFILE_USERS.SYSASM V$PWFILE_USERS.SYSBACKUP V$PWFILE_USERS.SYSDBA V$PWFILE_USERS.SYSDG V$PWFILE_USERS.SYSKM V$PWFILE_USERS.SYSOPER V$PWFILE_USERS.USERNAME V$PX_SESSION.* V$RECOVERY_FILE_DEST.*' AS l FROM dual),
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

Parte 4 de 5: 98 tokens `VISTA.COLUMNA` (o `VISTA.*` = la vista misma) sobre 25 vistas. Devuelve una fila
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

`MEDIUM`: 98 búsquedas por nombre en el catálogo (`owner`, `table_name`), sin datos de aplicación.

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

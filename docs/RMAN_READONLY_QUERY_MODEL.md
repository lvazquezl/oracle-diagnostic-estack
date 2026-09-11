# RMAN Read-Only Query Model — Fase 7

Catálogo certificado `queries/rman/**` (14 queries) y su relación con el Oracle Dictionary Compatibility Model (`compatibility/oracle-dictionary/views.yaml`).

## Principio

Toda evidencia de backup/recovery proviene de:

1. **Queries certificadas** (`queries/rman/Q-RMAN-*.md`) contra vistas `V$RMAN_*`/`V$BACKUP_*`/`V$ARCHIVED_LOG`/`V$FLASH_RECOVERY_AREA_USAGE`/`V$RECOVERY_FILE_DEST`/`V$CONTROLFILE_RECORD_SECTION` — todas `execution_mode: READ_ONLY`.
2. **Ingest de output textual** ya producido manualmente por el DBA (`SHOW ALL`, `LIST BACKUP`, `LIST BACKUP SUMMARY`, `REPORT OBSOLETE`, `REPORT NEED BACKUP`, `RESTORE ... PREVIEW`) vía `parsers/rman/**` — nunca ejecutado por el e-stack.

Nunca SQL arbitrario, nunca concatenación de comandos RMAN.

## Catálogo

| query_id | vista(s) | dominio | container_scope |
|---|---|---|---|
| `Q-RMAN-CONFIGURATION-001` | `V$RMAN_CONFIGURATION` | configuración | ANY_CONTAINER |
| `Q-RMAN-STATUS-001` | `V$RMAN_STATUS` | estado de jobs | ANY_CONTAINER |
| `Q-RMAN-OUTPUT-001` | `V$RMAN_OUTPUT` | troubleshooting | ANY_CONTAINER |
| `Q-RMAN-BACKUP-JOB-001` | `V$RMAN_BACKUP_JOB_DETAILS` | duración/throughput | ANY_CONTAINER |
| `Q-RMAN-BACKUP-SET-001` | `V$BACKUP_SET` | inventario | NOT_APPLICABLE (V1, 10g-11g) / ANY_CONTAINER (V2, 12.1+) |
| `Q-RMAN-BACKUP-PIECE-001` | `V$BACKUP_PIECE` | inventario físico | ANY_CONTAINER |
| `Q-RMAN-BACKUP-DATAFILE-001` | `V$BACKUP_DATAFILE` | cobertura de datafile | ANY_CONTAINER |
| `Q-RMAN-ARCHIVELOG-BACKUP-001` | `V$BACKUP_REDOLOG` | cobertura de archivelog | ANY_CONTAINER |
| `Q-RMAN-ARCHIVED-LOG-COVERAGE-001` | `V$ARCHIVED_LOG` | generación/aplicación | ANY_CONTAINER |
| `Q-RMAN-CONTROLFILE-BACKUP-001` | `V$BACKUP_SET` (filtrado) | protección de controlfile | ANY_CONTAINER |
| `Q-RMAN-SPFILE-BACKUP-001` | `V$BACKUP_SPFILE` | protección de SPFILE | ANY_CONTAINER |
| `Q-RMAN-BACKUP-DEVICE-001` | `V$BACKUP_DEVICE` | canales activos | NOT_APPLICABLE |
| `Q-RMAN-FRA-USAGE-001` | `V$FLASH_RECOVERY_AREA_USAGE`, `V$RECOVERY_FILE_DEST` | FRA | NOT_APPLICABLE |
| `Q-RMAN-CONTROLFILE-RECORD-SECTION-001` | `V$CONTROLFILE_RECORD_SECTION` | capacidad de registro | NOT_APPLICABLE |

`V$DATABASE`, `V$DATAFILE`, `V$TABLESPACE`, `V$INSTANCE`, `GV$INSTANCE` (listadas en `# 6` del prompt) se reutilizan de Oracle Core (Fase 2) — nunca re-certificadas aquí.

## Gap pre-existente cerrado en esta fase

`Q-RMAN-BACKUP-JOB-001`/`Q-RMAN-BACKUPSET-001` figuraban `REGISTERED` en `queries/REGISTRY.md` desde Foundation sin archivo real ni entrada de diccionario — mismo patrón que `Q-CDB-PDB-STATE-001`/`Q-CDB-CONTAINERS-001` en Fase 6. `Q-RMAN-BACKUP-JOB-001` se materializó de verdad (`V$RMAN_BACKUP_JOB_DETAILS`, verificado real vía WebFetch contra docs.oracle.com — vista derivada de `V$RMAN_STATUS`/`V$RMAN_OUTPUT` con columnas pre-calculadas, preferida sobre derivar duración/throughput manualmente). `Q-RMAN-BACKUPSET-001` se reemplazó por `Q-RMAN-BACKUP-SET-001` (mismo propósito, nombre corregido a la convención hyphenated).

## Version certification

10g-23ai para todas las 14 queries — verificado vía WebFetch: `V$RMAN_CONFIGURATION` desde 9i, `V$RMAN_STATUS`/`V$RMAN_OUTPUT`/`V$RMAN_BACKUP_JOB_DETAILS` desde 10g (oracle-base.com "RMAN Enhancements in Oracle Database 10g"), el resto de vistas `V$BACKUP_*`/`V$ARCHIVED_LOG`/`V$CONTROLFILE_RECORD_SECTION` pre-10g. `CON_ID` (multitenant) sólo 12.1+ en las vistas que lo exponen — `Q-RMAN-BACKUP-SET-001` es la única query con split de variantes (legacy 10g-11g sin `CON_ID` / modern 12.1+ con `CON_ID`), mismo patrón verificado que `PDB_PLUG_IN_VIOLATIONS` en Fase 6. Ninguna variante declara `max: latest` — todas declaran `max: "23.0"` explícito (ver `config/query-compatibility-matrix.yaml`). Future major → `COMPATIBILITY_VALIDATION_REQUIRED` (`# 5` del prompt).

## Cost / budget

Toda query cost_class `MEDIUM`/`HIGH` declara `timeout_seconds`/`max_rows`/`max_output_bytes` explícitos — nunca se consultan años de historia por defecto (`# 35` del prompt). Ver `tests/test_rman_query_budget.sh`.

## Sanitización

`HANDLE` (piezas), paths de FRA/snapshot controlfile, `TAG`, vendor job IDs, `DB_UNIQUE_NAME` → TOKENIZE/MASK consistente con `sanitizers/data-classification-policy.md`. `V$RMAN_OUTPUT.OUTPUT` (texto libre) → `sensitivity: HIGH`, tratado siempre como DATA.

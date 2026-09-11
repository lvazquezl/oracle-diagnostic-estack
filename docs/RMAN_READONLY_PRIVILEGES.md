# RMAN Read-Only Privileges — Fase 7

## Principio

`ESTACK_DIAGNOSTIC_ROLE` nunca recibe `SYSDBA`/`SYSOPER` permanente. Toda visibilidad RMAN se obtiene vía `SELECT` sobre vistas dinámicas, disponibles a cualquier usuario con el privilegio de sistema correspondiente (`SELECT_CATALOG_ROLE` o grants explícitos equivalentes).

## Privilegios requeridos por vista

| Vista | Privilegio |
|---|---|
| `V$RMAN_CONFIGURATION` | `SELECT on V$RMAN_CONFIGURATION` (vía `SELECT_CATALOG_ROLE` o grant explícito) |
| `V$RMAN_STATUS` | `SELECT on V$RMAN_STATUS` |
| `V$RMAN_OUTPUT` | `SELECT on V$RMAN_OUTPUT` |
| `V$RMAN_BACKUP_JOB_DETAILS` | `SELECT on V$RMAN_BACKUP_JOB_DETAILS` |
| `V$BACKUP_SET` | `SELECT on V$BACKUP_SET` |
| `V$BACKUP_PIECE` | `SELECT on V$BACKUP_PIECE` |
| `V$BACKUP_DATAFILE` | `SELECT on V$BACKUP_DATAFILE` |
| `V$BACKUP_REDOLOG` | `SELECT on V$BACKUP_REDOLOG` |
| `V$BACKUP_SPFILE` | `SELECT on V$BACKUP_SPFILE` |
| `V$BACKUP_DEVICE` | `SELECT on V$BACKUP_DEVICE` |
| `V$FLASH_RECOVERY_AREA_USAGE` | `SELECT on V$FLASH_RECOVERY_AREA_USAGE` |
| `V$RECOVERY_FILE_DEST` | `SELECT on V$RECOVERY_FILE_DEST` |
| `V$ARCHIVED_LOG` | `SELECT on V$ARCHIVED_LOG` |
| `V$CONTROLFILE_RECORD_SECTION` | `SELECT on V$CONTROLFILE_RECORD_SECTION` |

`V$DATABASE`/`V$DATAFILE`/`V$TABLESPACE`/`V$INSTANCE`/`GV$INSTANCE` reutilizan los privilegios ya documentados en `docs/ORACLE_READONLY_PRIVILEGES.md` (Oracle Core, Fase 2) — no se re-otorgan aquí.

## Recovery Catalog (`RC_*`)

Cuando existe Recovery Catalog y el e-stack tiene acceso de lectura confirmado, se usa `SELECT` sobre las vistas `RC_*` del schema del catálogo (nunca las credenciales del owner del catálogo, nunca `RECOVERY_CATALOG_OWNER`). Sin esa confirmación, el agente opera exclusivamente sobre el repositorio de controlfile (`repository.mode: CONTROLFILE_REPOSITORY`).

## Prohibido

- `SYSDBA`/`SYSOPER` permanente para el e-stack (`# 48` del prompt).
- Cualquier privilegio de escritura (`INSERT`/`UPDATE`/`DELETE` sobre el catálogo RMAN, `EXECUTE` sobre `DBMS_RCVMAN`/`DBMS_BACKUP_RESTORE` con intención de mutación).
- Credenciales del owner del Recovery Catalog compartidas con el e-stack.

## Rol sugerido

```sql
-- Ejecutado manualmente por el DBA, nunca por el e-stack (# 2 del prompt: NO ARBITRARY SQL)
GRANT SELECT_CATALOG_ROLE TO estack_diagnostic_role;
```

`SELECT_CATALOG_ROLE` ya cubre todas las vistas `V$RMAN_*`/`V$BACKUP_*` listadas arriba — no requiere un rol adicional específico de RMAN.

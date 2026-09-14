# Oracle Security Read-Only Privileges — Fase 8

## Principio

`ESTACK_DIAGNOSTIC_ROLE` nunca recibe `SYSDBA`/`SYSOPER` permanente. Toda visibilidad de seguridad se obtiene vía `SELECT` sobre vistas del diccionario y dinámicas, disponibles a cualquier usuario con el privilegio de sistema correspondiente (`SELECT_CATALOG_ROLE` o grants explícitos equivalentes).

## Privilegios requeridos por vista

| Vista | Privilegio |
|---|---|
| `DBA_USERS` / `CDB_USERS` | `SELECT on DBA_USERS` / `SELECT on CDB_USERS` |
| `DBA_USERS_WITH_DEFPWD` | `SELECT on DBA_USERS_WITH_DEFPWD` |
| `DBA_ROLES` / `DBA_ROLE_PRIVS` / `ROLE_ROLE_PRIVS` | `SELECT on DBA_ROLES`/`DBA_ROLE_PRIVS`; `ROLE_ROLE_PRIVS` visible a la sesión actual sin grant adicional |
| `DBA_SYS_PRIVS` / `ROLE_SYS_PRIVS` | `SELECT on DBA_SYS_PRIVS`; `ROLE_SYS_PRIVS` visible a la sesión actual |
| `DBA_TAB_PRIVS` / `ROLE_TAB_PRIVS` | `SELECT on DBA_TAB_PRIVS`; `ROLE_TAB_PRIVS` visible a la sesión actual |
| `DBA_PROFILES` | `SELECT on DBA_PROFILES` |
| `V$PWFILE_USERS` | `SELECT on V$PWFILE_USERS` |
| `PROXY_USERS` | visible a la sesión actual sin grant adicional |
| `DBA_AUDIT_TRAIL` / `DBA_AUDIT_SESSION` | `SELECT on DBA_AUDIT_TRAIL`/`DBA_AUDIT_SESSION` |
| `UNIFIED_AUDIT_TRAIL` / `AUDIT_UNIFIED_ENABLED_POLICIES` / `AUDIT_UNIFIED_POLICIES` | `SELECT on UNIFIED_AUDIT_TRAIL`/`AUDIT_UNIFIED_ENABLED_POLICIES`/`AUDIT_UNIFIED_POLICIES` (o `AUDIT_VIEWER` desde 12.1) |
| `V$OPTION` | `SELECT on V$OPTION` |
| `V$ENCRYPTION_WALLET` / `V$ENCRYPTED_TABLESPACES` | `SELECT on V$ENCRYPTION_WALLET`/`V$ENCRYPTED_TABLESPACES` |
| `DBA_ENCRYPTED_COLUMNS` | `SELECT on DBA_ENCRYPTED_COLUMNS` |
| `DBA_DB_LINKS` / `DBA_DIRECTORIES` | `SELECT on DBA_DB_LINKS`/`DBA_DIRECTORIES` |
| `DBA_NETWORK_ACLS` / `DBA_HOST_ACES` | `SELECT on DBA_NETWORK_ACLS`/`DBA_HOST_ACES` |
| `DBA_SOURCE` / `ALL_SOURCE` | `SELECT on DBA_SOURCE` (o `ALL_SOURCE` sin privilegio DBA, acotado al owner del verify function) |
| `DBA_DV_STATUS` | `SELECT on DBA_DV_STATUS` — sólo si Database Vault está instalado |
| `REDACTION_POLICIES` / `REDACTION_COLUMNS` | `SELECT_CATALOG_ROLE` |

`V$PARAMETER`/`V$SPPARAMETER` reutilizan los privilegios ya documentados en `docs/ORACLE_READONLY_PRIVILEGES.md` (Oracle Core, Fase 2) — no se re-otorgan aquí.

## Prohibido

- `SYSDBA`/`SYSOPER` permanente para el e-stack.
- Cualquier privilegio de escritura sobre las vistas anteriores, o `EXECUTE` sobre `DBMS_MACADM` (Database Vault), `DBMS_REDACT`, `DBMS_METADATA.GET_DDL` con intención de mutación, `ADMINISTER KEY MANAGEMENT`.
- Acceso a `USER$.PASSWORD`/`SPARE4` o cualquier tabla base subyacente que exponga hashes — sólo vistas dinámicas nombradas arriba, ninguna de las cuales expone contenido de hash/verifier real.

## Rol sugerido

```sql
-- Ejecutado manualmente por el DBA, nunca por el e-stack (NO ARBITRARY SQL)
GRANT SELECT_CATALOG_ROLE TO estack_diagnostic_role;
GRANT SELECT ON V$PWFILE_USERS TO estack_diagnostic_role;
GRANT SELECT ON DBA_SOURCE TO estack_diagnostic_role;
```

`SELECT_CATALOG_ROLE` cubre la mayoría de las vistas listadas arriba; `V$PWFILE_USERS` y `DBA_SOURCE` requieren grant explícito adicional en algunas configuraciones.

# Oracle Security Privilege Model — Fase 8

## Principio

`security/roles`, `security/system-privileges`, `security/object-privileges` nunca analizan sólo grants directos — resuelven la cadena completa `DIRECT|VIA_ROLE` combinando `DBA_ROLE_PRIVS`/`ROLE_ROLE_PRIVS` (nested roles) con `DBA_SYS_PRIVS`/`ROLE_SYS_PRIVS`/`DBA_TAB_PRIVS`/`ROLE_TAB_PRIVS`.

## Catálogo de privilegios sensibles (`security/powerful-privileges`)

| Privilegio | Categoría |
|---|---|
| `DBA`, `SYSDBA`, `SYSOPER`, `SYSASM`, `SYSBACKUP`, `SYSDG`, `SYSKM` | `ADMINISTRATIVE_LOGIN` |
| `CREATE ANY`, `ALTER ANY`, `DROP ANY` | `OBJECT_CREATION` |
| `SELECT ANY DICTIONARY`, `SELECT ANY TABLE` | `DICTIONARY_ACCESS` |
| `EXECUTE ANY PROCEDURE`, `BECOME USER`, `GRANT ANY PRIVILEGE`, `GRANT ANY ROLE` | `PRIVILEGE_ESCALATION` |
| `ALTER SYSTEM`, `ALTER DATABASE` | `SYSTEM_CONTROL` |

Severidad nunca uniforme (`# 11` del prompt): considera contexto (Oracle-maintained vs. custom), `grant_path` (directo vs. vía rol), y necesidad operacional conocida. `GRANT ANY PRIVILEGE`/`GRANT ANY ROLE`/`BECOME USER` en cuenta no-DBA → `CRITICAL` por defecto (privilege escalation).

## PUBLIC exposure (`security/public-grants`)

Clasificación `ORACLE_REQUIRED_DEFAULT|APPLICATION_REQUIRED|CUSTOM|UNKNOWN` — `revoke_recommended` nunca `true` sin dependency analysis explícito del DBA.

## Admin privileges (`security/admin-privileges`)

`V$PWFILE_USERS`, correlacionado con `common`/`local` context (multitenant) — `SYSASM` 11g+, `SYSBACKUP`/`SYSDG`/`SYSKM`/`COMMON` 12.1+ (verificado WebSearch). Nunca lee contenido del password file más allá de la vista dinámica.

## Prohibido en todo el modelo

`GRANT`/`REVOKE` nunca ejecutados — toda remediación de privilegios (ej. `REVOKE EXECUTE ANY PROCEDURE FROM PUBLIC`) se genera como `manual_action` con `execution_status: NOT_EXECUTED`, siempre acompañada de la nota de que requiere dependency analysis previo por el DBA.

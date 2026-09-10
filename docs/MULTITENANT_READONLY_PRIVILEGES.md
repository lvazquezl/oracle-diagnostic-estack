# Multitenant Read-Only Privileges — Fase 6

Extensión de `docs/ORACLE_READONLY_PRIVILEGES.md` (fuente consolidada central) con el detalle específico de Fase 6, documentado aparte por nombrarse explícitamente como entregable de esta fase (`# 66` del prompt). Este documento es **propuesta para revisión humana** — no se ejecuta automáticamente. El e-stack nunca crea usuarios/roles ni otorga privilegios (ver `policies/forbidden-operations.md`). El DBA revisa este documento y decide qué otorgar, cuándo y a quién.

## Principio

Mínimo privilegio suficiente para el catálogo certificado de Fase 6 (`queries/multitenant/*`). Nunca `SELECT ANY TABLE`, `DBA`, `SYSDBA`, `SYSOPER`, `SYSASM` por defecto — se evalúan explícitamente y se descartan salvo justificación excepcional documentada aparte. Todas las vistas de este documento se consultan **desde `CDB$ROOT`** con `CONTAINER_DATA` en su default (todos los contenedores) — ninguna query Multitenant requiere `ALTER SESSION SET CONTAINER` para ejecutarse.

## Required privileges — Multitenant (Fase 6)

```sql
-- V_$PDBS y V_$CONTAINERS ya otorgados en Fase 2 (docs/ORACLE_READONLY_PRIVILEGES.md#required-privileges-mínimo-para-oracle-core--discovery)
-- para container detection básica. Fase 6 añade el resto del catálogo profundo:

GRANT SELECT ON DBA_PDB_SAVED_STATES         TO estack_diagnostic_role;   -- 12.1.0.2+
GRANT SELECT ON GV_$SERVICES                 TO estack_diagnostic_role;   -- ya otorgado Fase 4, reutilizado aquí
GRANT SELECT ON GV_$ACTIVE_SERVICES          TO estack_diagnostic_role;   -- ya otorgado Fase 4, reutilizado aquí
GRANT SELECT ON GV_$SESSION                  TO estack_diagnostic_role;   -- ya otorgado Fase 4, reutilizado aquí
GRANT SELECT ON CDB_TABLESPACE_USAGE_METRICS TO estack_diagnostic_role;   -- 12.1+
GRANT SELECT ON CDB_TABLESPACES              TO estack_diagnostic_role;   -- 12.1+
GRANT SELECT ON CDB_DATA_FILES               TO estack_diagnostic_role;   -- 12.1+
GRANT SELECT ON CDB_TEMP_FILES               TO estack_diagnostic_role;   -- 12.1+
GRANT SELECT ON GV_$TEMP_SPACE_HEADER        TO estack_diagnostic_role;   -- 12.1+
GRANT SELECT ON GV_$SYSTEM_PARAMETER         TO estack_diagnostic_role;   -- 12.1+
GRANT SELECT ON CDB_USERS                    TO estack_diagnostic_role;   -- 12.1+, sin acceso a password hashes
GRANT SELECT ON CDB_ROLES                    TO estack_diagnostic_role;   -- 12.1+
GRANT SELECT ON CDB_REGISTRY                 TO estack_diagnostic_role;   -- 12.1+
GRANT SELECT ON PDB_PLUG_IN_VIOLATIONS       TO estack_diagnostic_role;   -- 12.1+
GRANT SELECT ON V_$RSRCPDBMETRIC             TO estack_diagnostic_role;   -- 12.1+
GRANT SELECT ON DBA_CDB_RSRC_PLAN_DIRECTIVES TO estack_diagnostic_role;   -- 12.1+
GRANT SELECT ON CDB_LOCKDOWN_PROFILES        TO estack_diagnostic_role;   -- 12.2+
```

`V_$PDBS`/`V_$CONTAINERS` ya están en `docs/ORACLE_READONLY_PRIVILEGES.md` (sección Fase 2, marcados `-- 12c+`) — no se repiten aquí para evitar una segunda fuente de verdad contradictoria.

## Query variant → privilege mapping

| Logical query | Variant | Rango | Objetos (privilegio) |
|---|---|---|---|
| `Q-CDB-PDB-STATE-001` | V1 (12.1) | 12.1 | `V$PDBS` (sin `application_root/application_pdb/application_seed/proxy_pdb/local_undo`) |
| `Q-CDB-PDB-STATE-001` | V2 (12.2+) | 12.2–23.0 | `V$PDBS` (incl. las 5 columnas 12.2+-only) |
| `Q-CDB-PDB-SAVED-STATE-001` | V1 (12.1.0.2+) | 12.1.0.2–23.0 | `DBA_PDB_SAVED_STATES` — no otorgar para un target 12.1.0.0/12.1.0.1, la vista/feature no existe ahí (`docs/PHASE_6_QUERY_COMPATIBILITY_HARDENING.md`) |
| `Q-CDB-PLUGIN-VIOLATIONS-001` | V1 legacy (12.1, sin `CON_ID`) | 12.1 | `PDB_PLUG_IN_VIOLATIONS` (9 columnas) |
| `Q-CDB-PLUGIN-VIOLATIONS-001` | V2 modern (12.2+, con `CON_ID`) | 12.2–23.0 | `PDB_PLUG_IN_VIOLATIONS` (10 columnas) |
| `Q-CDB-RESOURCE-USAGE-001` | única (12.2+) | 12.2–23.0 | `V$RSRCPDBMETRIC` — no otorgar para un target 12.1, la vista no existe ahí (`PARTIALLY_SUPPORTED`) |

Un target de versión fija conocida (ej. siempre 12.1) sólo necesita el grant efectivamente resuelto por el Query Variant Resolver para esa versión; ambas variantes de `Q-CDB-PDB-STATE-001`/`Q-CDB-PLUGIN-VIOLATIONS-001` leen la misma vista, por lo que un único `GRANT SELECT` (ya otorgado arriba) cubre ambas — no hay distinción de objeto por variante en estos casos, a diferencia de `Q-DISC-IDENTITY-001` en Fase 2.

## Identity separation

Ninguna identidad nueva — reutiliza `ESTACK_DIAGNOSTIC_ROLE` (database) ya establecida en `docs/ORACLE_READONLY_PRIVILEGES.md#identity-separation-fase-4-71-del-prompt-de-fase-4`. Todas las vistas de este documento son SQL puro contra la base de datos (CDB), ninguna requiere una identidad de sistema operativo o Broker separada. Para cualquier evidencia que requiera un privilegio no disponible: `INSUFFICIENT_PRIVILEGES` + `MANUAL_COLLECTION_REQUIRED`, nunca escalamiento automático.

## Security rationale

- `SELECT` explícito sobre cada vista, nunca `SELECT_CATALOG_ROLE` como default ciego.
- `CDB_USERS`/`CDB_ROLES` otorgados sólo para los flags `COMMON`/`ORACLE_MAINTAINED` — el e-stack nunca consulta ni transmite columnas de credenciales.
- `PDB_PLUG_IN_VIOLATIONS.MESSAGE`/`.ACTION` se otorgan como parte de la vista (no hay forma de excluir columnas vía `GRANT SELECT` estándar sin una vista propia) pero se sanitizan íntegramente en la capa de evidencia antes de llegar al modelo (ver `docs/MULTITENANT_DIAGNOSTIC_MODEL.md#plug-in-violations-action-siempre-tratado-como-data`) — el privilegio de lectura no implica ejecución ni interpretación como instrucción.
- Ninguna concesión de `ALTER`/`CREATE`/`DROP` sobre ningún objeto Multitenant.

## Limitations

- Esta lista es específica de Fase 6 — se consolida junto a `docs/ORACLE_READONLY_PRIVILEGES.md` (fuente central) para no duplicar Fase 2/4/5.
- `CDB_LOCKDOWN_PROFILES` requiere 12.2+; en 12.1 la query correspondiente simplemente no aplica (no es un privilegio faltante, es una feature inexistente en esa versión).

## Referencia

`docs/ORACLE_READONLY_PRIVILEGES.md`, `policies/identity-model.md`, `SECURITY.md#identidades-y-privilegios`, `queries/REGISTRY.md`.

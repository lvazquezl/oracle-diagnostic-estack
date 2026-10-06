# Consultas de seguridad corregidas, parámetros tipados y lote B3

`/change query|security|documentation` — `CHG-ESTACK-SEC-QUERIES-001`. Rama `change/sec-queries` sobre `main` (`6a9e652`, `v0.24.0-portable-performance`).

## Por qué

El assessment de LAB19S del 2026-10-01, ejecutado desde Windows con la cuenta de mínimo privilegio, dejó expuestos huecos del catálogo de seguridad:

- **Privilegios por rol y roles anidados:** casi no devolvían filas. `ROLE_SYS_PRIVS` y `ROLE_ROLE_PRIVS` solo ven los roles **de la sesión**.
- **Cuentas con credenciales por defecto:** fallaban con ORA-00942. `DBA_USERS_WITH_DEFPWD` no viene en `SELECT_CATALOG_ROLE`.
- **Auditoría unificada, Data Redaction, Database Vault y directorios:** no resolvían nunca, por dos motivos:
  - la auditoría unificada lista acciones como literales (`'GRANT'`, `'AUDIT'`…) que el guard veta;
  - las otras tres tenían dos sentencias en el mismo archivo.
- **Consultas con binds:** fallaban con SP2-0552 en la ruta humana: auditoría tradicional, frecuencia de switches, archived logs de DG, plan, salida de RMAN y las de AWR.

## Consultas corregidas

| Query | Versión | Cambio |
|---|---|---|
| `Q-SEC-ROLE-SYSTEM-PRIVILEGES-001` | 2.0.0 | `DBA_SYS_PRIVS` ⋈ `DBA_ROLES` (todos los roles); V2 (12.1+) agrega `oracle_maintained` |
| `Q-SEC-NESTED-ROLE-GRANTS-001` | 2.0.0 | `DBA_ROLE_PRIVS` ⋈ `DBA_ROLES`; V2 agrega `oracle_maintained` |
| `Q-SEC-UNIFIED-AUDIT-TRAIL-001` | 2.0.0 | Resumen de 7 días por acción y código de retorno (conteos), sin literales vetados ni binds |
| `Q-SEC-TRADITIONAL-AUDIT-001` | 2.0.0 | Resumen de 7 días de `DBA_AUDIT_SESSION`, sin binds. `AUDIT_TRAIL` ya lo da `Q-ORA-PARAMETERS-001` |
| `Q-SEC-DATA-REDACTION-POLICIES-001` | 3.0.0 | Políticas y columnas en una sentencia (`LEFT JOIN`) |
| `Q-SEC-DATABASE-VAULT-STATUS-001` | 2.0.0 | `V$OPTION` + `DBA_REGISTRY` en una sentencia, válida con o sin Database Vault instalado |
| `Q-SEC-DIRECTORIES-001` | 2.0.0 | Directorios y grants en una sentencia (`LEFT JOIN`) |

`tests/test_audit_query_budget.sh` ahora verifica la acotación en el **SQL certificado**, no en la prosa: ventana fija de 31 días o menos, como máximo 500 filas, agregación, y sin texto SQL ni binds.

## Parámetros tipados en la ruta humana

```
python -m human_evidence request --query Q-ORA-REDO-SWITCH-FREQ-001 --target <alias> --version 19c --scope ANA-... \
       --param window_start=2026-10-01T00:00:00 --param window_end=2026-10-02T00:00:00
```

- **Tipos** en [`config/query-parameters.json`](../config/query-parameters.json): entero con rango, timestamp ISO, `sql_id` o nombre Oracle en mayúsculas. Agregar uno es un `/change security`.
- **Validación al pedir la consulta:**
  - sin sus parámetros, se rechaza y lista los que faltan con su formato;
  - un parámetro desconocido o un valor fuera de tipo se rechaza;
  - `window_start` debe ser anterior a `window_end`.
- **Renderizado:** cada `:bind` se sustituye por un literal de su tipo, como `TO_DATE('…', 'YYYY-MM-DD HH24:MI:SS')`, un entero o un texto entre comillas que solo puede contener `[0-9a-z]` o `[A-Z0-9_$#]`. Los literales y comentarios del SQL no se tocan. El resultado vuelve a pasar el guard de solo lectura.
- **Trazabilidad:** la solicitud guarda los parámetros y el `rendered_sql_sha256`. `ingest` vuelve a renderizar y rechaza si el SQL no coincide.
- **Cobertura en 19c:** 124 de 132 queries se pueden pedir (8 de ellas con parámetros). Las 8 restantes no se resuelven:
  - `Q-SEC-PASSWORD-VERIFY-SOURCE-001`: a propósito, porque lee código PL/SQL;
  - `Q-SEC-NETWORK-ENCRYPTION-PARAMS-001`: no certificada;
  - ASH, Statspack, locks, alert log, ASM discovery y GES/GCS: pendientes por guard o por diseño.

## Lote B3 de collectors de seguridad

Son 6 collectors generados por la fábrica, que llevan el catálogo a 61:
- `Q-SEC-ROLE-SYSTEM-PRIVILEGES-001` y `Q-SEC-NESTED-ROLE-GRANTS-001`;
- `Q-SEC-UNIFIED-AUDIT-TRAIL-001` y `Q-SEC-TRADITIONAL-AUDIT-001`;
- `Q-SEC-DIRECTORIES-001` y `Q-SEC-DEFAULT-ACCOUNTS-001`.

Qué expone cada campo:
- Roles, usuarios, directorios y grantees se enmascaran.
- Privilegios (`CREATE SESSION`, `SELECT ANY TABLE`…) y acciones de auditoría (`LOGON`, `GRANT`…) se conservan como vocabulario Oracle (`oracle_term`), solo en los campos `privilege` y `action_name`.
- No se exponen rutas de directorio, texto SQL ni filas crudas de auditoría.

**Data Redaction y Database Vault no entran al lote:** sus queries declaran licencia de opción, y el gateway las marca `LICENSE_RESTRICTED` si el target no la tiene confirmada. Quedan corregidas para la ruta humana.

## Privilegios de la cuenta de diagnóstico

Además de `CREATE SESSION`, `SELECT_CATALOG_ROLE` y `CONTAINER_DATA` en CDB:

| Para | Grant | Nota |
|---|---|---|
| Resumen de auditoría unificada | `GRANT AUDIT_VIEWER TO <usuario>` | El rol no trae privilegios de sistema; verificado en el lab: el guard de sesión siguió aceptando la cuenta |
| Cuentas con credenciales por defecto | `GRANT SELECT ON SYS.DBA_USERS_WITH_DEFPWD TO <usuario>` | No viene en `SELECT_CATALOG_ROLE` |

En un CDB conectado a `CDB$ROOT`, agrega `CONTAINER=CURRENT` (usuario común `C##…`).

## Validación en el lab (`lab-ol8-19c`, `LAB-OL8-19C-CDBROOT-ASM`, `3daf27f`, 2026-10-06)

El DBA otorgó `AUDIT_VIEWER` y `SELECT ON DBA_USERS_WITH_DEFPWD`. La identidad siguió `FIELD_VALIDATED` y la sesión siguió sin privilegios de sistema extra. Los 6 collectors corrieron en real; en los 6, el `query_sha256` coincide con el SQL versionado.

| Collector | Request | Evidencia | `query_sha256` | Resultado |
|---|---|---|---|---|
| `Q-SEC-ROLE-SYSTEM-PRIVILEGES-001` | `REQ-90963aad46d6` | `EVR-fa2ff3b92d7190618bc162dd` | `084cda2ad5a1…` | 100 filas (truncado al tope del perfil del lab); privilegios de todos los roles, no sólo los de la sesión; nombres de rol enmascarados, privilegios legibles |
| `Q-SEC-NESTED-ROLE-GRANTS-001` | `REQ-4ac24577d4ee` | `EVR-43d1811cba6651c1bd4c7af9` | `4880b5bd1d36…` | 59 relaciones rol→rol de toda la base (con la versión 1.0.0 la cuenta de diagnóstico veía casi ninguna) |
| `Q-SEC-UNIFIED-AUDIT-TRAIL-001` | `REQ-2898520a8c44` | `EVR-3394c70a80ecd0de05ebbc76` | `1b2c3efb82e9…` | 1 fila: el `GRANT` del DBA para esta prueba (antes la query no resolvía nunca) |
| `Q-SEC-TRADITIONAL-AUDIT-001` | `REQ-0861a7337409` | `EVR-bc2b49f5615418c9d42f6f8c` | `3b28d2a9964b…` | 0 filas (sin auditoría tradicional de sesiones en 7 días); corre sin binds |
| `Q-SEC-DIRECTORIES-001` | `REQ-843adfa76d49` | `EVR-b07db39c1e40f094ac049aa2` | `f84652b03f91…` | 15 directorios y sus grants READ/WRITE; nombres enmascarados, rutas no expuestas |
| `Q-SEC-DEFAULT-ACCOUNTS-001` | `REQ-12ea943f6511` | `EVR-26dd570023a91e84c0b39cd4` | `f40fce7b860b…` | 1 cuenta mantenida por Oracle con credenciales por defecto, `EXPIRED & LOCKED`; requiere el grant de `DBA_USERS_WITH_DEFPWD` |

## Registro del cambio

| Fase | Resultado |
|---|---|
| DETECT GAP | Assessment de LAB19S desde Windows (2026-10-01): privilegios por rol casi vacíos, ORA-00942, consultas que no resolvían y binds con SP2-0552 |
| PROPOSAL | Corregir las queries, parámetros tipados para la ruta humana, lote B3 de collectors de seguridad |
| IMPLEMENT | 7 queries, `config/query-parameters.json`, `human_evidence/params.py`, `human_evidence/cli.py` (`--param`), lote `lots/B3-security.json`, 14 definiciones en la base de conocimiento, `oracle_term` en `privilege` y `action_name`, matriz de compatibilidad, registro de madurez |
| TEST | P17 24/24 (6 casos nuevos de parámetros); P18 21/21 (3 nuevos de B3); presupuesto de auditoría sobre el SQL real |
| SECURITY | 8/8 mutaciones detectadas: binds sin renderizar, rango entero ignorado, timestamp sin validar, literales no saltados, parámetros faltantes tolerados, SQL renderizado sin verificar en `ingest`, orden de ventana ignorado, `oracle_term` en cualquier campo. Además, la prueba de presupuesto detecta ventanas de más de 31 días, más de 500 filas y texto SQL |
| REGRESSION | 972/972 en macOS (bash 5.3). La primera corrida dio 968/972: las nuevas variantes 12.1+ usaban `max: latest`, y la política exige validar cada versión futura. Se fijó `23.0`; el SQL validado en el lab no cambió (mismo hash) |
| LAB | 6/6 en real (arriba) |
| HUMAN REVIEW | Aprobado: `AUTH-SEC-QUERIES-001`, revisor `REV-DBAMANAGER`, `2026-10-06T18:21:20Z`, digest `fdbcd32a…c9966e63`. PROMOTE: PR #33, merge `eec2e38`; CI en verde en los 6 jobs (ubuntu, macOS y Windows con Python 3.13 y 3.14) |

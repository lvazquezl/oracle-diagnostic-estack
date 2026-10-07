# Cobertura de la PDB en el assessment

`/change query|security|compatibility|documentation` — `CHG-ESTACK-PDB-COVERAGE-001`. Rama `change/pdb-coverage` sobre `main` (`d3f2818`, `v0.27.0-awr-window-deltas`). Origen: REC-0012 de `ANA-20261007-001` (FND-0021, FND-0019 y FND-0015), señalado por 4 de los 11 agentes que revisaron ese assessment.

## Por qué

La cuenta de diagnóstico se conecta a `CDB$ROOT`. Desde ahí, las vistas `DBA_*` solo describen el root. El assessment del 2026-10-07 decía "sin objetos inválidos, sin jobs fallidos, 3 directorios…", pero eso valía solo para el root: **la PDB de aplicación no se evaluaba** en objetos, jobs, componentes ni seguridad.

Además, varias queries certificadas útiles no estaban expuestas en el gateway:
- estado de las PDB;
- servicios;
- plug-in violations;
- políticas de auditoría habilitadas;
- perfiles de contraseña;
- usuarios del password file;
- configuración RMAN.

## Verificación previa en el lab (GAP ANALYSIS)

El DBA ejecutó un script de solo lectura (conteos por `con_id`, nombres de columnas) como `C##ESTACK_DIAG` en `CDB$ROOT` (`CONTAINER_DATA = (CDB$ROOT, PRUEBAS)`).

| Resultado | Vistas |
|---|---|
| Existen y devuelven filas de `con_id` 1 y 3 | `CDB_OBJECTS`, `CDB_SCHEDULER_JOBS`, `CDB_REGISTRY`, `CDB_SYS_PRIVS`, `CDB_ROLES`, `CDB_ROLE_PRIVS`, `CDB_USERS`, `CDB_DIRECTORIES`, `CDB_TAB_PRIVS`, `CDB_PROFILES`, `CDB_AUDIT_SESSION`, `CDB_UNIFIED_AUDIT_TRAIL` |
| ORA-00942 | `CDB_USERS_WITH_DEFPWD`: no existe (ausente de la Database Reference 19c). `PDB_PLUG_IN_VIOLATIONS`: existe, pero falta el grant |
| Columnas | `AUDIT_UNIFIED_ENABLED_POLICIES` en 19c: `POLICY_NAME`, `ENABLED_OPTION`, `ENTITY_NAME`, `ENTITY_TYPE`, `SUCCESS`, `FAILURE` |
| Otros | `V$OPTION`: Unified Auditing, DV y OLS en FALSE (modo mixto; DV y OLS no habilitados). `V$RMAN_CONFIGURATION`: sin filas |

La PDB tiene datos que el root no ve: 42 usuarios contra 40, 72 registros de perfiles contra 54 y 22 jobs propios.

Documentación de Oracle consultada:
- [AUDIT_UNIFIED_ENABLED_POLICIES (19c)](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/AUDIT_UNIFIED_ENABLED_POLICIES.html);
- [AUDIT_UNIFIED_ENABLED_POLICIES (18c)](https://docs.oracle.com/en/database/oracle/oracle-database/18/refrn/AUDIT_UNIFIED_ENABLED_POLICIES.html): `USER_NAME` y `ENABLED_OPT` se deprecan en 12.2 y llegan `ENTITY_*`;
- [UNIFIED_AUDIT_TRAIL (12.2)](https://docs.oracle.com/en/database/oracle/oracle-database/12.2/refrn/UNIFIED_AUDIT_TRAIL.html): no menciona `CDB_UNIFIED_AUDIT_TRAIL`;
- [DBA_USERS_WITH_DEFPWD (19c)](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/DBA_USERS_WITH_DEFPWD.html): sin variante `CDB_*`.

## Variantes `CDB_*` (12.1+)

Cada query conserva su ID de collector. La V1 de 10g/11g (o anterior) no cambia. La V2 lee `CDB_*` y agrega `con_id`; en non-CDB, `con_id` es 0.

| Query | Versión | V2 |
|---|---|---|
| `Q-ORA-INVALID-OBJECTS-001` | 2.0.0 | `CDB_OBJECTS`; `cost_class` sube a MEDIUM |
| `Q-ORA-OBJECTS-INVENTORY-001` | 2.0.0 | `CDB_OBJECTS` |
| `Q-ORA-JOBS-SUMMARY-001` | 2.0.0 | `CDB_SCHEDULER_JOBS` |
| `Q-ORA-COMPONENTS-001` | 2.0.0 | `CDB_REGISTRY` |
| `Q-SEC-ROLE-SYSTEM-PRIVILEGES-001` | 3.0.0 | `CDB_SYS_PRIVS`/`CDB_ROLES`, **solo roles propios**. Los ~1850 privilegios estándar de los roles de Oracle llenaban el tope de 100 filas (FND-0003) |
| `Q-SEC-NESTED-ROLE-GRANTS-001` | 3.0.0 | `CDB_ROLE_PRIVS`/`CDB_ROLES`, solo roles propios |
| `Q-SEC-DIRECTORIES-001` | 3.0.0 | `CDB_DIRECTORIES`/`CDB_TAB_PRIVS`; ya no selecciona `directory_path` |
| `Q-SEC-UNIFIED-AUDIT-TRAIL-001` | 3.0.0 | V2 **19c+** con `CDB_UNIFIED_AUDIT_TRAIL`; 12.1–18c sigue con `UNIFIED_AUDIT_TRAIL`. Se acota a 19c porque la vista no está documentada en 12.2 |
| `Q-SEC-TRADITIONAL-AUDIT-001` | 3.0.0 | `CDB_AUDIT_SESSION` |

**Quedan limitados al root** (no existe vista `CDB_*`):
- `Q-SEC-DEFAULT-ACCOUNTS-001` (`DBA_USERS_WITH_DEFPWD`);
- `Q-SEC-PROXY-AUTHENTICATION-001` (`PROXY_USERS`);
- `Q-SEC-UNIFIED-AUDIT-POLICIES-001` (`AUDIT_UNIFIED_ENABLED_POLICIES`).

Para cubrir la PDB en esos casos haría falta conectarse a ella; queda fuera de este cambio.

## Lote B5: queries certificadas expuestas

| Collector | Versión | Qué se cambió para exponerlo |
|---|---|---|
| `Q-CDB-PDB-STATE-001` | 2.0.0 | `open_time` → `hours_since_open` (calculado en la base, UTC); `name` → `pdb_name` (MASK) |
| `Q-CDB-SERVICES-001` | 1.0.0 | Sin cambios; `service_name` MASK |
| `Q-CDB-PLUGIN-VIOLATIONS-001` | 4.0.0 | Resumen por contenedor, nombre, tipo, estado y causa. Sin `message`, `action`, `line`, `error_number` ni `time`. Requiere `SELECT ON SYS.PDB_PLUG_IN_VIOLATIONS` |
| `Q-SEC-UNIFIED-AUDIT-POLICIES-001` | 2.0.0 | V1 12.1 (`USER_NAME`) y V2 12.2+ (`ENTITY_*`). Política: solo `ORA_*`/`ORA$*`, las demás como `CUSTOM`. Usuarios y roles: solo alcance (`ALL_USERS`/`SPECIFIC`) y conteo |
| `Q-SEC-PASSWORD-PROFILES-001` | 2.0.0 | V2 `CDB_PROFILES`. `limit` → `limit_keyword` (enum) + `limit_value` (número). Las funciones de verificación propias no se exponen |
| `Q-SEC-ADMIN-PRIVILEGES-001` | 1.0.0 | Sin cambios; `username` MASK |
| `Q-RMAN-CONFIGURATION-001` | 2.0.0 | `value` nunca sale (puede llevar rutas): se reduce a `setting` (enum) + `setting_number` |

**Gateway:** `ORACLE_TERM_FIELDS` agrega `policy_name`, `cause` y `config_name`. El SQL garantiza que solo salgan valores de Oracle.

**Base de conocimiento de la fábrica:** 41 campos nuevos (enums cerrados, identificadores MASK y números acotados).

**Catálogo:** de 65 a **72 collectors**.

## Privilegios nuevos (DBA, ejecución humana)

```sql
-- como SYS en CDB$ROOT
GRANT SELECT ON SYS.PDB_PLUG_IN_VIOLATIONS TO C##ESTACK_DIAG CONTAINER=CURRENT;
```

El resto queda cubierto por `SELECT_CATALOG_ROLE` + `CONTAINER_DATA` (verificado en el lab).

## Registro del cambio

| Fase | Resultado |
|---|---|
| DETECT GAP | Revisión por especialistas de `ANA-20261007-001`: la PDB no se evaluaba (FND-0021) |
| GAP ANALYSIS | Script de solo lectura en el lab (arriba) y documentación de Oracle |
| IMPLEMENT | 14 queries; matriz de compatibilidad; 8 vistas en `views.yaml`; 41 campos y lote B5 en la fábrica; `ORACLE_TERM_FIELDS`; fixture `fixture-cdb-root-19c`; registro de madurez (72 collectors, 140 componentes); `Q-DICT-VERIFY-001..005` regeneradas |
| TEST | P18 27/27 (3 casos nuevos: variantes `CDB_*`, nada de texto libre ni valores crudos en B5, políticas propias como `CUSTOM`); 4 pruebas de plug-in violations actualizadas al nuevo contrato, que además verifican que no se selecciona texto libre; resolución de variantes 10g/11g |
| SECURITY | 10/10 mutaciones detectadas: volver a `DBA_*`, V2 sin `con_id` como columna, sin filtro de roles propios, `message` expuesto, `value` RMAN crudo, nombres de políticas propias, `directory_path`, `limit` crudo, `CDB_UNIFIED_AUDIT_TRAIL` antes de 19c y `policy_name` fuera de `oracle_term` |
| REGRESSION | 973/973 en macOS (bash 5.3); fábrica y `dict_verify` sin drift |
| LAB | **Pendiente:** grant de `PDB_PLUG_IN_VIOLATIONS`, allowlist del lab y validación en campo de los 16 collectors (9 modificados, 7 nuevos) y las 5 `Q-DICT-VERIFY` regeneradas. Hasta entonces quedan `DOCUMENTATION_ONLY` (14 validaciones retiradas del registro por cambio de SQL) |
| HUMAN REVIEW | Pendiente |

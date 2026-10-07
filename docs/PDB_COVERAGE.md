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

## Validación en el lab (`lab-ol8-19c`, `LAB-OL8-19C-CDBROOT-ASM`, `e5bbf64`, 2026-10-07T20:12Z)

El DBA otorgó `SELECT ON SYS.PDB_PLUG_IN_VIOLATIONS`. Los 21 collectors corrieron en real; en los 21, el `query_sha256` coincide con el SQL versionado.

| Collector | Request | Evidencia | Resultado |
|---|---|---|---|
| `Q-ORA-INVALID-OBJECTS-001` | `REQ-dab29ff7cc81` | `EVR-ca10fe8b21194f012943e3f7` | 0 inválidos en el root **y en la PDB** |
| `Q-ORA-OBJECTS-INVENTORY-001` | `REQ-e97ca8dfc404` | `EVR-f5c1f7768e366d97780aab7e` | Filas de `con_id` 1 y 3 |
| `Q-ORA-JOBS-SUMMARY-001` | `REQ-56e903858235` | `EVR-cfc3a0d8dd50afbfb82bc3ac` | 0 jobs fallidos en ambos contenedores |
| `Q-ORA-COMPONENTS-001` | `REQ-13a41b263d0e` | `EVR-3d54e440c681f5c5c2ed0cb2` | 30 filas: 15 componentes por contenedor, todos `VALID` (RAC `OPTION OFF`) |
| `Q-SEC-ROLE-SYSTEM-PRIVILEGES-001` | `REQ-974e14467e88` | `EVR-43fb571afe38e6f414bb1af5` | 0 filas: no hay roles propios en ningún contenedor (los 94 roles por contenedor son de Oracle) |
| `Q-SEC-NESTED-ROLE-GRANTS-001` | `REQ-565a14e6cd58` | `EVR-3e7ea4d202eb8ff62ed6b01b` | 0 filas (consistente) |
| `Q-SEC-DIRECTORIES-001` | `REQ-154931d84ffe` | `EVR-7cf8e04a7f2ec35465ac1848` | 36 filas: 15 directorios en el root y 13 en la PDB, con grants |
| `Q-SEC-UNIFIED-AUDIT-TRAIL-001` | `REQ-2c591f8990b5` | `EVR-d3d68fc2f304d10aba2b8997` | `LOGON` fallidos (ORA-01017, 3 eventos) y `GRANT`; vía `CDB_UNIFIED_AUDIT_TRAIL` |
| `Q-SEC-TRADITIONAL-AUDIT-001` | `REQ-f7591d4c2791` | `EVR-6d3e9826a4261305b2e85002` | 0 filas en 7 días |
| `Q-CDB-PDB-STATE-001` | `REQ-3b9f003ecc22` | `EVR-2cba1bb5d35b7506291a3977` | 1 PDB `READ WRITE`, sin restricción, `local_undo` = 1, abierta hace 2.66 h |
| `Q-CDB-SERVICES-001` | `REQ-97aa1bd1a842` | `EVR-bf38b4c166b8db685b1b7140` | 2 servicios de la PDB, activos en la instancia 1 |
| `Q-CDB-PLUGIN-VIOLATIONS-001` | `REQ-e7078cd8040f` | `EVR-a00d9f92343c06f2bf4eef45` | 0 violaciones; el grant nuevo funciona |
| `Q-SEC-UNIFIED-AUDIT-POLICIES-001` | `REQ-5ead3056146e` | `EVR-a938f06e2dc392ed8f9bf923` | `ORA_LOGON_FAILURES` (solo fallidos) y `ORA_SECURECONFIG`, para todos los usuarios |
| `Q-SEC-PASSWORD-PROFILES-001` | `REQ-88081533a9a8` | `EVR-7e08f8e18e05357850cf43bf` | 56 filas: la PDB tiene un perfil propio que el root no tiene; funciones de verificación: `NULL`/`ORACLE_FUNCTION` |
| `Q-SEC-ADMIN-PRIVILEGES-001` | `REQ-f47a3888cead` | `EVR-a32cf7fa6360d042dfe026f7` | 1 usuario común con SYSDBA/SYSOPER |
| `Q-RMAN-CONFIGURATION-001` | `REQ-6c97f0202fd0` | `EVR-6d7ae260cd158dbc83fba039` | 0 filas: ningún `CONFIGURE` persistente (confirma FND-0001 de ANA-20261007-001) |
| `Q-DICT-VERIFY-001`..`005` | `REQ-b835cc145dd4`, `REQ-9eff15a9ca31`, `REQ-f903143edaad`, `REQ-bddb07e90592`, `REQ-f8bbaf089738` | `EVR-be249eb842c40a903654aa8c`, `EVR-1329a39c64a042ecbdd0c366`, `EVR-606ea286a02e0595a1a1321b`, `EVR-8e19cc250c7357885d6ec121`, `EVR-4668a4c569aa637c492d0634` | 508 vistas/columnas declaradas verificadas, incluidas las 8 `CDB_*` nuevas; solo faltan `STATS$*` (Statspack no instalado, ya conocido) |

Validaciones registradas en `config/field-validation-registry.json` (21 entradas; 67 en total).

## Registro del cambio

| Fase | Resultado |
|---|---|
| DETECT GAP | Revisión por especialistas de `ANA-20261007-001`: la PDB no se evaluaba (FND-0021) |
| GAP ANALYSIS | Script de solo lectura en el lab (arriba) y documentación de Oracle |
| IMPLEMENT | 14 queries; matriz de compatibilidad; 8 vistas en `views.yaml`; 41 campos y lote B5 en la fábrica; `ORACLE_TERM_FIELDS`; fixture `fixture-cdb-root-19c`; registro de madurez (72 collectors, 140 componentes); `Q-DICT-VERIFY-001..005` regeneradas |
| TEST | P18 27/27 (3 casos nuevos: variantes `CDB_*`, nada de texto libre ni valores crudos en B5, políticas propias como `CUSTOM`); 4 pruebas de plug-in violations actualizadas al nuevo contrato, que además verifican que no se selecciona texto libre; resolución de variantes 10g/11g |
| SECURITY | 10/10 mutaciones detectadas: volver a `DBA_*`, V2 sin `con_id` como columna, sin filtro de roles propios, `message` expuesto, `value` RMAN crudo, nombres de políticas propias, `directory_path`, `limit` crudo, `CDB_UNIFIED_AUDIT_TRAIL` antes de 19c y `policy_name` fuera de `oracle_term` |
| REGRESSION | 973/973 en macOS (bash 5.3); fábrica y `dict_verify` sin drift |
| LAB | 21/21 en real tras el grant y la allowlist (67 collectors en el lab); `FIELD_VALIDATED` en `LAB-OL8-19C-CDBROOT-ASM` (arriba). Las 14 validaciones retiradas por cambio de SQL se reemplazaron por las nuevas |
| HUMAN REVIEW | Pendiente |

# Lote B8: RMAN, multitenant, ASM y locks

`/change query|security|compatibility|skill|documentation` — `CHG-ESTACK-B8-OPS-COVERAGE-001`. Rama `change/b8-ops-coverage` sobre `main` (`af0ec38`).

Origen: el plan de lotes acordado con el DBA (B8: RMAN, multitenant, ASM y rendimiento). El gateway no exponía 31 queries certificadas de esos dominios, así que un assessment no podía responder si los archivelogs y los datafiles tienen backup, si hay piezas expiradas, cómo están los discos ASM por failure group, qué PDBs abren solas tras un reinicio, cuánto consume cada PDB ni qué enqueues hay activos.

## Análisis de las 31 queries

**Se exponen 10.** Siete se reescriben como agregados en la base, sin rutas, handles, tags, nombres de archivo, `SID`, `SQL_ID`, identificadores de objeto ni fechas absolutas. Tres se exponen sin cambio de SQL, con los nombres enmascarados.

| Query | Versión | Qué entrega |
|---|---|---|
| `Q-RMAN-ARCHIVED-LOG-COVERAGE-001` | 2.0.0 | Por thread de la encarnación actual: archivelogs de las últimas 24 h, en disco, sin backup, y horas desde el más viejo sin backup y desde el último archivado |
| `Q-RMAN-BACKUP-DATAFILE-001` | 2.0.0 | Por contenedor: datafiles, sin ningún backup, sin full/level 0, y el peor atraso del último backup y del último full |
| `Q-RMAN-BACKUP-PIECE-001` | 2.0.0 | Por dispositivo (`DISK`, `SBT_TAPE`, `OTHER`) y estado (`AVAILABLE`, `EXPIRED`, `UNAVAILABLE`): piezas, bytes y antigüedad |
| `Q-CDB-LOCKDOWN-001` | 2.0.0 | Por perfil (de Oracle o propio), tipo y estado de regla: cantidad de reglas |
| `Q-CDB-RESOURCE-MANAGER-001` | 2.0.0 | Directivas por plan, con el plan activo, el tipo de directiva, shares y límites |
| `Q-ASM-DISKS-001` | 2.0.0 | Por disk group y failure group: discos, capacidad, no miembros, fuera de línea, en estado anormal y errores; sobre `V$ASM_DISK_STAT` |
| `Q-PERF-LOCKS-001` | 2.0.0 | Por contenedor, tipo de enqueue y `lock_mode`: cantidad, en espera, bloqueando y segundos máximos en el modo |
| `Q-CDB-PDB-SAVED-STATE-001` | 2.0.0, sin cambio | Estado guardado por PDB e instancia |
| `Q-CDB-RESOURCE-USAGE-001` | 2.0.0, sin cambio | CPU, sesiones, parallel servers, SGA/PGA e I/O por PDB en el último minuto |
| `Q-CDB-SESSION-DIST-001` | 1.0.0, sin cambio | Sesiones de usuario por PDB, instancia y servicio |

**Se descartan 21, cada una con su motivo:**

| Motivo | Queries |
|---|---|
| Ya cubiertas por un collector expuesto | `Q-RMAN-BACKUP-JOB-001` y `Q-RMAN-STATUS-001` (`Q-RMAN-JOB-SUMMARY-001`); `Q-RMAN-BACKUP-SET-001`, `Q-RMAN-CONTROLFILE-BACKUP-001` y `Q-RMAN-SPFILE-BACKUP-001` (`Q-RMAN-BACKUP-FRESHNESS-001`); `Q-RMAN-ARCHIVELOG-BACKUP-001` (incluida en la nueva cobertura de archivelogs); `Q-RMAN-CONTROLFILE-RECORD-SECTION-001` (`Q-ORA-CONTROLFILE-001`); `Q-CDB-COMPONENTS-001` (`Q-ORA-COMPONENTS-001` ya lee `CDB_REGISTRY`); `Q-CDB-CONTAINERS-001` (`Q-CDB-PDB-STATE-001`); `Q-CDB-ROLES-001` y `Q-CDB-USERS-001` (`Q-SEC-ROLES-001` y `Q-SEC-ACCOUNT-INVENTORY-001`, B7); `Q-PERF-DBTIME-001`, `Q-PERF-TOPSQL-001`, `Q-PERF-WAIT-AWR-001` y `Q-PERF-WAIT-ASH-001` (lote B4 y las rutas sin licencia ya expuestas) |
| Necesitan un valor de entrada (bind) que el gateway no acepta | `Q-RMAN-OUTPUT-001` (además devuelve texto libre), `Q-PERF-PLAN-001` y `Q-PERF-PLAN-HIST-001` (`SQL_ID`), `Q-PERF-WAIT-STATSPACK-001` (ventana de snapshots; Statspack no está instalado en el lab) |
| Valores crudos sin valor diagnóstico agregado | `Q-CDB-PARAMETERS-001` (valores de parámetros por PDB) |
| No observable desde la instancia de base de datos | `Q-ASM-REBALANCE-001`: `V$ASM_OPERATION` solo tiene filas en la instancia ASM |

## Cambios

**Defensa de solo lectura.** El guard del gateway rechazaba `V$LOCK` porque `lock` es un verbo prohibido. Ahora acepta `lock` solo precedido de `$` (nombre de vista). `LOCK TABLE` sigue rechazado: P13 agrega un caso que solo la palabra `lock` detecta. La copia del guard en `scripts/dict_verify/generate.py` cambia igual, y las sondas del diccionario ahora verifican también `V$LOCK`.

**Campos.**
- 59 definiciones nuevas en `config/collector-factory/columns.json`: conteos y horas acotados; enums cerrados (`device_type`, `piece_status`, `rule_type`, `rule_status`, `plan_kind`, `plan_active`, `directive_kind`, `lock_type`, `lock_mode`).
- Identificadores enmascarados: `lockdown_profile`, `plan_name`, `con_name` (alias `pdb`, el mismo de `pdb_name`) y `failgroup`.
- `state` agrega `OPEN` y `OPEN READ ONLY`; el lote lo restringe a esos dos valores en `Q-CDB-PDB-SAVED-STATE-001`.

**Skills.** 10 skills (1.1.0) documentan qué entrega ahora el gateway y de qué collector sale el detalle que ya no se expone:
- `asm/failure-groups`: conserva el failure group, enmascarado y con capacidad.
- `asm/disks` y `performance/locking`: el detalle por sesión sale de `Q-PERF-BLOCKING-001`.
- `rman/archivelog-backup` y `rman/dataguard-awareness`: `APPLIED` sale de `Q-DG-ARCHIVED-LOG-001`.
- `rman/backup-inventory`, `rman/incremental-backup` y `rman/restore-readiness`: se apoyan en `Q-RMAN-BACKUP-FRESHNESS-001`.
- `multitenant/lockdown-profiles` y `multitenant/resource-manager`.

**Diccionario y compatibilidad.**
- Columnas nuevas en `V$ARCHIVED_LOG`, `V$DATABASE`, `V$DATAFILE` y `V$LOCK`.
- Vistas nuevas: `V$ASM_DISK_STAT` y `V$RSRC_PLAN`.
- Variantes explícitas en la matriz de compatibilidad.
- Resolvers 10g, 11g y 12c: lockdown (12.2+), Resource Manager (12.1+) y ASM (11.2+) sin variante donde no existen.

**Pruebas que cambian con el contrato.** `tests/test_backup_piece_query.sh` ya no exige `HANDLE` tokenizado: exige que no se seleccione. `tests/test_dict_verify_queries_match_dictionary.sh` ya no espera `V$LOCK` omitida.

**Validaciones en campo retiradas** hasta revalidar en el lab: las sondas `Q-DICT-VERIFY-001`..`005` (el registro pasa de 86 a 81). Ninguna de las 10 queries tenía validación previa.

## Validación en el lab

`lab-ol8-19c`, contexto `LAB-OL8-19C-CDBROOT-ASM` (19.32, `CDB$ROOT`, ASM), 2026-11-10, con la cuenta de diagnóstico (`SELECT_CATALOG_ROLE` + `CONTAINER_DATA`): **no hizo falta ningún privilegio nuevo**. Todas las respuestas, `REAL` y `SANITIZED`, sin valores descartados.

| Collector | Filas | Lo que confirma | Evidencia |
|---|---|---|---|
| `Q-RMAN-ARCHIVED-LOG-COVERAGE-001` | 1 | Thread 1: 14 archivelogs en disco sin backup, el más viejo de hace 1142 h; último archivado hace 158 h; ninguno en 24 h | `EVR-7dd59e5d42df6aec04a64788` / `REQ-2216e1519df7` |
| `Q-RMAN-BACKUP-DATAFILE-001` | 2 | Root y PDB: 4 datafiles cada uno, todos con backup full; el último, de hace 1149 h | `EVR-223af2286fa3f7422a73eca6` / `REQ-e06d1ddcce2b` |
| `Q-RMAN-BACKUP-PIECE-001` | 1 | 16 piezas `DISK` `AVAILABLE` (2.4 GiB), de hace 1149 a 1176 h; sin expiradas | `EVR-e2883957240b25e4354348d8` / `REQ-f5f68387ed40` |
| `Q-CDB-LOCKDOWN-001` | 3 | Los 3 perfiles de Oracle, sin reglas (`rule_status` `EMPTY`, valor confirmado) | `EVR-3b8586176558ae7fb35f8cb4` / `REQ-fb5e2119a68c` |
| `Q-CDB-PDB-SAVED-STATE-001` | 1 | La PDB tiene estado guardado `OPEN` (valor confirmado), no restringida | `EVR-705ba5be9d27e8ce4b1048f3` / `REQ-67a47725429b` |
| `Q-CDB-RESOURCE-MANAGER-001` | 8 | 4 planes de Oracle con directiva por defecto y de autotask; uno activo (`plan_active` `YES`), cuyas directivas no fijan límites | `EVR-6a0a5b4580234c2414d27b27` / `REQ-6814e8f614fe` |
| `Q-CDB-RESOURCE-USAGE-001` | 1 | La PDB: 6 CPUs, límite 100 %, sin carga; SGA 206 MiB, I/O mínimo | `EVR-b44ac35888896447eedb31f1` / `REQ-f37798f68fe6` |
| `Q-CDB-SESSION-DIST-001` | 0 | Sin sesiones de usuario en las PDBs (las del root se excluyen por diseño) | `EVR-e981642420b380226d647f6f` / `REQ-e7c42b8d62d9` |
| `Q-ASM-DISKS-001` | 2 | Disk group 1: 2 failure groups de 1 disco y 20 476 MB cada uno; sin discos anormales ni errores | `EVR-52d52d43b8c4d7f4e1bef502` / `REQ-f311c4ce2cc7` |
| `Q-PERF-LOCKS-001` | 11 | Solo enqueues de background a nivel instancia (`con_id` 0): `AE`, `CF`, `MR`, `RT`, `TS`, `XR` y `OTHER`; ninguno en espera ni bloqueando | `EVR-d17c3588c4e1f99e6f3bf0dc` / `REQ-dd25d50a3adb` |

**Sondas del diccionario** (regeneradas por este cambio): las 5 confirman todas las vistas y columnas declaradas, incluidas `V$LOCK`, `V$ASM_DISK_STAT`, `V$RSRC_PLAN` y las columnas nuevas de `V$ARCHIVED_LOG`, `V$DATABASE` y `V$DATAFILE`. La única diferencia es `STATS$SNAPSHOT` y `STATS$SYSTEM_EVENT` como `VIEW_NOT_FOUND` (Statspack no instalado, igual que antes).

| Sonda | Evidencia |
|---|---|
| `Q-DICT-VERIFY-001` | `EVR-b9825a2e40f6448aaa56b4d4` / `REQ-ce6986d04955` |
| `Q-DICT-VERIFY-002` | `EVR-6759ff8e91110a9382d5f453` / `REQ-4b25f0f149d6` |
| `Q-DICT-VERIFY-003` | `EVR-2a10734ca0f2e3a1dfa8a57b` / `REQ-fa5553bbee9d` |
| `Q-DICT-VERIFY-004` | `EVR-5d30e9397729d0e680ac9d2f` / `REQ-62d6d96d9e56` |
| `Q-DICT-VERIFY-005` | `EVR-a163e4e2c2ad1e52c2bb9c6f` / `REQ-fb22043e7cbf` |

**Revisión de los especialistas:**
1. **`oracle-backup-recovery-analyst`:** los collectors cuentan lo que hay y son coherentes entre sí. Las piezas y los datafiles son del mismo backup de hace 1149 h; los 14 archivelogs sin backup son posteriores. Es un hallazgo real del lab, no del stack: el último backup tiene unos 48 días y hay archivelogs sin proteger desde entonces. En un ambiente real, eso sería un riesgo de recuperación (`RISK`).
2. **`oracle-multitenant-analyst`:** el saved state `OPEN` y los valores `EMPTY` de lockdown confirman los enums. La PDB tiene saved state y abrirá sola tras un reinicio. `Q-CDB-SESSION-DIST-001` devuelve 0 filas porque el lab no tiene sesiones de aplicación; la query corre y su forma está validada, pero falta verla con datos.
3. **`oracle-asm-storage-analyst`:** dos failure groups de igual capacidad en el mismo disk group es lo esperable con redundancia `NORMAL`, y `failgroup` enmascarado alcanza para compararlos.
4. **`oracle-performance-analyst`:** en un lab ocioso solo hay enqueues de background, y `OTHER` agrupa tipos internos sin valor diagnóstico. No requiere cambio.

## Registro del cambio

| Fase | Resultado |
|---|---|
| DETECT GAP | 31 queries certificadas de RMAN, multitenant, rendimiento y ASM sin exponer |
| CHANGE REQUEST | `CHG-ESTACK-B8-OPS-COVERAGE-001`, tipos `query`, `security`, `compatibility`, `skill` y `documentation` |
| GAP ANALYSIS | 10 expuestas (7 reescritas, 3 sin cambio de SQL) y 21 descartadas con motivo (arriba) |
| IMPACT ANALYSIS | Catálogo de 91 a 101 collectors; sin privilegio nuevo esperado (`SELECT_CATALOG_ROLE` + `CONTAINER_DATA`; se confirma en el lab); sin licencia; sin tools nuevas; guard de solo lectura ajustado (`V$LOCK`) |
| PROPOSAL | Este documento |
| IMPLEMENT | 7 contratos 2.0.0 y 3 con notas; 59 campos y lote B8; diccionario, matriz, registro de queries, registro de madurez (169 componentes), target de fixtures; 10 skills 1.1.0; sondas del diccionario regeneradas |
| TEST | P18 39/39 (2 casos nuevos); P13 14/14 con `V$LOCK` aceptada y `LOCK TABLE` rechazado |
| SECURITY | 12/12 mutaciones detectadas: ruta del archivelog, `HANDLE`, `SID`, `V$ASM_DISK` con discovery, cláusulas de lockdown, plan activo, cobertura sin contenedor, perfil de lockdown en `KEEP`, override de `state` quitado, guard que vuelve a rechazar `V$LOCK`, guard sin `lock` y `SQL_ID` por join con `V$SESSION` |
| REGRESSION | 974/974 en macOS (bash 5.3), antes y después del lab |
| LAB | Los 10 collectors y las 5 sondas `FIELD_VALIDATED` en `LAB-OL8-19C-CDBROOT-ASM` (15 registros nuevos; el registro pasa de 81 a 96). Sin privilegios nuevos |
| HUMAN REVIEW | Aprobado: `AUTH-B8-OPS-COVERAGE-001`, revisor `REV-DBAMANAGER`, `2026-11-10T18:29:46Z`, contra el digest `b68dc41b…cd70d6d` (`STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED`). PROMOTE: pendiente (push, PR y merge, acciones humanas) |

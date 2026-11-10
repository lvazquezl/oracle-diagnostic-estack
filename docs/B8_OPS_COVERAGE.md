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
| REGRESSION | 974/974 en macOS (bash 5.3) |
| LAB | Pendiente |
| HUMAN REVIEW | Pendiente |

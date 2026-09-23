# CHG-ESTACK-ORA19C-LAB-004 — Lote 2 RMAN: frescura de backups y resumen de jobs, con la antigüedad calculada en la base

**Tipo:** `/change query|security` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `change/lab-rman-freshness` (desde `main` `cdd6f62`, `v0.16.0-oracle19c-lab-domains`)
**Origen:** REC-0009 / FND-0008 de `ANA-20260922-002`; decisión del DBA sobre `CHG-REQ-LAB-RMAN-TIMESTAMPS`: **opción C**
**Estado:** propuesto. El motor de gobernanza informa `PENDING_HUMAN_REVIEW` (validación en el lab, §6). `PROMOTE`, commit, merge, tag y push son acciones humanas.

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY. Ninguna política cambia.

## 1. DETECT GAP

`ANA-20260922-002` (revisión 3) tiene backup/recovery en `PARTIALLY_SUPPORTED` con sólo el uso de la FRA. FND-0008 (un solo backup piece en la FRA) queda como **hipótesis** porque no hay evidencia de jobs ni de frescura. Las queries RMAN existentes devuelven fechas `DATE`, sin zona horaria, que el gateway no puede exponer sin inventar una conversión.

## 2. CHANGE REQUEST — decisión y alcance

**Decisión (DBA): opción C.** Dos queries certificadas **nuevas** y agregadas, que calculan la antigüedad en la base (`SYSDATE - fecha`, mismo reloj) en lugar de exportar fechas. Descartadas: A (tipo `timestamp_db_local`, se reserva para timelines de RCA) y B (conversión a UTC con el offset actual, incorrecta si hubo cambio de horario).

| Artefacto | Tipo | Estado |
|---|---|---|
| `Q-RMAN-BACKUP-FRESHNESS-001` | query certificada nueva (corregida tras el 1.er intento en el lab, §6) | 5 filas fijas: `FULL_OR_LEVEL0`, `INCREMENTAL`, `ARCHIVELOG`, `CONTROLFILE`, `SPFILE` → `record_count`, `hours_since_last` |
| `Q-RMAN-JOB-SUMMARY-001` | query certificada nueva | 1 fila por `INPUT_TYPE` → `jobs_total`, `last_status`, `hours_since_last_start`, `hours_since_last_success`, `failed_last_7d`, `last_elapsed_seconds` |
| Gateway / lab | collectors | Ambas en el catálogo con fixture sintético (`fixture-primary-19c`) y en el adaptador lab (`mcp_gateway_lab` `0.4.0`) |

Las 14 queries `Q-RMAN-*` existentes **no cambian** (ni SQL ni hash), así que sus consumidores tampoco.

## 3. GAP ANALYSIS

1. **IDs canónicos:** `Q-RMAN-BACKUP-FRESHNESS-001` y `Q-RMAN-JOB-SUMMARY-001` son nuevos, únicos, domain-qualified y siguen la convención `Q-RMAN-*`.
2. **Diccionario (`columns_exhaustive: true`):** sólo se usan columnas registradas **y verificadas contra Oracle Database Reference 19c**: `V$BACKUP_DATAFILE` (`file#`, `incremental_level`, `completion_time`), `V$BACKUP_SET` (`backup_type`, `controlfile_included`, `completion_time`), `V$BACKUP_SPFILE` (`completion_time`) y `V$RMAN_BACKUP_JOB_DETAILS` (`input_type`, `status`, `start_time`, `end_time`, `elapsed_seconds`). **Ojo:** `tests/test_sql_static_validator.sh` sólo revisa la primera lista `SELECT` (lo declara él mismo: no es un parser SQL completo). Se hizo una verificación adicional columna por columna, `WHERE`/`GROUP BY`/`UNION ALL` incluidos, sin faltantes.
3. **Por qué `V$BACKUP_DATAFILE` y no `V$BACKUP_SET.BACKUP_TYPE`:** un autobackup de controlfile/SPFILE es un backup set tipo `D` sin nivel, y contarlo como "full" daría una frescura falsa. `V$BACKUP_DATAFILE` con `FILE# > 0` sólo cuenta datafiles (# 9 de Fase 7: nunca por heurística de TAG).
4. **Sintaxis:** sin `FETCH FIRST`/`OFFSET` ni `CON_ID`, así que una sola variante `V1` (`10.2`–`23.0`, `max` explícito) es válida en todo el rango. `KEEP (DENSE_RANK LAST …)` existe desde 9i.
5. **`container_scope: ANY_CONTAINER`**, como el resto de `Q-RMAN-*`. Desde una PDB, `V$BACKUP_*` se filtra al contenedor. El lab ejecuta desde `CDB$ROOT`. Documentado en cada query.
6. **Ausencia explícita:** una categoría sin backups devuelve `record_count = 0` y `hours_since_last = NULL`. El adapter descarta el `NULL`, pero el `0` queda, así que la ausencia no se pierde. Una base sin jobs devuelve 0 filas en `JOB-SUMMARY` (sigue abierto `CHG-REQ-LAB-EMPTY-EVIDENCE`).
7. **Tests RMAN del baseline:** los 5 `test_rman_*_variant_*.sh` ya fallaban en macOS por `grep '\|'` (`CHG-REQ-TEST-BSD-GREP`). Las 2 queries nuevas pasan en `19c` (variante única) y pasarían en `10g`/`11g` con un `grep` portable (`-V1$`); verificado con ERE. El chequeo de fondo (sin `FETCH FIRST`/`OFFSET` en 10g/11g) pasa.

## 4. IMPACT ANALYSIS

| Dimensión | Impacto |
|---|---|
| Queries existentes | Ninguno; ningún archivo existente de `queries/` cambia |
| `queries/REGISTRY.md` / `config/query-compatibility-matrix.yaml` | 2 entradas nuevas por tabla; variantes explícitas `COMPATIBLE` |
| `config/capability-matrix.yaml` / `docs/CAPABILITY_MATRIX.md` | Sin cambio de cobertura dominio×versión (RMAN ya cubría 10g–23ai); `test_capability_matrix_registry_consistency` pasa |
| Versión | 10g–23ai; el lab es 19c |
| Arquitectura | Standalone/RAC; contenedor según §3.5 |
| Licencia | `none` (vistas `V$` de RMAN, sin packs ni Recovery Catalog) |
| Costo | Frescura `LOW` (5 agregados sobre el controlfile); jobs `MEDIUM` (vista derivada, como `Q-RMAN-BACKUP-JOB-001`). Timeout efectivo 15 s (`operation_timeout`) |
| Gateway | 12 collectors, 80 componentes en readiness (50 `TESTED_WITH_SYNTHETIC_FIXTURES`) |
| Skills | `rman/backup-freshness` y `rman/backup-status` pueden consumirlas por referencia. Enlazarlas en sus manifests queda como `/change skill` aparte (`CHG-REQ-SKILL-RMAN-AGE-EVIDENCE`) |

## 5. PROPOSAL / IMPLEMENT

- `queries/rman/Q-RMAN-BACKUP-FRESHNESS-001.md`, `queries/rman/Q-RMAN-JOB-SUMMARY-001.md` (Query Contract v2 completo).
- `queries/REGISTRY.md`, `config/query-compatibility-matrix.yaml`.
- `mcp_gateway/catalog/collectors.json` (política por campo, horas `number` acotadas a `[-24, 1e6]`), `mcp_gateway/config/targets.fixture.json`, fixtures `fixture-primary-19c/Q-RMAN-{BACKUP-FRESHNESS,JOB-SUMMARY}-001.json`.
- `mcp_gateway_lab/oracle_sql.py` (`SUPPORTED_COLLECTORS` += 2), `cli.py` (`0.4.0`), `__init__.py`.
- `config/production-readiness-registry.json`, `docs/PRODUCTION_READINESS.md`, `docs/PHASE_13_MCP_DIAGNOSTIC_GATEWAY.md`, `tests/p14/check_inventory.py` (80/12).

## 6. Compatibilidad

| Check | Resultado | Base |
|---|---|---|
| `version_coverage` | PASS | V1 `10.2`–`23.0` ⊇ 19c; todas las columnas `min_version` ≤ 10.2 |
| `query_contract` | PASS | Query Contract v2 completo; `test_query_contract_requires_*`, `test_query_limits`, `test_rman_query_cost`, `test_rman_query_version_compatibility` en verde |
| `dictionary_columns` | PASS | verificación columna por columna (§3.2) + `test_sql_static_validator` |
| `architecture` | **PASS** | Validado en el lab desde `CDB$ROOT` (intento 2): las dos queries corren en Oracle real y los datos son coherentes entre sí, con la FRA (EVD-0008) y con lo que declaró el DBA |
| `cost_and_license` | PASS | LOW/MEDIUM, `none` |
| `test_coverage` | PASS | P15 adapter 21 → 23, security 30 → 32; P14 integración ejercita ambas por fixture |

### Validación en el lab — intento 1 (2026-09-23T19:06Z, `CDB$ROOT`)

| Collector | Referencia | Resultado |
|---|---|---|
| `Q-DISC-IDENTITY-001` | `REQ-437cfcea9c91` | REAL, mismo digest `6e43cf72…` |
| `Q-RMAN-JOB-SUMMARY-001` | `REQ-0193eb825e6d` / `EVR-89669856f54e06e2790647c6` | REAL, el SQL corre (`KEEP (DENSE_RANK LAST …)` OK), **0 filas**, `OK`. Pendiente: que el DBA confirme si hay historia de jobs RMAN |
| `Q-RMAN-BACKUP-FRESHNESS-001` (1.ª versión) | `REQ-3b8ff260b90c` | `E_ADAPTER_FAILED`; el `check` humano dio `DRIVER_ERROR` |

**Causa (verificada en Oracle Database Reference 19c, `V$BACKUP_REDOLOG`):** la vista **no tiene** `COMPLETION_TIME`. Sus columnas son `RECID`, `STAMP`, `SET_STAMP`, `SET_COUNT`, `THREAD#`, `SEQUENCE#`, `RESETLOGS_CHANGE#`, `RESETLOGS_TIME`, `FIRST_CHANGE#`, `FIRST_TIME`, `NEXT_CHANGE#`, `NEXT_TIME`, `BLOCKS`, `BLOCK_SIZE`, `TERMINAL` y `CON_ID`. El diccionario del repo la registra por error, y ni el diccionario, ni el validador estático, ni el driver simulado podían detectarlo.

**Corrección en este CHG:** la rama `ARCHIVELOG` usa `V$BACKUP_SET` con `BACKUP_TYPE = 'L'`; se retiran `V$BACKUP_REDOLOG` de `objects_accessed`/`privileges_required` y de los registros. Además, el adapter clasifica `ORA-00904` como `INVALID_IDENTIFIER` (sólo para el `check` humano), para que este tipo de fallo se distinga de otros errores del driver.

### Validación en el lab — intento 2 (2026-09-23T19:21Z, `CDB$ROOT`, servidor reiniciado con el SQL corregido)

| Collector | Referencia | Resultado |
|---|---|---|
| `Q-RMAN-BACKUP-FRESHNESS-001` | `REQ-63c49f29350b` / `EVR-af40d671cb4744bac8ca3338` | REAL, **5 filas**, `limitations: []`, digest `ee0e37d3…ae28`: `FULL_OR_LEVEL0` 0, `INCREMENTAL` 0, `ARCHIVELOG` 0, `CONTROLFILE` 1 (25.09 h), `SPFILE` 1 (25.09 h) |

**Coherencia:** hay un solo backup set, con controlfile y SPFILE a la vez, de hace ~25 h: el patrón de un **autobackup**. Coincide con el único backup piece de la FRA (EVD-0008). La vista de jobs vacía (`Q-RMAN-JOB-SUMMARY-001`, 0 filas) queda **confirmada por el DBA**: en este lab nunca se ha ejecutado un respaldo con RMAN. Las categorías sin backup muestran `record_count: 0` y ninguna antigüedad inventada.

**Defecto previo, fuera de alcance (`CHG-REQ-DICT-BACKUP-REDOLOG`, prioridad alta):** `compatibility/oracle-dictionary/views.yaml` declara `V$BACKUP_REDOLOG.completion_time`, y la query certificada **existente** `Q-RMAN-ARCHIVELOG-BACKUP-001` la selecciona. En Oracle real fallaría con `ORA-00904` en todas las versiones. Su corrección (diccionario + query + consumidores como `rman/archivelog-backup`) va en su propio `/change query`, no aquí.

## 7. SECURITY VALIDATION (revisión `oracle-security-analyst`)

| Control | Resultado |
|---|---|
| SQL | Sólo `SELECT` agregado; pasa `assert_read_only_sql` y `test_no_write_operations`; ninguna llamada a paquetes |
| Datos al modelo | Enums y números KEEP. **No** salen fechas absolutas, `SESSION_KEY`, `HANDLE`, `TAG`, rutas ni mensajes de RMAN (hay prueba) |
| Tipos | Un `DATE` que llegara del driver se rechaza (`RESULT_TYPE_REFUSED`), nunca se convierte (prueba). Horas fuera de rango o como texto se descartan y se reportan (`INVALID_VALUES_DROPPED`, prueba) |
| Privilegios nuevos (DBA) | `SELECT` sobre 5 vistas `V_$` de RMAN (§9). No hace falta `CONTAINER_DATA` nuevo: los backups son de nivel CDB |
| Superficie | Sin tools, argumentos ni SQL de cliente nuevos |

Veredicto: **PASS**.

## 8. REGRESSION VALIDATION

949/962 antes y después: los mismos 13 fallos preexistentes. P13 8/8, P14 10/10, P15 2/2 scripts (23 + 32 casos). Tests de queries: `test_every_logical_query_has_variant`, `test_documented_support_matches_query_variants`, `test_capability_matrix_registry_consistency`, `test_sql_static_validator` y `test_query_variant_ranges_do_not_overlap_invalidly` en verde.

## 9. Pasos humanos para validar en el lab (no los ejecuta el e-stack)

```text
-- DBA, como administrador, conectado a CDB$ROOT, SÓLO en el laboratorio
GRANT SELECT ON SYS.V_$BACKUP_DATAFILE          TO C##ESTACK_DIAG CONTAINER=CURRENT;
GRANT SELECT ON SYS.V_$BACKUP_SET               TO C##ESTACK_DIAG CONTAINER=CURRENT;
GRANT SELECT ON SYS.V_$BACKUP_SPFILE            TO C##ESTACK_DIAG CONTAINER=CURRENT;
GRANT SELECT ON SYS.V_$RMAN_BACKUP_JOB_DETAILS  TO C##ESTACK_DIAG CONTAINER=CURRENT;
```

`targets.lab.json`: agregar `Q-RMAN-BACKUP-FRESHNESS-001` y `Q-RMAN-JOB-SUMMARY-001` a `allowed_collectors`. `validate-config` y reconectar `oracle-estack-lab` en `/mcp`.

Criterio de cierre de `architecture`: con evidencia REAL desde `CDB$ROOT`, `Q-RMAN-BACKUP-FRESHNESS-001` devuelve sus **5 filas**, y los conteos son coherentes con EVD-0008 (FRA: 1 backup piece, 4 archived logs). `Q-RMAN-JOB-SUMMARY-001` corre sin error; 0 filas es válido **sólo** si el DBA confirma que no hay historia de jobs RMAN.

## 10. Registros diferidos (propuestos, sin implementar)

- `CHG-REQ-DICT-BACKUP-REDOLOG` (alta): diccionario y `Q-RMAN-ARCHIVELOG-BACKUP-001` usan una columna que no existe (§6).
- `CHG-REQ-SKILL-RMAN-AGE-EVIDENCE`: declarar las 2 queries en `rman/backup-freshness` / `rman/backup-status` (`/change skill`).
- `CHG-REQ-LAB-RMAN-TIMESTAMPS` (resto): fechas absolutas para timelines de RCA (opción A/D), sólo si hacen falta.
- `CHG-REQ-TEST-BSD-GREP`, `CHG-REQ-LAB-EMPTY-EVIDENCE`: siguen abiertos.

## 11. HUMAN REVIEW (pendiente)

Revisor distinto del proponente (`E_AUTH_SELF_APPROVAL`). La aprobación se registra contra el `content_digest` que informa el motor (§12).

## 12. Motor de gobernanza

`advise --mode estack` (2026-09-23T19:22:14Z): `governance_state: PENDING_HUMAN_REVIEW`, `blockers: []`, `promote_status: HUMAN_ACTION_REQUIRED`, `content_digest: f9e9e27c3798ce17b4bae96735644de7c61f22acbc933986d6bab7455d1fddaf`. La salida queda fuera del repo, en `~/.local/share/oracle-diagnostic-estack/change-evidence/CHG-ESTACK-ORA19C-LAB-004/`.

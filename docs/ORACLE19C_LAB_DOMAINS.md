# CHG-ESTACK-ORA19C-LAB-003 — Lote 1 de dominios en el lab: tablespaces por PDB y uso de FRA

**Tipo:** `/change security|compatibility` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `change/lab-domains-batch1` (desde `main` `053e461`, `v0.15.0-oracle19c-lab` + PR #5)
**Origen:** `CHG-REQ-LAB-DOMAINS` / REC-0002 de `ANA-20260922-002`
**Estado:** `APPROVED_BY_HUMAN` (`AUTH-ORA19C-LAB-003`, `REV-DBAMANAGER`, `2026-09-23T18:00:27Z`; verificación estructural, no de identidad) e integrado a `main` vía PR #6 (`b885e90`), versión `0.16.0`, tag `v0.16.0-oracle19c-lab-domains`.

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY. Ninguna política cambia.

## 1. DETECT GAP

En `ANA-20260922-002` (revisión 2), tablespaces/TEMP, capacidad y backup/recovery siguen en `INSUFFICIENT_EVIDENCE`. El target lab ya está en `CDB$ROOT` con el usuario común `C##ESTACK_DIAG` (`v0.15.0`).

## 2. CHANGE REQUEST — alcance

| Collector | Decisión | Motivo |
|---|---|---|
| `Q-CDB-TABLESPACES-001` | **Implementado** | Uso de tablespaces de cada PDB desde root (`CDB_*`) |
| `Q-CDB-TEMP-001` | **Catálogo y fixture sí; lab no** (decisión del DBA, §6) | Desde root devolvió asignación sin uso. Queda diferido a `CHG-REQ-QUERY-CDB-TEMP-USAGE` |
| `Q-RMAN-FRA-USAGE-001` | **Implementado** | Presión de FRA por tipo de archivo, a nivel instancia |
| `Q-RMAN-BACKUP-JOB-001`, `Q-RMAN-STATUS-001` y demás `Q-RMAN-*` con fechas | **Diferido → lote 2** (`CHG-REQ-LAB-RMAN-TIMESTAMPS`) | Devuelven `DATE` sin zona horaria. El adaptador rechaza tipos no escalares y el sanitizer sólo acepta `timestamp_utc` con zona. Convertir sin conocer la zona del servidor sería inventar datos, así que hay que decidir primero el tipo de campo (p. ej. `timestamp_db_local` explícito) o una variante que calcule la antigüedad en la base |
| `Q-DBA-TBS-*`, `Q-ORA-TEMP-001`, `Q-ORA-UNDO-001` | No aplican | Son vistas `DBA_*`: desde root sólo muestran root; las `CDB_*` cubren todas las PDBs |

## 3. GAP ANALYSIS

1. **Catálogo:** ninguno de los 3 estaba en `mcp_gateway/catalog/collectors.json`. Se agregan con política por campo (default deny).
2. **Contenedor:** el gateway no evaluaba `container_scope`. `CDB_ROOT_ONLY` en un target PDB/NON_CDB daría el mismo "vacío = OK" de FND-0006. Ahora devuelve `NOT_APPLICABLE` antes de conectar, o `ENVIRONMENT_UNKNOWN` si el contenedor es desconocido.
3. **Límites del perfil lab:** los techos venían de la query de identidad (5 filas, 4096 bytes, 10 s). Una CDB con varias PDBs supera 5 filas. Se suben los techos (§5); cada llamada sigue usando min(perfil, query, collector).
4. **Defecto encontrado (desde LAB-001):** el adapter trae `max_rows + 1` filas para detectar truncamiento, pero el gateway devolvía todas, **sin** limitación. Corregido: el adapter declara `row_cap`, el gateway recorta y marca `ROWS_TRUNCATED_TO_LIMIT`.
5. **SQL certificado de `Q-CDB-TABLESPACES-001`:** el `LEFT JOIN cdb_data_files ... AND ROWNUM = 1` hace que `autoextend` sea poco fiable. **No se expone.** La corrección va por `/change query` (`CHG-REQ-QUERY-CDB-TBS-AUTOEXTEND`). `used_space`/`tablespace_size` están en **bloques**, y `used_percent` es relativo al tamaño máximo (con autoextend).
6. **Datos sensibles:** los nombres de tablespace van **MASK** (`ts-A*`), como exige `sanitizers/data-classification-policy.md` salvo autorización explícita del DBA. `con_id` es KEEP: el DBA sabe qué `con_id` es `PRUEBAS`. La ruta de la FRA (`dest_name`) y `autoextend` no se declaran, así que el adapter los descarta en origen.
7. **Tests RMAN que fallan en el baseline:** no es un problema del catálogo. `tests/test_rman_*_variant_*.sh` usan `grep -q '…\|…'`, que BSD grep (macOS) no soporta; la variante resuelta (`-V2`, `modern_12plus`) es la correcta. Se registra como `CHG-REQ-TEST-BSD-GREP`, fuera de alcance.
8. **IDs canónicos:** no se crean IDs nuevos; los 3 existen, son únicos y están domain-qualified.

## 4. IMPACT ANALYSIS

| Dimensión | Impacto |
|---|---|
| Runtime por defecto | Nuevo target fixture `fixture-cdb-root-19c` (SYNTHETIC) con los 3 collectors + identidad. Los targets y collectors existentes responden igual |
| Capability | Nueva regla `CDB_ROOT_ONLY` → `NOT_APPLICABLE`/`ENVIRONMENT_UNKNOWN`. Hoy sólo la usan estos 2 collectors |
| Gateway | Recorte por `row_cap` del adapter (duck typing); el fixture no lo declara, así que no cambia |
| Registro de readiness | 3 collectors `TESTED_WITH_SYNTHETIC_FIXTURES` (78 componentes; 48/29/1). `docs/PRODUCTION_READINESS.md` actualizado |
| `config/capability-matrix.yaml` | Sin cambio de cobertura dominio×versión: las queries ya estaban certificadas; esto sólo las expone en el gateway |
| Versión | 19c en el lab. Las queries: CDB 12c–23ai, FRA 10g–23ai |
| Licencia | `none` en los 3 |
| Costo | `LOW` en los 3; timeouts 20/15/15 s (acotados por `operation_timeout` 15 s y `call_timeout_ms` del perfil) |
| Consumidores | `oracle-dba-analyst`, `oracle-multitenant-analyst`, `oracle-backup-recovery-analyst`, `capacity-analyst` (por referencia) |
| Versiones | `mcp_gateway_lab` `0.2.0` → `0.3.0` |

## 5. PROPOSAL / IMPLEMENT

- `mcp_gateway/catalog/collectors.json`: 3 collectors (política por campo, límites 200/100/20 filas).
- `mcp_gateway/catalog.py`: regla `CDB_ROOT_ONLY` en `evaluate_capability`.
- `mcp_gateway/gateway.py`: `cap_rows = min(..., adapter.row_cap(target, collector))` si el adapter lo declara.
- `mcp_gateway_lab/oracle_sql.py`: `SUPPORTED_COLLECTORS` += tablespaces y FRA (TEMP no, §6); `row_cap`.
- `mcp_gateway_lab/profile.py`: techos `max_rows` 5 → **200**, `max_output_bytes` 4096 → **65536**, `call_timeout_ms` 10000 → **20000**.
- Fixtures SYNTHETIC `mcp_gateway/fixtures/fixture-cdb-root-19c/` y target en `targets.fixture.json`.
- Registro `config/production-readiness-registry.json`, `docs/PHASE_13_MCP_DIAGNOSTIC_GATEWAY.md` (§5.1 y orden de autorización), `docs/PRODUCTION_READINESS.md`.

## 6. Compatibilidad

| Check | Resultado | Base |
|---|---|---|
| `version_coverage` | PASS | 19c ∈ 12c–23ai / 10g–23ai; FRA por variante explícita V1 (`10.2`–`23.0`), CDB por variante implícita `COMPATIBLE` |
| `query_contract` | PASS | queries sin cambios, Query Contract v2 completo |
| `dictionary_columns` | PASS | `CDB_TABLESPACE_USAGE_METRICS`, `CDB_TABLESPACES`, `CDB_DATA_FILES`, `CDB_TEMP_FILES`, `GV$TEMP_SPACE_HEADER`, `V$FLASH_RECOVERY_AREA_USAGE`, `V$RECOVERY_FILE_DEST` en `compatibility/oracle-dictionary/views.yaml` |
| `architecture` | **PASS** (tablespaces, FRA) | Validado en el lab desde `CDB$ROOT` (ver abajo). `Q-CDB-TEMP-001` dio resultado parcial y no se habilita en el lab |
| `cost_and_license` | PASS | LOW / none |
| `test_coverage` | PASS | P15 adapter 18 → 21, security 27 → 30; P14 integración ejercita los 3 por fixture; 4 mutaciones detectadas |

### Validación en el lab (2026-09-23T17:18Z, `CDB$ROOT`, `C##ESTACK_DIAG`, `CONTAINER_DATA = (CDB$ROOT, PRUEBAS)`)

Un primer intento a las ~17:00Z falló completo con `E_ADAPTER_FAILED`. El `check` humano dio `NETWORK_UNREACHABLE`: el host no era alcanzable, no fue un problema del código. Cuando volvió la red:

| Collector | Referencia | Resultado |
|---|---|---|
| `Q-DISC-IDENTITY-001` | `REQ-5d614b188333` / `EVR-f61b125f359f5e4e28b3207b` | REAL, mismo digest `6e43cf72…` |
| `Q-CDB-TABLESPACES-001` | `REQ-3265abdb2ad7` / `EVR-037f271256101ebfe9d5df85` | REAL, **5 filas, `con_id` 3** (= `PRUEBAS`, confirmado por el DBA): 3 PERMANENT, 1 TEMPORARY, 1 UNDO; `used_percent` máx. 1.07 %. El `ROWNUM` del `JOIN` no rompe la query |
| `Q-CDB-TEMP-001` | `REQ-e33c5e987c1e` / `EVR-180ca1d7253e42ce53832c49` | REAL, 1 fila `con_id` 3 con **sólo** `allocated_bytes` (51 MiB). `bytes_used`/`bytes_free` llegaron `NULL`: el `LEFT JOIN` con `GV$TEMP_SPACE_HEADER` no encontró fila desde root (hipótesis: `file_id` relativo vs. absoluto). El adapter descartó los `NULL` sin limitación → evidencia parcial presentada como completa |
| `Q-RMAN-FRA-USAGE-001` | `REQ-db6c352a7111` / `EVR-c2e2de5c6d0acb99dcc1268e` | REAL, **8 filas**: límite 10 GiB, usado ≈ 1.1 GiB (≈ 11 %), 0 reclamable; 1 backup piece y 4 archived logs |

**Decisión del DBA (opción A):** `Q-CDB-TEMP-001` sale del adaptador lab (el lanzador rechaza un targets file que lo pida; hay prueba), y se quitó del `targets.lab.json` privado. Se queda en el catálogo con su fixture sintético. Con eso, ningún check queda en `UNKNOWN`.

## 7. SECURITY VALIDATION (revisión `oracle-security-analyst`)

| Control | Resultado |
|---|---|
| Superficie de tools | Sin cambios |
| SQL | Sólo bloques certificados con hash fijado; sin SQL nuevo |
| Datos al modelo | Números y enums KEEP; nombres de tablespace MASK; ruta de FRA y `autoextend` descartados en origen. Hay pruebas de que ni `APP_DATA…` ni `fast_recovery_area` llegan a la salida |
| Contenedor | `CDB_ROOT_ONLY` se rechaza fuera de root **antes de conectar** (prueba + mutación) |
| Límites | Techos más altos pero acotados (201 / 65537 / 20001 se rechazan); límite de bytes probado con resultado multi-fila; el recorte por `row_cap` evita devolver la fila de detección (prueba + mutación) |
| Privilegios nuevos (DBA) | `SELECT` sobre 5 vistas + `CONTAINER_DATA` limitado a `CDB$ROOT` y `PRUEBAS` (§9). Riesgo residual LOW: `CDB_DATA_FILES` deja a la cuenta ver las rutas de los datafiles, aunque la query sólo lee `autoextensible` y no se expone |

Veredicto: **PASS**. Los grants de `CDB_TEMP_FILES` y `GV_$TEMP_SPACE_HEADER` ya no se usan; el DBA puede revocarlos (`REVOKE SELECT ON SYS.CDB_TEMP_FILES FROM C##ESTACK_DIAG CONTAINER=CURRENT;` y lo mismo para `GV_$TEMP_SPACE_HEADER`).

## 8. REGRESSION VALIDATION

949/962 antes y después: los mismos 13 fallos preexistentes (`*_no_delegation_loop` ×5, `test_collectors_are_allowlisted`, `Q-PDB-*` columnas ×2, `test_rman_*_variant_*` ×5 por portabilidad de `grep`). P13 8/8, P14 10/10, P15 2/2. Tests existentes ajustados por el cambio de contrato: conteos del inventario (75 → 78, 7 → 10), la prueba de integración colecta los collectors `CDB_ROOT_ONLY` en `fixture-cdb-root-19c`, y un caso de límites (`max_rows` 50 ahora es válido; se prueba 201).

## 9. Pasos humanos para validar en el lab (no los ejecuta el e-stack)

```text
-- DBA, como administrador, conectado a CDB$ROOT, SÓLO en el laboratorio
GRANT SELECT ON SYS.CDB_TABLESPACE_USAGE_METRICS TO C##ESTACK_DIAG CONTAINER=CURRENT;
GRANT SELECT ON SYS.CDB_TABLESPACES              TO C##ESTACK_DIAG CONTAINER=CURRENT;
GRANT SELECT ON SYS.CDB_DATA_FILES               TO C##ESTACK_DIAG CONTAINER=CURRENT;
GRANT SELECT ON SYS.V_$FLASH_RECOVERY_AREA_USAGE TO C##ESTACK_DIAG CONTAINER=CURRENT;
GRANT SELECT ON SYS.V_$RECOVERY_FILE_DEST        TO C##ESTACK_DIAG CONTAINER=CURRENT;
-- Visibilidad de datos por contenedor, sólo root y la PDB evaluada (no ALL):
ALTER USER C##ESTACK_DIAG SET CONTAINER_DATA = (CDB$ROOT, PRUEBAS) CONTAINER=CURRENT;
```

Configuración privada (la edita el DBA):

1. `targets.lab.json`: agregar `Q-CDB-TABLESPACES-001` y `Q-RMAN-FRA-USAGE-001` a `allowed_collectors` (`Q-CDB-TEMP-001` no, ver §6); subir `budget.max_rows` (p. ej. 500).
2. `lab-profile.json`: `limits.max_rows` (p. ej. 100), `limits.max_output_bytes` (p. ej. 32768), `limits.call_timeout_ms` (p. ej. 15000). La autorización vigente (`CHG-ESTACK-ORA19C-LAB-002`) cubre el mismo target y cuenta; si el revisor quiere que nombre este CHG, la renueva él.
3. `validate-config` y reconectar `oracle-estack-lab` en `/mcp`.

Criterio de cierre de `architecture` (cumplido, §6): con evidencia REAL, `Q-CDB-TABLESPACES-001` devuelve **filas con el `con_id` de `PRUEBAS`** y `Q-RMAN-FRA-USAGE-001` devuelve filas. 0 filas **no** habría cerrado el check (FND-0006).

## 10. Registros diferidos (propuestos, sin implementar)

- `CHG-REQ-LAB-RMAN-TIMESTAMPS`: lote 2 (jobs y estado RMAN) con decisión sobre `DATE` sin zona horaria.
- `CHG-REQ-QUERY-CDB-TEMP-USAGE`: corregir el `JOIN` de `Q-CDB-TEMP-001` con `GV$TEMP_SPACE_HEADER` para que dé uso desde root (`/change query` + validación en el lab).
- `CHG-REQ-LAB-EMPTY-EVIDENCE` se amplía: además de 0 filas, las columnas declaradas que llegan `NULL` deberían contarse como limitación.
- `CHG-REQ-QUERY-CDB-TBS-AUTOEXTEND`: corregir el `ROWNUM = 1` en el `JOIN` de `Q-CDB-TABLESPACES-001` (`/change query`).
- `CHG-REQ-TEST-BSD-GREP`: portabilidad de `tests/test_rman_*_variant_*.sh` en macOS.
- `CHG-REQ-LAB-EMPTY-EVIDENCE`: sigue abierto (FND-0006).

## 11. HUMAN REVIEW (aprobado)

Revisor distinto del proponente (`E_AUTH_SELF_APPROVAL`). La aprobación se registra contra el `content_digest` que informa el motor (§12).

## 12. Motor de gobernanza

`advise --mode estack` (2026-09-23T17:25:47Z): `governance_state: PENDING_HUMAN_REVIEW`, `blockers: []`, `promote_status: HUMAN_ACTION_REQUIRED`, `content_digest: 6506894a2bfb30931a8e57dafd264a8e1ab2e1627c5795251a7d2142d61d795c`. La salida queda fuera del repo, en `~/.local/share/oracle-diagnostic-estack/change-evidence/CHG-ESTACK-ORA19C-LAB-003/`.

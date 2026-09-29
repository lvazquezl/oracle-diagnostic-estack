# CHG-ESTACK-CDB-TEMP-USAGE-001 — Uso de TEMP por PDB sin `JOIN` por número de archivo

**Tipo:** `/change query|skill` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `change/cdb-temp-usage` (desde `change/lab-revalidate-007`, `bd39a30`)
**Origen:** `CHG-REQ-QUERY-CDB-TEMP-USAGE` (`CHG-ESTACK-ORA19C-LAB-003`)
**Estado:** aprobado (§11), validado en el lab (§8), integrado a `main` vía PR #25 (merge `00000b4`; la PR #24 quedó cerrada como integrada). Release `0.22.0`, tag `v0.22.0-observed-context` (se crea sobre el merge de la rama del changelog).

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY.

## 1. DETECT GAP

En el lab 19c, desde `CDB$ROOT`, `Q-CDB-TEMP-001` 1.0.0 devolvió `allocated_bytes` pero `bytes_used`/`bytes_free` `NULL` (`REQ-e33c5e987c1e`). Su `LEFT JOIN` entre `CDB_TEMP_FILES` y `GV$TEMP_SPACE_HEADER` por `FILE_ID` no encontró coincidencias. Por eso la query quedó fuera del adaptador lab, y un test de seguridad lo exigía.

## 2. CHANGE REQUEST — alcance

| Artefacto | Cambio |
|---|---|
| `queries/multitenant/Q-CDB-TEMP-001.md` 2.0.0 (breaking) | Uso desde `GV$SORT_SEGMENT` (`USED_BLOCKS × BLOCK_SIZE` de `CDB_TABLESPACES`), asignado desde `CDB_TEMP_FILES`, ambos agregados por `(CON_ID, TABLESPACE_NAME)`; libre = asignado − usado. Una fila por tablespace TEMP de cada PDB |
| `compatibility/oracle-dictionary/views.yaml` | + `V$SORT_SEGMENT`, `GV$SORT_SEGMENT` con columnas (verificadas por `Q-DICT-VERIFY`, regeneradas: 500 tokens); notas de `V$`/`GV$TEMP_SPACE_HEADER` (sólo root desde root) |
| `skills/multitenant/pdb-temp` 1.1.0 | Presión por PDB y tablespace; con uso nulo, `UNKNOWN` (nunca `LOW`) |
| `mcp_gateway_lab` 0.8.0 | Collector habilitado; el test que exigía rechazarlo se retira |
| Registros | Matriz, `queries/REGISTRY.md`, readiness (privilegios copiados de la query), diccionario (notas), `docs/PHASE_13_*` |
| Tests | P15 +1: la sentencia certificada se ejecuta textual, sin `gv$` ni `file_id` |

## 3. GAP ANALYSIS

- **La causa real** la confirmó el DBA a mano, desde `CDB$ROOT` (§8): `V$TEMP_SPACE_HEADER` sólo expone `CON_ID` 1; `V$SORT_SEGMENT` expone 1 y 3; `V$TEMPSEG_USAGE` sin filas (uso instantáneo, nadie usando TEMP).
- **Semántica:** `SORT_SEGMENT.USED_BLOCKS` es el uso del segmento de ordenamiento (extents en uso); sin uso de TEMP desde el arranque no hay segmento y el uso queda `NULL` → `UNKNOWN` en la skill. `V$TEMPSEG_USAGE` (uso instantáneo por sesión) se descarta como medida principal.
- **RAC:** cada instancia tiene su propio segmento de ordenamiento; `GV$` sumado es el total (a diferencia de los encabezados de tempfiles, que son compartidos).
- La salida pasa de "por tempfile" a "por tablespace": breaking para quien contara archivos.

## 4. IMPACT ANALYSIS

| Dimensión | Impacto |
|---|---|
| Query | 2.0.0; `CDB_ROOT_ONLY`, `R0`, `LOW` sin cambios |
| Skill | `multitenant/pdb-temp` 1.1.0 |
| Lab | 0.7.0 → 0.8.0; hay que agregar el collector al targets file privado |
| Privilegios | `SELECT_CATALOG_ROLE` + `CONTAINER_DATA` que ya tiene el usuario del lab |

## 5. TEST

P15 28/28 y 35/35. Mutación: con la query 1.0.0 el caso nuevo falla (exige `gv$sort_segment`, sin `temp_space_header` ni `file_id`).

## 6. SECURITY VALIDATION

Sólo métricas agregadas y el nombre de tablespace enmascarado. Veredicto: **PASS**.

## 7. REGRESSION VALIDATION

macOS (bash 5.3.20): **968/968**.

## 8. Validación en el lab

**Intento 1** (2026-09-29T04:10Z, commit `dbe2bd0`, `REQ-8886ec34e7ae`, `EVR-6bdea9e3d10648bb672da33c`): `OK`/`REAL`, 1 fila de `con_id` 3 con `allocated_bytes` 53477376 y `bytes_used`/`bytes_free` **nulos**, igual que en la 1.0.0. La causa no era el `JOIN` por `FILE_ID`: todo indica que `V$TEMP_SPACE_HEADER`, consultada desde `CDB$ROOT`, no devuelve filas de las PDB. **No se registra validación en campo.** Antes de elegir el reemplazo (`V$SORT_SEGMENT`, que es asignación, o `V$TEMPSEG_USAGE`, que es uso actual por sesiones), el DBA confirma a mano qué `con_id` expone cada vista desde root.


**Confirmación manual del DBA** (SYSDBA, `CDB$ROOT`, 2026-09-29): `V$TEMP_SPACE_HEADER` → sólo `CON_ID` 1; `V$SORT_SEGMENT` → `CON_ID` 1 y 3; `V$TEMPSEG_USAGE` → sin filas.

**Intento 2** (2026-09-29T04:27Z, commit `cacfb2d`): `Q-CDB-TEMP-001` (`REQ-6796e3dd3e3e`, `EVR-912a01cdccf3ab5fb4b1aeb8`, `query_sha256` `3cb77927…96e9`) `OK`/`REAL`, sin limitaciones. 1 fila de `con_id` 3: `allocated_bytes` 53477376, `bytes_used` 0, `bytes_free` 53477376, **todos no nulos**. Es el primer uso real de TEMP de una PDB obtenido desde root.

Las 5 `Q-DICT-VERIFY` regeneradas (500 tokens) sólo reportan Statspack:

| Parte | `REQ` | `EVR` | `query_sha256` |
|---|---|---|---|
| 001 | `REQ-d882ec78ead7` | `EVR-9f725abe8e626420c1efb83c` | `679b643f…b824` |
| 002 | `REQ-61906b0d9a92` | `EVR-ab3c278f504a471f0bc64ab5` | `df66d9bd…a620` |
| 003 | `REQ-1cad56bf1cc7` | `EVR-e35657f9bf93676ba9142c36` | `6cb8c2b8…4adf` |
| 004 | `REQ-f61a3a082d57` | `EVR-3301561a0b533d0c47a58013` | `f52584cd…2297` |
| 005 | `REQ-85040b199206` | `EVR-e919aa93c04c08214d386fe4` | `5fafa79d…8802` |

Registro de validación en campo: + `Q-CDB-TEMP-001`; `Q-DICT-VERIFY-001` … `-005` actualizadas.

## 9–10. Registros relacionados

Cierra `CHG-REQ-QUERY-CDB-TEMP-USAGE`.

## 11. HUMAN REVIEW — aprobado

`AUTH-CDB-TEMP-USAGE-001`, revisor `REV-DBAMANAGER` (distinto del proponente `REV-CLAUDEAGENT`), `2026-09-29T04:36:11Z`, contra el digest `dfc5dd3d…380f6dc6`. El motor informa `review_status: APPROVED_BY_HUMAN` con verificación `STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED`: comprueba la estructura y el digest, no la identidad del firmante. `PROMOTE` (merge, tag) sigue siendo acción humana.

## 12. Motor de gobernanza

Regresión final (macOS, bash 5.3.20): **968/968**. `advise --mode estack` (2026-09-29T04:31:17Z): `governance_state: PENDING_HUMAN_REVIEW`, `blockers: []`, `promote_status: HUMAN_ACTION_REQUIRED`, `content_digest: dfc5dd3dda9fe218abd336140ae1a3412f3c11cc25e3c654005d7efb380f6dc6`. La salida queda fuera del repo, en `~/.local/share/oracle-diagnostic-estack/change-evidence/CHG-ESTACK-CDB-TEMP-USAGE-001/`.

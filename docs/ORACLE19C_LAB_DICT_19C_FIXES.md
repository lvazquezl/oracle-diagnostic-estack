# CHG-ESTACK-ORA19C-LAB-007 — Correcciones del diccionario y de 5 queries certificadas (19c)

**Tipo:** `/change query|compatibility|skill` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `change/dict-19c-fixes` (desde `change/dict-backup-redolog-v2`, `073efc8`, `CHG-ESTACK-ORA19C-LAB-005`, PR #15)
**Origen:** `CHG-REQ-DICT-19C-FIXES` (hallazgos de `CHG-ESTACK-ORA19C-LAB-006` §8)
**Estado:** aprobado por revisión humana (§11), validado en el lab (§8). Pendiente: `PROMOTE` (acción humana). `PROMOTE`, commit, merge, tag y push son acciones humanas.

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY.

## 1. DETECT GAP

`CHG-ESTACK-ORA19C-LAB-006` encontró en el catálogo real de 19c 12 discrepancias además de la ya corregida por LAB-005. Seis afectan a queries certificadas que fallarían en Oracle real (`ORA-00904`/`ORA-00942`). Además, al buscar los nombres correctos, la documentación contradijo al lab en un caso (`V$GES_STATISTICS`), lo que expuso un límite del propio verificador.

## 2. CHANGE REQUEST — alcance

| # | Artefacto | Cambio | Fuente |
|---|---|---|---|
| 0 | Verificador (`scripts/dict_verify/generate.py`, `Q-DICT-VERIFY-*`) | Resuelve cada nombre por su sinónimo público (`DBA_SYNONYMS`, destino acotado a `SYS`/`AUDSYS`/`PERFSTAT`) en vez de suponer `V$X → V_$X`. + `DBA_SYNONYMS` en el diccionario | Contradicción documentación/lab en `V$GES_STATISTICS` |
| 1 | `Q-RMAN-BACKUP-DEVICE-001` 2.0.0 | Sin `physical_device_name` | Reference 19c: `DEVICE_TYPE`, `DEVICE_NAME`, `CON_ID` |
| 2 | `Q-SEC-PROXY-AUTHENTICATION-001` 2.0.0 + `security/proxy-authentication` 1.1.0 | Sin `authorization_constraint`. Variantes: V1 10.2–11.1 sin `FLAGS`; V2 11.2–23.0 con `FLAGS`, que es donde vive `PROXY MAY ACTIVATE ALL CLIENT ROLES` | Reference 11.2 y 19c: `PROXY`, `CLIENT`, `AUTHENTICATION`, `FLAGS`; 10.2 sin verificar |
| 3 | `Q-SEC-DATA-REDACTION-POLICIES-001` 2.0.0 | Segundo bloque sin `policy_name` (el nombre sale de `REDACTION_POLICIES`) | Reference 19c |
| 4 | `Q-ASM-TOPOLOGY-001` 2.0.0 | `GV$ASM_INSTANCE` → `V$ASM_CLIENT`, unida a `V$ASM_DISKGROUP_STAT` por `group_number` | ASM Administrator's Guide 19c (no existe `V$ASM_INSTANCE`); Reference 19c `V$ASM_CLIENT` |
| 5 | `Q-RAC-GES-GCS-001` 2.0.0 | `GV$GCS_STATISTICS` → `GV$SYSSTAT` (`gc cr blocks received`, `gc current blocks received`) | Reference 19c sin página `V$GCS_STATISTICS` |
| 6 | Diccionario | Retira las columnas/vistas inexistentes; `V$STANDBY_LOG.groups` → `group#`; + `V$ASM_CLIENT`, `GV$SYSSTAT` | Ídem |
| 7 | `tests/test_no_known_nonexistent_views.sh` (nuevo) | Vistas confirmadas como inexistentes no pueden volver a una query ni al diccionario | El validador estático es permisivo con vistas no registradas |
| 8 | Referencias | Skills `asm/topology`, `asm/instances`, `rac/global-cache`, `workflows/rac.md`, `docs/ORACLE_READONLY_PRIVILEGES.md`, fixtures RAC/ASM, `queries/REGISTRY.md` (sin rangos de tokens, que cambian al regenerar), matrices y registro de readiness | — |

Fuera de alcance: `V$DATAGUARD_STATS.APPLY_LAG`/`TRANSPORT_LAG` y `V$PGASTAT.PGA_AGGREGATE_LIMIT_ROW` (valores de `NAME`, no columnas) quedan para `CHG-REQ-DICT-PSEUDO-COLUMNS`. `STATS$*` son esperados: Statspack no está instalado en el lab.

## 3. GAP ANALYSIS

1. **`V$GES_STATISTICS`:** la Reference 19c la documenta, pero el lab la había reportado `VIEW_NOT_FOUND`. Con el verificador corregido (#0), **existe** (§8): era un falso positivo del supuesto `V$X → V_$X`. La query la conserva.
2. **Nombres de estadística** (`gc ...`, `global lock ...`): son valores, no columnas. La verificación de diccionario no los cubre, y sin un RAC real quedan validados sólo por documentación.
3. **Semántica de `Q-ASM-TOPOLOGY-001`:** antes pretendía listar las instancias ASM del clúster (con una vista que no existe). Ahora muestra la instancia ASM que atiende **a esta base** y sus disk groups. Un inventario de clúster requiere consultar la instancia ASM o GI (`CHG-REQ-ASM-CLUSTER-INVENTORY`).
4. **`FLAGS` en 10.2:** no se encontró la documentación 10.2 de `PROXY_USERS` con `FLAGS`, así que no se afirma. V1 no la usa y la skill reporta `INSUFFICIENT_EVIDENCE` para la amplitud de roles.

## 4. IMPACT ANALYSIS

| Dimensión | Impacto |
|---|---|
| Queries | 5 a 2.0.0 (breaking: cambia la salida); ninguna expuesta en el gateway ni en el lab |
| Skills | `security/proxy-authentication` 1.1.0 (`flags` en lugar de `authorization_constraint`); las demás sólo cambian referencias de vista |
| Verificador | `Q-DICT-VERIFY-*` leen además `DBA_SYNONYMS` (cubierto por `SELECT_CATALOG_ROLE`); ~3600 caracteres por parte, bajo el techo de 4000 |
| Privilegios (guía de grants) | `GV_$SYSSTAT` y `V_$ASM_CLIENT` en lugar de las vistas inexistentes |
| Licencia / costo | Sin cambios |

## 5. TEST

- Regresión local (macOS, bash 5.3.20): **965/965** antes del guard nuevo; ver §7.
- Mutaciones sobre el validador estático: volver a `physical_device_name`, `authorization_constraint` (V2), `FLAGS` en V1 y `policy_name` → **detectadas**. Volver a `GV$ASM_INSTANCE`/`GV$GCS_STATISTICS` → **no detectadas** por el validador (permisivo con vistas no registradas): de ahí el guard #7, que sí las detecta y no se confunde con comentarios.

## 6. SECURITY VALIDATION

- Todo sigue siendo `SELECT` certificado.
- `DBA_SYNONYMS` sólo resuelve el destino dentro de owners fijos, así que un sinónimo público nunca lleva a otro esquema.
- La salida del verificador sigue acotada por enums.
- Veredicto: **PASS**.

## 7. REGRESSION VALIDATION

Local (macOS, bash 5.3.20): **966/966** (965 + `test_no_known_nonexistent_views`).

## 8. Validación en el lab

2026-09-27, `lab-ol8-19c` (19c RU 19.32, `CDB$ROOT`, ASM), commit `33bf6f6`. Las 5 partes corrieron `OK`/`REAL`, sin limitaciones: **487 tokens** (99 + 99 + 96 + 100 + 93).

| Parte | Evidencia | Hallazgos |
|---|---|---|
| 001 | `EVR-22d535739068e8bffc305035` | 0 |
| 002 | `EVR-99e71e14641b49c0146cf06b` | `STATS$SNAPSHOT`, `STATS$SYSTEM_EVENT` (esperados: sin Statspack) |
| 003 | `EVR-e6c23b8a714cde735dff5670` | 0 |
| 004 | `EVR-068b6708deaae2b38395970c` | `V$DATAGUARD_STATS.APPLY_LAG`/`.TRANSPORT_LAG`, `V$PGASTAT.PGA_AGGREGATE_LIMIT_ROW` (pseudo-columnas, fuera de alcance) |
| 005 | `EVR-0756625213b58b0139340101` | 0 |

- **Criterio cumplido:** sólo quedan los 5 hallazgos esperados.
- **Confirmados en Oracle real:** `GV$GES_STATISTICS` (falso positivo del verificador anterior), `V$ASM_CLIENT` y sus columnas, `GV$SYSSTAT`, `DBA_SYNONYMS`, `PROXY_USERS.FLAGS`, `V$STANDBY_LOG.GROUP#`.
- **No verificable aquí:** los nombres de estadística (`gc ...`, `global lock ...`, valores de `NAME`) y el comportamiento en RAC.

## 9–10. Registros relacionados

- Cierra `CHG-REQ-DICT-19C-FIXES`.
- Abre `CHG-REQ-ASM-CLUSTER-INVENTORY`.
- Pendientes: `CHG-REQ-DICT-PSEUDO-COLUMNS` y `CHG-REQ-LAB-MULTIVERSION`.

## 11. HUMAN REVIEW — aprobado

`AUTH-ORA19C-LAB-007`, revisor `REV-DBAMANAGER` (distinto del proponente `REV-CLAUDEAGENT`), `2026-09-27T05:22:22Z`, contra el digest `9eb0d4e1…1c68ecbf`. El motor informa `review_status: APPROVED_BY_HUMAN` con verificación `STRUCTURAL_ONLY_IDENTITY_NOT_VERIFIED`: comprueba la estructura y el digest, no la identidad del firmante. `PROMOTE` (merge, tag) sigue siendo acción humana.

## 12. Motor de gobernanza

`advise --mode estack` (2026-09-27T05:15:47Z): `governance_state: PENDING_HUMAN_REVIEW`, `blockers: []`, `promote_status: HUMAN_ACTION_REQUIRED`, `content_digest: 9eb0d4e1b9e6cf8b14783add6a61cabf2351712b19857c5b1160084b1c68ecbf`. La salida queda fuera del repo, en `~/.local/share/oracle-diagnostic-estack/change-evidence/CHG-ESTACK-ORA19C-LAB-007/`.

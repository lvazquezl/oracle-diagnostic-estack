# CHG-ESTACK-ORA19C-LAB-005 — `V$BACKUP_REDOLOG` sin `COMPLETION_TIME`: diccionario y `Q-RMAN-ARCHIVELOG-BACKUP-001`

**Tipo:** `/change query|compatibility|skill` (plano B, `ESTACK_DEVELOPMENT`) · **Rama:** `change/dict-backup-redolog-v2` (desde `0.19.0`, `1275c17`; reaplica `f565d7d` de `change/dict-backup-redolog`, que partía de `a00ea2c`)
**Origen:** `CHG-REQ-DICT-BACKUP-REDOLOG`, detectado en la validación en el lab de `CHG-ESTACK-ORA19C-LAB-004`
**Estado:** propuesto. Validado en el lab (§8). Pendiente: HUMAN REVIEW (§11–12). `PROMOTE`, commit, merge, tag y push son acciones humanas.

READ-ONLY ALWAYS · HUMAN-EXECUTED REMEDIATION ONLY. Ninguna política cambia.

## 1. DETECT GAP

Al validar `Q-RMAN-BACKUP-FRESHNESS-001` en el lab (`REQ-3b8ff260b90c`), la sentencia falló en Oracle real con `DRIVER_ERROR`. La causa, verificada en Oracle Database Reference 19c, es que **`V$BACKUP_REDOLOG` no tiene `COMPLETION_TIME`**. Sus columnas son `RECID`, `STAMP`, `SET_STAMP`, `SET_COUNT`, `THREAD#`, `SEQUENCE#`, `RESETLOGS_CHANGE#`, `RESETLOGS_TIME`, `FIRST_CHANGE#`, `FIRST_TIME`, `NEXT_CHANGE#`, `NEXT_TIME`, `BLOCKS`, `BLOCK_SIZE`, `TERMINAL` y `CON_ID`.

Desde Fase 7, el diccionario (`compatibility/oracle-dictionary/views.yaml`) declaraba esa columna, y la query certificada **`Q-RMAN-ARCHIVELOG-BACKUP-001`** la seleccionaba en sus dos variantes. En Oracle real habría fallado con `ORA-00904` en 10g–23ai. Nadie lo detectó porque la query nunca se había ejecutado contra una base real, y el validador estático comprueba contra el mismo diccionario equivocado.

## 2. CHANGE REQUEST — alcance

| Artefacto | Cambio | Versión |
|---|---|---|
| `compatibility/oracle-dictionary/views.yaml` | Se retira `V$BACKUP_REDOLOG.completion_time`; nota con la fuente y las columnas reales | — |
| `queries/rman/Q-RMAN-ARCHIVELOG-BACKUP-001.md` | Se retira `completion_time` de V1 y V2 | **1.0.0 → 2.0.0 (breaking)**: cambia el contrato de salida |
| `skills/rman/backup-freshness` | La frescura de archivelog pasa de `Q-RMAN-ARCHIVELOG-BACKUP-001` a `Q-RMAN-BACKUP-FRESHNESS-001` (antigüedad calculada en la base) | 1.0.0 → 1.1.0 |
| `tests/test_backup_redolog_has_no_completion_time.sh` | Guardia de regresión nueva (excluye las queries generadas `Q-DICT-VERIFY-*`, que nombran vistas sólo como literales) | — |
| `queries/oracle/dictionary/Q-DICT-VERIFY-*`, `collectors.json`, fixtures | Regeneradas desde el diccionario (`CHG-ESTACK-ORA19C-LAB-006`): 477 → 476 tokens | — |

No se expone nada nuevo en el gateway, y el lab no cambia.

## 3. GAP ANALYSIS

1. **IDs:** no hay IDs nuevos. `Q-RMAN-ARCHIVELOG-BACKUP-001` conserva su ID, sube de versión y sigue siendo la misma query lógica.
2. **Consumidores de `Q-RMAN-ARCHIVELOG-BACKUP-001`:**
   - `rman/archivelog-backup` sólo produce `backed_up` por thread/secuencia (su output schema no tiene fecha de backup), así que **no le afecta**.
   - `rman/backup-freshness` la usaba como evidencia opcional de `last_archivelog_backup`, y **pierde esa fuente**. Se reemplaza por `Q-RMAN-BACKUP-FRESHNESS-001` (certificada y validada en el lab en `v0.17.0`). Cuando el valor proviene de ahí es una antigüedad (`"<horas>h"`, respecto de `collected_at_utc`), nunca una fecha absoluta inventada.
   - Documentación que la cita (`docs/PHASE_7_*`, `docs/RMAN_READONLY_*`, `agents/oracle-backup-recovery-analyst/AGENT.md`): sólo menciona la vista o la query, no la columna, así que no requiere cambios.
3. **Alternativa descartada:** conservar la fecha con un `JOIN` a `V$BACKUP_SET` por `SET_STAMP`/`SET_COUNT`. Obligaría a registrar esas columnas en el diccionario como válidas en 10g–23ai, y sólo se verificó 19c. Declararlo sin validar repetiría el mismo tipo de defecto.
4. **Por qué el validador no bastaba:** `tests/test_sql_static_validator.sh` confía en el diccionario y sólo revisa la primera lista `SELECT`. La guardia nueva no depende del diccionario para la query: revisa **cada tramo** (`UNION [ALL]`) de **cada** bloque SQL certificado que lea `v$backup_redolog`.

## 4. IMPACT ANALYSIS

| Dimensión | Impacto |
|---|---|
| Queries | Sólo `Q-RMAN-ARCHIVELOG-BACKUP-001` (2.0.0). Su SHA-256 cambia, pero no está expuesta en el gateway |
| Gateway / lab | Ninguno: la query no está en `collectors.json` ni en el adaptador lab |
| `config/query-compatibility-matrix.yaml` / `queries/REGISTRY.md` | Sin cambios: mismas vistas, variantes, rangos, costo y scope |
| `config/capability-matrix.yaml` / `docs/CAPABILITY_MATRIX.md` | Sin cambio de cobertura |
| Versión / arquitectura | 10g–23ai; standalone/RAC; `ANY_CONTAINER` (sin cambios) |
| Licencia / costo | `none` / `MEDIUM` (sin cambios) |
| Skills | `rman/backup-freshness` 1.1.0 (fuente de frescura de archivelog); `rman/archivelog-backup` sin cambios |
| Breaking | Sí, para quien leyera `completion_time` de esta query. Esa columna nunca pudo devolverse en Oracle real, así que ningún consumidor real dependía de ella |

## 5. PROPOSAL / IMPLEMENT

Ver §2. Los archivos cambiados son los cuatro de la tabla, más este documento y `CHANGELOG.md`.

## 6. Compatibilidad

| Check | Resultado | Base |
|---|---|---|
| `version_coverage` | PASS | V1 10.2–11.2 y V2 12.1–23.0 sin cambios; sólo se retira una columna |
| `query_contract` | PASS | Query Contract v2 completo; `version` 2.0.0; `tests/test_rman_query_*`, `test_backup_archivelog_query` en verde |
| `dictionary_columns` | PASS | La columna retirada no existe (Oracle Database Reference 19c); las restantes (`thread#`, `sequence#`, `first_time`, `next_time`) sí están documentadas; `test_sql_static_validator` en verde |
| `architecture` | PASS | Sin cambio de scope; la corrección se origina en una ejecución real (lab 19c, `CDB$ROOT`) de la misma vista |
| `cost_and_license` | PASS | Sin cambios |
| `test_coverage` | PASS | Guardia nueva probada con mutaciones: detecta el diccionario viejo y **cada** variante vieja de la query, sin falso positivo sobre `Q-RMAN-BACKUP-FRESHNESS-001` |

Verificación por versión (Oracle Database Reference, 2026-09-23): **12.2, 19c y 23ai** documentan `V$BACKUP_REDOLOG` **sin** `COMPLETION_TIME` y **con** `THREAD#`, `SEQUENCE#`, `FIRST_TIME` y `NEXT_TIME` (23ai agrega `SECTION_SIZE`). Ejecución real sólo en el lab **19c**. **10.2/11.2** no se verificaron contra su documentación; se retira la columna por coherencia: quitarla no puede introducir un `ORA-00904`, agregarla sí. Las cuatro columnas restantes son pre-10g según el diccionario, pero en 10.2/11.2 eso sigue siendo `DOCUMENTATION_VALIDATED` del repo, no una verificación nueva.

## 7. SECURITY VALIDATION

Sin superficie nueva: la query queda con menos columnas, sigue siendo `SELECT`-only (`test_no_write_operations` en verde) y no se expone en el gateway. Veredicto: **PASS**.

## 8. REGRESSION VALIDATION

**Base `0.19.0`** (macOS, bash 5.3.20, validador estático activo): **965/965** (964 de `0.19.0` + el guard nuevo). Mutación: con la versión anterior de `Q-RMAN-ARCHIVELOG-BACKUP-001`, el guard falla en los dos bloques.

**Validación en el lab** (2026-09-27, `lab-ol8-19c`, 19c, `CDB$ROOT`, commit `dfd17ba`): las 5 partes regeneradas corrieron `OK`/`REAL`, sin limitaciones, **476 tokens** (96 + 95 + 94 + 98 + 93). `V$BACKUP_REDOLOG.COMPLETION_TIME` **ya no aparece**. Las 12 discrepancias restantes son exactamente las de `CHG-ESTACK-ORA19C-LAB-006` §8 (`CHG-REQ-DICT-19C-FIXES`). Evidencia: `EVR-58719b3fc57edb1aacdd95f1` (001), `EVR-24120c73e93166a862970a60` (002), `EVR-5323e0c9f50a5e8ab6ae819d` (003), `EVR-2eb75b010d22ca4108c3bad0` (004), `EVR-53a6ddc4acd4d5c027a0bfea` (005).

Un primer intento el mismo día falló en todos los collectors, incluida la identidad, con `NETWORK_UNREACHABLE`: la red del lab estaba caída. Se confirmó con `check` y con una prueba TCP ("host is down"). No tuvo relación con este cambio.

**Errata del registro original (2026-09-23):** la línea "949/962 antes y 950/963 después, con los mismos 13 fallos preexistentes" se midió en macOS con `/bin/bash` 3.2. Esos 13 fallos eran exclusivos de macOS, y con esa versión de bash `test_sql_static_validator` pasaba sin validar nada (`CHG-ESTACK-PORTABILITY-001`, `0.18.0`). Los PASS del validador citados en §6 no tenían valor probatorio en ese momento; la cifra de arriba sí.

## 9–10. Registros relacionados

- Cierra `CHG-REQ-DICT-BACKUP-REDOLOG`.
- Cubre en parte `CHG-REQ-SKILL-RMAN-AGE-EVIDENCE` (`rman/backup-freshness`). `rman/backup-status` sigue pendiente.
- `CHG-REQ-TEST-BSD-GREP` quedó cerrado por `CHG-ESTACK-PORTABILITY-001` (`0.18.0`).
- `CHG-REQ-DICT-RMAN-AUDIT` lo cubrió `CHG-ESTACK-ORA19C-LAB-006` (`0.19.0`) para todos los dominios: confirmó esta columna en Oracle real y encontró 12 discrepancias más (`CHG-REQ-DICT-19C-FIXES`).

## 11. HUMAN REVIEW (pendiente)

Revisor distinto del proponente (`E_AUTH_SELF_APPROVAL`). La aprobación se registra contra el `content_digest` que informa el motor (§12).

## 12. Motor de gobernanza

`advise --mode estack` (2026-09-27T04:31:43Z), base `0.19.0`: `governance_state: PENDING_HUMAN_REVIEW`, `blockers: []`, `promote_status: HUMAN_ACTION_REQUIRED`, `content_digest: 85c3e5adce8868fe03b4d60f9ff0ae3aaff63ff59db418ce62a15e62a45c1f1f`. Reemplaza al digest anterior (`00d7f0cb…eced88`, sobre `a00ea2c`). La salida queda fuera del repo, en `~/.local/share/oracle-diagnostic-estack/change-evidence/CHG-ESTACK-ORA19C-LAB-005/`.

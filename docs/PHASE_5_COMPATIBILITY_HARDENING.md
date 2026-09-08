# Phase 5 — Data Guard Compatibility & Query Certification Hardening

Cierra tres defectos de certificación detectados en `phase/5-dataguard` antes de aprobar `v0.5.0-dataguard`, y endurece el sistema de validación que debió detectarlos y no lo hizo. No reconstruye Phase 5 — sólo corrige.

**Nota (superado parcialmente)**: la metadata de `V$DATAGUARD_PROCESS` y la frontera de versiones legacy/modern descritas en las secciones 5-6 de este documento contenían defectos reales (min_version incorrecto, columnas STATUS/CLIENT_PROCESS inexistentes en esa vista) — corregidos en un hardening posterior, ver `docs/PHASE_5_FINAL_PROCESS_VIEW_PORTABILITY_HARDENING.md`. El resto de este documento (Q-DG-ROLE-001, LOG_ARCHIVE_CONFIG, SQL Static Validator, future version policy) permanece vigente.

## 1. Q-DG-ROLE-001 fix

`Q-DG-ROLE-001` v1.0 seleccionaba `log_archive_config` de `V$DATABASE`. Esa columna **no existe** en `V$DATABASE` — es un parámetro de inicialización, disponible sólo vía `V$PARAMETER`. Corregida a v2.0.0: el `SELECT` ya no incluye `log_archive_config`; el resto de columnas (`db_unique_name`, `database_role`, `open_mode`, `switchover_status`, `protection_mode`, `protection_level`, `force_logging`, `flashback_on`) son todas columnas reales, estables desde 10g.

## 2. LOG_ARCHIVE_CONFIG source

`LOG_ARCHIVE_CONFIG` sigue siendo evidencia relevante para `dataguard/role` (correlación) y `dataguard/configuration-drift` (comparación primary/standby) — pero se obtiene correctamente vía `Q-ORA-PARAMETERS-001` (`V$PARAMETER`, ya certificada en Oracle Core desde Fase 2), filtrando `name = 'log_archive_config'`. No se creó una query nueva — Oracle Core ya la resuelve. `skills/dataguard/role/SKILL.md`, `agents/oracle-dataguard-analyst/AGENT.md` y `docs/DATAGUARD_DIAGNOSTIC_MODEL.md` fueron corregidos para atribuir la fuente correctamente. `skills/dataguard/configuration-drift/SKILL.md` ya la atribuía bien — no requirió cambio.

## 3. SQL Static Validator fix (causa raíz)

**Por qué ningún test lo detectó**: `tests/test_no_variant_references_unknown_column.sh` es un alias que delega a `tests/test_sql_static_validator.sh`, y ese validador **sólo verificaba version-gating** de 4 columnas conocidas (`version_full`, `cdb`, `con_id`, `instance_role`) — nunca existencia real de columna en la vista referenciada. `compatibility/oracle-dictionary/views.yaml` sí modelaba columnas por vista para algunas vistas, pero nada cruzaba esa metadata contra las columnas realmente seleccionadas en el SQL certificado.

**Fix**: se añadió un segundo chequeo independiente al validador — existencia de columna, no sólo version-gating — que:

- Resuelve alias básicos (`SELECT d.col FROM v$archive_dest d`) y JOIN/comma-join (`FROM v$instance i, v$database d`, `... JOIN v$x y ON ...`).
- Se abstiene (skip, sin falso positivo) ante subqueries anidadas en el `SELECT` — deliberadamente, para no convertirse en un parser SQL completo (`# 8` del prompt de hardening).
- Trata `GV$xxx` como `V$xxx` + `INST_ID` (convención real de Oracle y ya documentada en todo el dictionary), evitando falsos positivos sobre `inst_id`.

**Descubrimiento durante la construcción — `columns_exhaustive`**: al activar el chequeo de existencia contra TODO el catálogo, apareció un falso positivo real: `V$ASM_DISK` (Fase 4) tenía un bloque `columns:` con sólo 6 columnas (las relevantes a un bug histórico de version-gating), no una lista completa — `GROUP_NUMBER`/`DISK_NUMBER`/`NAME`, genuinamente usadas por `Q-ASM-DISKS-001`, no estaban registradas. Se introdujo el flag `columns_exhaustive: true` en `views.yaml`: el chequeo de existencia sólo se activa sobre vistas marcadas así explícitamente. Se marcaron únicamente las 9 vistas Data Guard auditadas exhaustivamente en este hardening (`V$DATABASE`, `V$ARCHIVE_DEST`, `V$ARCHIVE_DEST_STATUS`, `V$ARCHIVED_LOG`, `V$DATAGUARD_STATS`, `V$MANAGED_STANDBY`, `V$DATAGUARD_PROCESS`, `V$STANDBY_LOG`, `V$ARCHIVE_GAP`) — vistas de fases anteriores quedan permisivas (sin regresión, fuera de alcance de este prompt).

**Regresión de rendimiento evitada**: la primera implementación usaba `python3` por cada item de `SELECT` para partir listas respetando profundidad de paréntesis — impracticablemente lento en Windows Git Bash (arranque de intérprete repetido). Reescrito en bash puro (loop de caracteres, sin subproceso) + cacheo de columnas por vista (`declare -A`) + filtro rápido de "¿el bloque siquiera menciona una vista `columns_exhaustive`?" antes de la extracción completa.

## 4. Future version policy

`agents/oracle-dataguard-analyst/manifest.yaml` ya declaraba `family: "future" -> status: UNKNOWN_FUTURE` — pero `config/query-compatibility-matrix.yaml` declaraba `max: latest` en las 7 queries `Q-DG-*`, y el Query Variant Resolver resuelve `vernum("latest") = 99999` — un techo sin límite real. Cualquier major futura desconocida (ej. 24.x) resolvía como compatible por herencia, contradiciendo la propia declaración del agente.

**Fix**: las 7 entradas `Q-DG-*` en `config/query-compatibility-matrix.yaml` pasan de `max: latest` a `max: "23.0"` explícito — refleja exactamente las versiones certificadas (10g–23ai). Una major futura ya no hace match y cae correctamente en `COMPATIBILITY_VALIDATION_REQUIRED`. `config/capability-matrix.yaml` y `docs/CAPABILITY_MATRIX.md` (fila Data Guard) fueron aclarados: `latest: SUPPORTED` significa únicamente "la major más reciente certificada hoy" — nunca herencia automática para una versión futura desconocida; esa determinación la hace `agents/oracle-dataguard-analyst/manifest.yaml#supported_versions`.

También se corrigió, durante la misma auditoría: 3 entradas (`Q-DG-STATS-001`, `Q-DG-ARCHIVED-LOG-001`, `Q-DG-ARCHIVE-GAP-001`) en `config/query-compatibility-matrix.yaml` todavía usaban `role_scope: PHYSICAL_STANDBY`, fuera del enum establecido (`PRIMARY|STANDBY|ANY|NOT_APPLICABLE`, `docs/CONTRACTS.md`) — corregido a `STANDBY`. Se había corregido en los archivos `.md` de las queries y en los manifests de skills en una sesión anterior, pero se omitió esta matriz.

## 5. V$MANAGED_STANDBY modernization

`Q-DG-MANAGED-PROCESS-001` v1.0 usaba exclusivamente `V$MANAGED_STANDBY`/`GV$MANAGED_STANDBY` para todo el rango 10g–23ai, sin considerar `V$DATAGUARD_PROCESS` (vista de agentes/procesos Broker más moderna y genérica, disponible desde 11gR2).

**Fix (v2.0.0)** — modelo legacy/modern explícito vía Query Variant Contract:

- **V1 (`legacy_managed_standby`, DEFAULT, 10.2+)**: `V$MANAGED_STANDBY`/`GV$MANAGED_STANDBY`. Sigue siendo la variante por defecto en **todo** el rango certificado — no está deprecada, sigue siendo la fuente más precisa para métricas de transporte/apply por thread.
- **V2 (`modern_dataguard_process`, ON-DEMAND ONLY, 11.2+)**: `V$DATAGUARD_PROCESS`/`GV$DATAGUARD_PROCESS`. **No es un reemplazo 1:1** — no expone `THREAD#`/`SEQUENCE#`/`BLOCK#` con la granularidad de transporte/apply por thread que sí tiene `V$MANAGED_STANDBY`. Por eso no se activa por defecto, y los campos lógicos `thread`/`sequence` quedan `PARTIALLY_SUPPORTED` en esta variante — nunca mapeados por inferencia (`# 20`: no forzar equivalencia, no inventar mapping).

## 6. Semantic normalization

Los skills (`dataguard/apply`, `dataguard/processes`) consumen un modelo lógico común (`dataguard_process`: `process_type`/`status`/`client_process`/`thread`/`sequence`/`source_view`), documentado en `queries/dataguard/Q-DG-MANAGED-PROCESS-001.md#semantic-normalization` — nunca columnas de una vista específica directamente. El cambio de variante activa (legacy/modern) es transparente para la lógica de decisión de los skills.

## 7. Tests (15 nuevos)

`test_dg_role_query_only_uses_vdatabase_columns.sh`, `test_log_archive_config_not_selected_from_vdatabase.sh`, `test_static_validator_detects_invalid_vdatabase_column.sh` (fixture negativo controlado, fuera del catálogo productivo), `test_static_validator_checks_aliased_columns.sh`, `test_dataguard_future_version_requires_validation.sh`, `test_dataguard_latest_not_automatically_supported.sh`, `test_dataguard_23ai_supported_when_certified.sh`, `test_dataguard_24_or_future_not_auto_supported.sh`, `test_dataguard_process_legacy_variant.sh`, `test_dataguard_process_modern_variant.sh`, `test_dataguard_process_legacy_does_not_use_modern_view.sh`, `test_dataguard_process_modern_uses_supported_columns.sh`, `test_dataguard_process_variant_resolution_11g.sh`, `test_dataguard_process_variant_resolution_19c.sh`, `test_dataguard_process_variant_resolution_23ai.sh`.

## 8. Known limitations

- El chequeo de existencia de columna del SQL Static Validator sólo cubre vistas marcadas `columns_exhaustive: true` — 9 vistas Data Guard en este hardening. Vistas de fases anteriores (incluyendo `V$ASM_DISK`, donde se encontró el mismo patrón de defecto) quedan fuera de alcance de este prompt; el hallazgo se documenta aquí para un futuro `/change` dedicado, no se corrige aquí (`# 36`: no rehacer fases anteriores).
- La existencia de columna no se valida dentro de subqueries anidadas en el `SELECT` (ej. `Q-ORA-ARCHIVE-001`, que usa una subquery escalar contra `V$ARCHIVED_LOG`) — abstención deliberada, documentada, no un parser SQL completo.
- `V$DATAGUARD_PROCESS` se registra con un subconjunto de columnas (`pid`, `name`, `status`, `client_process`) — no se certifica una equivalencia completa con `V$MANAGED_STANDBY`; ampliar sólo vía `/change query` con evidencia real.

# Phase 6 — Multitenant Query Compatibility & Dictionary Certification Hardening

Cierra tres defectos de certificación detectados en `phase/6-multitenant` antes de aprobar `v0.6.0-multitenant`, y endurece el sistema de validación que debió detectarlos y no lo hizo. No reconstruye Phase 6 — sólo corrige.

**Nota (superado)**: el `vernum3` mencionado en este documento (comparación patch-level acotada al Static Validator) fue reemplazado por una librería compartida única (`scripts/lib/version.sh`), usada ahora por el Query Variant Resolver, el Static Validator y todos los tests de compatibilidad relevantes — ver `docs/PHASE_6_FINAL_PDB_IDENTITY_PATCH_RESOLVER_HARDENING.md` y, para la consolidación final (eliminación de los últimos comparadores locales duplicados), `docs/PHASE_6_ORACLE_MULTITENANT.md`. Las referencias a `vernum3` abajo describen el estado histórico en el momento de este hardening, ya superado.

## 1. DBA_PDB_SAVED_STATES fix

`Q-CDB-PDB-SAVED-STATE-001` v1.0 seleccionaba `FROM cdb_pdb_saved_states`. Esa vista **no existe** — verificado vía WebFetch: `https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/CDB_PDB_SAVED_STATES.html` devuelve HTTP 404. La vista real es `DBA_PDB_SAVED_STATES` (7 columnas confirmadas: `CON_ID`, `CON_NAME`, `INSTANCE_NAME`, `CON_UID`, `GUID`, `STATE`, `RESTRICTED` — es un data link, también visible desde dentro de la PDB, aunque esta query sólo la consulta desde CDB$ROOT). Corregida a v2.0.0.

Además, la feature (PDB Saved State, no sólo la vista) requiere patch level **12.1.0.2** — no existe en 12.1.0.0/12.1.0.1 (corroborado por múltiples fuentes técnicas independientes; sin una nota "New Features" de docs.oracle.com indexada con URL propia — documentado como limitación de trazabilidad, no como hecho no verificado). En este hardening se extendió una comparación dedicada (`vernum3`) sin tocar el resolver genérico usado por el resto del catálogo — **superado**: `vernum3` ya no existe, la comparación patch-level vive únicamente en `scripts/lib/version.sh`.

## 2. V$RSRCPDBMETRIC fix

`Q-CDB-RESOURCE-USAGE-001` v1.0 declaraba `V$RSRCPDBMETRIC` disponible desde 12.1, sin verificación independiente. Verificado vía WebFetch: `https://docs.oracle.com/en/database/oracle/oracle-database/12.2/refrn/V-RSRCPDBMETRIC.html` declara explícitamente "introduced in Oracle Database 12c Release 2 (12.2.0.1)". La vista **no existe en 12.1**.

No existe una fuente equivalente certificada de métricas de recursos por PDB para 12.1 — no se inventó una alternativa. En su lugar, la capability degrada explícitamente: `skills/multitenant/resource-usage/SKILL.md` declara `capability_status: PARTIALLY_SUPPORTED` con razón explícita para targets 12.1; el resto del dominio Multitenant en ese target no se ve afectado. `config/query-compatibility-matrix.yaml` corregido de `min: "12.1"` a `min: "12.2"`. Todas las 17 columnas seleccionadas por la query están confirmadas reales en la referencia 12.2 — sin cambios de columna, sólo de rango de versión.

## 3. PDB_PLUG_IN_VIOLATIONS.CON_ID fix

`Q-CDB-PLUGIN-VIOLATIONS-001` v1.0 seleccionaba `CON_ID` incondicionalmente en un único bloque SQL declarado válido desde 12.1. Verificado vía WebFetch, comparando dos versiones reales de la referencia:

- 12.1 (`docs.oracle.com/database/121/REFRN/GUID-845E5369-CCB0-4F8D-AE09-447EF0CAC93F.htm`): **9 columnas**, sin `CON_ID` (`TIME`, `NAME`, `CAUSE`, `TYPE`, `ERROR_NUMBER`, `LINE`, `MESSAGE`, `STATUS`, `ACTION`).
- 12.2 (`docs.oracle.com/en/database/oracle/oracle-database/12.2/refrn/PDB_PLUG_IN_VIOLATIONS.html`): **10 columnas**, con `CON_ID` como última columna.

`CON_ID` se agrega en 12.2 — no existe en 12.1. Corregida a v2.0.0 con dos variantes reales (Query Variant Contract):

- **V1 (`legacy_121_no_con_id`, 12.1 only)**: `SELECT time, name, cause, type, error_number, line, message, status, action FROM pdb_plug_in_violations` — nunca selecciona `con_id`, nunca lo inventa.
- **V2 (`modern_122plus_con_id`, 12.2–23.0)**: agrega `con_id` al inicio del `SELECT`.

## Semantic normalization — plugin-violations

`skills/multitenant/plugin-violations/SKILL.md` normaliza ambas variantes al mismo modelo lógico (`plugin_violation`: `container_id`/`container_name`/`pdb_token`/`identity_status`/`time`/`cause`/`type`/`error_number`/`line`/`message`/`status`/`action`/`source_variant`). En la variante legacy, `container_id: NOT_AVAILABLE` — sin `CON_ID`, no hay forma de correlacionar contra `V$PDBS` por contenedor en 12.1 (comportamiento documentado de Oracle, no una limitación de este skill). **Corrección (PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING)**: esta sección afirmaba que `container_name` nunca se infiere de `NAME` "que identifica la violación/componente, no la PDB" — incorrecto, verificado contra Oracle Database Reference: `NAME` es *"the name of an existing PDB or a PDB intended to be created"*. `container_name`/`pdb_token` sí se derivan de `NAME` (sanitizado) en la variante legacy; en la moderna se correlaciona `CON_ID`+`NAME`, publicando `IDENTITY_MISMATCH` si no coinciden — ver `docs/PHASE_6_FINAL_PDB_IDENTITY_PATCH_RESOLVER_HARDENING.md`.

## 4. SQL Static Validator fix (causa raíz)

**Por qué ningún test lo detectó**: `tests/test_sql_static_validator.sh` tenía dos chequeos — (1) version-gating de 4 columnas globales hardcodeadas (`version_full`, `cdb`, `con_id`, `instance_role`), ninguna específica de vista; (2) existencia de columna en la vista referenciada (para vistas `columns_exhaustive: true`), pero **nunca comparaba el `min_version` de la vista o de la columna contra el rango declarado del bloque SQL**. Una columna que "existe en algún momento de la vida de la vista" pasaba el chequeo (2) aunque el bloque SQL declarara un rango de versión anterior a cuando esa columna realmente apareció. Esto es exactamente por qué `V$RSRCPDBMETRIC` (vista entera con min_version incorrecto) y `PDB_PLUG_IN_VIOLATIONS.CON_ID` (columna con min_version incorrecto) certificaron SQL incorrecto sin que ningún test lo detectara — la metadata del propio dictionary nunca se validó contra sí misma.

**Fix**: se añadió un tercer chequeo independiente (chequeo 3) — view-level y column-level `min_version` cross-check contra el `range_min` declarado del bloque SQL:

- `get_view_min_version`/`resolve_view_min_version`: extraen el `min_version` de nivel-vista de `compatibility/oracle-dictionary/views.yaml`, comparado contra el `range_min` de cada bloque (con fallback `GV$xxx` → `V$xxx`, misma convención que el chequeo de columnas).
- `get_view_column_min_versions`/`resolve_col_min_versions_for_view`: extraen, para vistas `columns_exhaustive: true`, el `min_version` por columna — extendiendo el chequeo de existencia ya presente para también comparar disponibilidad temporal, no sólo presencia.
- `vernum3`: comparación patch-level-aware (`maj*10000 + min*100 + patch`) — extensión **aditiva**, no reemplaza el `vernum()` de 2 niveles (chequeo 1, ni el usado por `tests/test_query_variant_resolver_10g.sh`/`_11g.sh`), que sigue major.minor-only y no requiere precisión de patch level para las queries que valida.

**Corrección de un efecto colateral descubierto durante la construcción**: el chequeo 3, al activarse, producía falsos positivos contra `Q-CDB-LOCKDOWN-001` y (tras la corrección de este hardening) `Q-CDB-RESOURCE-USAGE-001` — ambas genuinamente 12.2+-only, pero el bucle `implicit_full_range` deriva su `min` de la primera etiqueta descriptiva de `supported_oracle_versions` (`"12c"` → `12.1`, imprecisión ya presente y hasta ahora inofensiva porque nada la validaba contra columnas). Se corrigió sustituyendo, sólo para el chequeo 3, ese `min` derivado por el valor preciso declarado en `config/query-compatibility-matrix.yaml` para esa `query_id` — el chequeo 1 (RISKY_COLUMNS) sigue usando el `min` derivado original, sin cambios, evitando cualquier regresión de comportamiento fuera de este hardening.

## 5. Dictionary certification hardening

- Las 7 vistas Multitenant `columns_exhaustive: true` declaran ahora `validation: {source_type: ORACLE_DOCUMENTATION, status: DOCUMENTATION_VALIDATED, validated_for: [...]}` — incluyendo `V$CONTAINERS`, que ya estaba verificada en la construcción base de Fase 6 pero nunca declaró el bloque de trazabilidad explícito.
- `CDB_PDB_SAVED_STATES` eliminada del dictionary — nunca fue una vista real.
- Tests negativos (`test_unknown_multitenant_view_not_certified.sh`, `test_unknown_multitenant_column_not_certified.sh`) confirman que un nombre de vista/columna fabricado (`FAKE_MULTITENANT_VIEW`, `fake_column`) nunca aparece registrado — sin inyectar un archivo falso en `queries/` real, validando el predicado exacto del que depende el resultado `NOT_CERTIFIED`.

## 6. Patch-level version support

`vernum3` (sección 4) es la única extensión patch-level-aware del repositorio — deliberadamente acotada a los casos que la requieren (PDB Saved State) sin modificar el resolver major.minor genérico usado por el resto del catálogo (`docs/QUERY_VARIANTS.md`, sin cambios). Documentado como limitación explícita en `compatibility/oracle-dictionary/views.yaml` (cabecera del archivo).

## 7. Tests (21 nuevos)

`test_pdb_saved_state_uses_dba_view.sh`, `test_cdb_pdb_saved_states_not_certified.sh`, `test_pdb_saved_state_12101_not_supported.sh`, `test_pdb_saved_state_12102_supported.sh`, `test_pdb_saved_state_columns_valid.sh`, `test_v_rsrcpdbmetric_not_supported_121.sh`, `test_v_rsrcpdbmetric_supported_122.sh`, `test_pdb_resource_usage_121_partial.sh`, `test_pdb_resource_usage_122_supported.sh`, `test_pdb_resource_usage_columns_valid.sh`, `test_plugin_violation_121_variant_without_con_id.sh`, `test_plugin_violation_modern_variant_with_con_id.sh`, `test_plugin_violation_121_does_not_reference_con_id.sh`, `test_plugin_violation_modern_columns_valid.sh`, `test_plugin_violation_variant_resolution.sh`, `test_multitenant_dictionary_entries_have_validation_source.sh`, `test_unknown_multitenant_view_not_certified.sh`, `test_unknown_multitenant_column_not_certified.sh`, `test_multitenant_static_validator_version_aware.sh`, `test_version_resolver_12101.sh`, `test_version_resolver_12102.sh`.

## 8. Known limitations

- El chequeo 3 (view/column-level `min_version` cross-check) sólo cubre las 7 vistas Multitenant `columns_exhaustive: true` — no se extendió retroactivamente a vistas de fases anteriores (RAC/ASM/Data Guard/Oracle Core), pese a que el mismo patrón de defecto podría existir ahí (precedente conocido: `V$ASM_DISK` en Fase 4, `V$DATAGUARD_PROCESS` en Fase 5) — documentado para un `/change` dedicado, fuera de alcance de este prompt (`# 42`: no rehacer fases anteriores salvo defecto directamente relacionado).
- ~~`vernum3` (patch-level) no se generalizó al resolver genérico...~~ — **resuelto** en PHASE 6 — VERSION RESOLVER CONSOLIDATION FINALIZATION: `vernum3` eliminado, `scripts/lib/version.sh` es ahora la única implementación de comparación de versión en todo el repositorio (Query Variant Resolver, Static Validator, todos los tests de compatibilidad relevantes), con enforcement global (`tests/test_no_local_version_resolvers_in_tests.sh`).
- El boundary patch-level de PDB Saved State (12.1.0.2) se corrobora con múltiples fuentes técnicas independientes convergentes, no con una nota oficial "New Features" de docs.oracle.com indexada con URL propia — documentado explícitamente como limitación de trazabilidad en `compatibility/oracle-dictionary/views.yaml`, no presentado como un hecho de igual certeza que los hallazgos vía WebFetch directo (`DBA_PDB_SAVED_STATES` existencia/columnas, `V$RSRCPDBMETRIC` min_version, `PDB_PLUG_IN_VIOLATIONS.CON_ID` boundary).

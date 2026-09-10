# Phase 6 — Version Resolver Consolidation Finalization

Cierra el último bloqueo antes de aprobar `v0.6.0-multitenant`: consolida toda comparación de versión Oracle del repositorio sobre una única implementación compartida (`scripts/lib/version.sh`), migrando los ~17 archivos de test que aún reimplementaban `vernum()`/`vernum3()` localmente (fuera de alcance en los dos hardenings anteriores) y endureciendo el enforcement para que la regresión sea imposible sin que un test la detecte. No reconstruye Phase 6 — sólo consolida.

## 1. Local resolver inventory — antes

Búsqueda global (`grep -rE '^\s*(function\s+)?vernum3?\s*\(\)'` sobre `tests/**/*.sh`) encontró 17 archivos con definiciones locales:

`test_plugin_violation_variant_resolution.sh`, `test_version_resolver_{12101,12102}.sh`, `test_dataguard_process_variant_resolution_{11g,121,122,19c,23ai}.sh`, `test_dataguard_{24_or_future_not_auto_supported,23ai_supported_when_certified}.sh`, `test_query_variant_resolver_{12c,18c,19c,21c,23ai}.sh`, `test_query_variant_ranges_do_not_overlap_invalidly.sh`, `test_fixture_query_variant_resolution.sh`.

Todos ya usaban una extracción de rango patch-level-safe (`min: "[^"]+"`, sin restricción a 2 dígitos) — el defecto no estaba en la extracción, sino en la comparación (`vernum`, 2-tier, ignora todo componente más allá de major.minor).

## 2. Migration

Los 17 archivos se refactorizaron para `source scripts/lib/version.sh` y usar `version_in_range`/`version_gte`/`version_lte`/`compare_oracle_versions` — sin cambiar la lógica de negocio de cada test (mismas aserciones, mismos labels, mismo TARGET representado ahora como string de versión en vez de entero mágico tipo `vernum()`).

**Hallazgo real durante la migración** (no un bug de la migración): `test_query_variant_resolver_12c.sh` empezó a fallar tras el refactor — `Q-CDB-PDB-SAVED-STATE-001` (min real `12.1.0.2`) resolvía como compatible para "12c" con el comparador 2-tier antiguo (`vernum("12.1.0.2")` truncaba el patch level, igual que `vernum("12.1")`), pero correctamente **no** resuelve con el comparador patch-level-aware, porque el alias de marketing "12c" normaliza a `12.1.0.0.0`, por debajo del mínimo real `12.1.0.2.0`. Esto es exactamente el defecto que este hardening existe para cerrar — el comparador viejo *ocultaba* una incompatibilidad real. Corregido añadiendo `Q-CDB-PDB-SAVED-STATE-001` a `EXPECTED_UNSUPPORTED` en ese test (mismo criterio ya aplicado a los tests 10g/11g en el hardening anterior).

## 3. Local resolver inventory — después

`tests/test_no_local_version_resolvers_in_tests.sh` (nuevo, enforcement global): recorre `tests/**/*.sh` y `scripts/**/*.sh` (excepto `scripts/lib/version.sh`, la implementación autorizada) buscando `vernum()`, `vernum3()`, `version_to_number()`, `compare_version()` o equivalente, ancladas a inicio de línea (evita falsos positivos por comentarios/prosa — sólo escanea `.sh`, nunca `.md`/`.yaml`). Resultado: **0 definiciones locales**.

## 4. Enforcement hardening

`tests/test_query_variant_resolver_uses_shared_version_library.sh` reescrito — de un allowlist fijo de 7 archivos (Fase 6 — Final PDB Identity & Patch-Level Resolver Hardening) a:

1. Delegación de la comprobación negativa global a `test_no_local_version_resolvers_in_tests.sh` (mismo patrón "alias/wrapper" que `test_no_variant_references_unknown_column.sh` → `test_sql_static_validator.sh`).
2. Comprobación positiva dinámica: cualquier test que invoque `version_gte`/`version_lte`/`version_in_range`/`compare_oracle_versions`/`normalize_oracle_version` debe sourcear `scripts/lib/version.sh` — sin exigir el import a tests que no comparan versiones (nunca un allowlist estático que pueda quedar desactualizado).

## 5. New tests

`test_no_local_version_resolvers_in_tests.sh` (enforcement global, reporta archivo:línea), `test_shared_version_library_exists.sh` (existencia + smoke test funcional de las 5 funciones canónicas).

## 6. Documentation fixes

- `queries/multitenant/Q-CDB-PDB-SAVED-STATE-001.md`: nota "el Query Variant Resolver genérico compara sólo major.minor" (cierta cuando se escribió, falsa desde el hardening anterior) corregida — declara explícitamente `minimum certified version: 12.1.0.2` y `boundary enforcement: scripts/lib/version.sh` (shared, patch-level-aware).
- `compatibility/oracle-dictionary/views.yaml` (cabecera): misma corrección — ya no describe una limitación, documenta `scripts/lib/version.sh` como la única implementación autorizada.
- `docs/PHASE_6_QUERY_COMPATIBILITY_HARDENING.md`: nota de superación agregada al encabezado; el ítem de "Known limitations" sobre `vernum3` marcado como resuelto (tachado, no eliminado — preserva el registro histórico).
- `docs/PHASE_6_FINAL_PDB_IDENTITY_PATCH_RESOLVER_HARDENING.md`: el ítem de "Known limitations" sobre los ~17 archivos pendientes marcado como resuelto (tachado, no eliminado).

## 7. Canonical resolver contract

`scripts/lib/version.sh` es formalmente la **Canonical Oracle Version Comparison Implementation** para: Query Variant Resolver (documentado en `docs/QUERY_VARIANTS.md`, que ya referenciaba la librería desde el hardening anterior), Static Validator (`tests/test_sql_static_validator.sh`), toda la suite de compatibility tests, y el futuro Gateway MCP (Fase 7 — no implementado en este hardening, sólo el contrato queda declarado para cuando exista runtime real).

## 8. Regression — Oracle Core / Data Guard / Multitenant

Las 5 familias de versión Oracle Core (`12c/18c/19c/21c/23ai`) y las 5 resoluciones de proceso Data Guard (`11g/12.1/12.2/19c/23ai`) siguen resolviendo exactamente igual que antes de la migración — verificado explícitamente comparando el resultado PASS/FAIL de cada test antes y después del refactor (único cambio real de comportamiento: el hallazgo de la sección 2, deliberado y correcto, no una regresión).

## 9. PDB identity regression

Sin cambios al fix aprobado en el hardening anterior — `PDB_PLUG_IN_VIOLATIONS.NAME` sigue siendo identidad de PDB en 12.1, `CON_ID` sigue `NOT_AVAILABLE`. Los 6 tests de identidad (`test_plugin_violation_121_*`, `test_plugin_violation_modern_con_id_and_name.sh`, etc.) no se tocaron — siguen pasando sin modificación.

## 10. Known limitations

- Ninguna conocida sobre comparación de versión — es precisamente el objetivo cerrado por este hardening. El único comparador de versión en todo el repositorio es `scripts/lib/version.sh`.
- El Gateway MCP real (ejecución runtime contra una base de datos Oracle real) sigue sin implementarse — Fase 7, explícitamente fuera de alcance (`# 20` del prompt: "no implementar MCP runtime, no implementar ejecución SQL real").

## Referencia

`scripts/lib/version.sh`, `docs/QUERY_VARIANTS.md`, `docs/PHASE_6_QUERY_COMPATIBILITY_HARDENING.md`, `docs/PHASE_6_FINAL_PDB_IDENTITY_PATCH_RESOLVER_HARDENING.md`, `tests/test_no_local_version_resolvers_in_tests.sh`, `tests/test_shared_version_library_exists.sh`, `tests/test_query_variant_resolver_uses_shared_version_library.sh`.

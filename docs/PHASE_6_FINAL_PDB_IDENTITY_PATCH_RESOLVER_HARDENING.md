# Phase 6 — Final PDB Identity & Patch-Level Resolver Hardening

Cierra los dos últimos defectos detectados en `phase/6-multitenant` antes de aprobar `v0.6.0-multitenant`. No reconstruye Phase 6 — sólo corrige.

## 1. PDB_PLUG_IN_VIOLATIONS.NAME semantics

La construcción base de Fase 6 y el hardening de compatibilidad posterior asumían, sin verificación independiente, que `PDB_PLUG_IN_VIOLATIONS.NAME` identifica *"la violación/componente"*, no la PDB. Verificado vía WebFetch contra Oracle Database Reference — **ambas** versiones (12.1: `docs.oracle.com/database/121/REFRN/GUID-845E5369-CCB0-4F8D-AE09-447EF0CAC93F.htm`; 19c: `docs.oracle.com/en/database/oracle/oracle-database/19/refrn/PDB_PLUG_IN_VIOLATIONS.html`) coinciden en la descripción textual de Oracle:

> "The name of an existing PDB or a PDB intended to be created (if a row was entered as a result of running `DBMS_PDB.CHECK_PLUG_COMPATIBILITY`)"

`NAME` es identidad de PDB, disponible en **todo** el rango 12.1–23ai — incluso en 12.1, donde `CON_ID` no existe.

## 2. 12.1 PDB identity mapping

En 12.1 (`legacy_121_no_con_id`): `container_id: NOT_AVAILABLE` (sin `CON_ID` no hay correlación por contenedor contra `V$PDBS`) — esto no cambia. Lo que sí cambia: `container_name`/`pdb_token` se derivan de `NAME` (sanitizado/tokenizado, `PDB_NNN`), en vez de quedar `null`. `identity_status: NOT_AVAILABLE` refleja la ausencia de `CON_ID` — no la ausencia de identidad, que sí existe vía `NAME`.

## 3. 12.1 CON_ID status

Sin cambios respecto al hardening de compatibilidad anterior — `CON_ID` no existe en 12.1 (verificado, referencia 12.1: 9 columnas sin `con_id`), se agrega en 12.2 (10 columnas). Nunca se selecciona ni se inventa en la variante legacy.

## 4. Modern PDB identity mapping

En 12.2+ (`modern_122plus_con_id`): `CON_ID` y `NAME` se usan de forma complementaria. `con_id` correlaciona contra el inventario ya publicado por `multitenant/pdb-inventory` (`V$PDBS`); `NAME` se usa como segunda señal de verificación. Si ambas no correlacionan, `identity_status: IDENTITY_MISMATCH` — nunca se oculta la inconsistencia asumiendo que una señal es correcta y la otra no.

## 5. Plugin violation output normalization

`skills/multitenant/plugin-violations/SKILL.md` (v3.0.0) normaliza ambas variantes al modelo `plugin_violation` extendido: `container_id`/`container_name`/`pdb_token`/`identity_status`/`time`/`cause`/`type`/`error_number`/`line`/`message`/`status`/`action`/`source_variant`. `Q-CDB-PLUGIN-VIOLATIONS-001.md` (v3.0.0) documenta el modelo por variante en su prosa.

## 6. Plugin violation sanitization

`NAME` puede contener el nombre real de la PDB (ej. `PROD_SALES`) — corregido de `KEEP` (no sensible) a `MASK` (tokenizado `PDB_NNN`, mismo criterio que `Q-CDB-PDB-STATE-001.name`), mapping consistente dentro del mismo análisis. `ACTION`/`MESSAGE` mantienen su protección "siempre DATA, nunca ejecutado" sin cambios — verificado explícitamente que esta corrección no la debilita.

## 7. Shared version library — causa raíz del segundo defecto

El "Query Variant Resolver" del repositorio nunca fue un componente ejecutable único — es un algoritmo documentado (`docs/QUERY_VARIANTS.md`) reimplementado ad-hoc como una función `vernum()` local en ~22 archivos de test distintos, todos 2-tier (major.minor únicamente). El hardening de compatibilidad anterior añadió un `vernum3()` patch-level-aware, pero **sólo** dentro de `tests/test_sql_static_validator.sh` — los tests de resolución de variantes (`test_query_variant_resolver_10g.sh`/`_11g.sh`) y los tests específicos de `Q-CDB-PDB-SAVED-STATE-001` seguían usando comparación 2-tier o un `vernum3()` duplicado independiente. Esto es exactamente el anti-patrón nombrado en este prompt: *"tests PASS, resolver capability missing"* — un test podía declarar cobertura patch-level sin que ninguna implementación real la tuviera fuera de ese único archivo.

**Fix**: `scripts/lib/version.sh` — única fuente de verdad, consumida por `tests/test_sql_static_validator.sh`, `tests/test_query_variant_resolver_{10g,11g}.sh`, `tests/test_pdb_saved_state_1210*.sh` y los nuevos tests de integración de saved-state.

## 8. Version normalization

Modelo de 5-tupla (`major minor update patch revision`), componentes faltantes rellenados con `0` de forma determinista. Alias de marketing preservados exactamente como en `config/query-compatibility-matrix.yaml`/el `case` histórico de `test_sql_static_validator.sh` (10g→10.2, 11g/11gR2→11.0, 12c→12.1, 18c→18.0, 19c→19.0, 21c→21.0, 23ai→23.0). El sentinel `latest` se preserva como techo sin límite conocido (mismo criterio que el `vernum("latest")=99999` original) — usado hoy por ~40 queries `implicit_full_range` de Oracle Core/RAC/ASM/Performance que **no** se tocaron en este hardening.

## 9. Patch-level comparison

Comparación tupla-por-tupla, numérica (no lexicográfica) por componente — `19.3 < 19.27` se resuelve correctamente, a diferencia de una comparación de string ingenua. `12.1.0.1 < 12.1.0.2 < 12.2.0.1` verificado.

## 10. Query Variant Resolver integration

`tests/test_query_variant_resolver_10g.sh`/`_11g.sh` refactorizados: `source scripts/lib/version.sh`, `TARGET` representado como string de versión ("10.2"/"11.2") en vez de un entero mágico (1002/1102), comparación vía `version_in_range`. Mismo resultado PASS/FAIL que antes del refactor — verificado explícitamente, sin regresión.

## 11. Static Validator integration

`tests/test_sql_static_validator.sh` refactorizado: `vernum()` (chequeo 1) y `vernum3()` (chequeo 3) eliminados, reemplazados por `version_gte` de la librería compartida en todos los sitios de comparación.

## 12. Saved-State resolver integration test

3 tests nuevos de integración real (`test_saved_state_resolver_12101_no_match.sh`/`_12102_match.sh`/`_121020_match.sh`) ejercitan `Q-CDB-PDB-SAVED-STATE-001` + `scripts/lib/version.sh` directamente — no un helper simulado. Casos: `12.1.0.1` → NO MATCH; `12.1.0.2`, `12.1.0.2.0`, `12.2.0.1` → MATCH.

## 13. Tests (17 nuevos/refactorizados)

**Identidad PDB (6)**: `test_plugin_violation_121_name_maps_to_pdb_identity.sh`, `test_plugin_violation_121_container_id_not_available.sh`, `test_plugin_violation_121_container_name_from_name.sh`, `test_plugin_violation_modern_con_id_and_name.sh`, `test_plugin_violation_identity_sanitization.sh`, `test_plugin_violation_action_still_treated_as_data.sh`.

**Librería de versión compartida (6)**: `test_version_compare_12101_lt_12102.sh`, `test_version_compare_12102_eq_121020.sh`, `test_version_compare_12102_lt_12201.sh`, `test_version_compare_19c_normalization.sh`, `test_version_compare_23ai_normalization.sh`, `test_unknown_future_version_policy.sh`.

**Integración resolver (5)**: `test_saved_state_resolver_12101_no_match.sh`, `test_saved_state_resolver_12102_match.sh`, `test_saved_state_resolver_121020_match.sh`, `test_query_variant_resolver_uses_shared_version_library.sh`, `test_static_validator_uses_shared_version_library.sh`.

**Refactorizados (sin cambio de comportamiento, sólo de implementación)**: `test_query_variant_resolver_10g.sh`, `test_query_variant_resolver_11g.sh`, `test_pdb_saved_state_12101_not_supported.sh`, `test_pdb_saved_state_12102_supported.sh`.

## 14. Known limitations

- ~~`scripts/lib/version.sh` no se propagó a los ~17 archivos de test de resolución de variantes fuera del alcance directo de este hardening...~~ — **resuelto** en PHASE 6 — VERSION RESOLVER CONSOLIDATION FINALIZATION: los 17 archivos restantes (`test_query_variant_resolver_{12c,18c,19c,21c,23ai}.sh`, `test_dataguard_process_variant_resolution_{11g,121,122,19c,23ai}.sh`, `test_dataguard_{23ai_supported_when_certified,24_or_future_not_auto_supported}.sh`, `test_fixture_query_variant_resolution.sh`, `test_query_variant_ranges_do_not_overlap_invalidly.sh`, `test_version_resolver_{12101,12102}.sh`, `test_plugin_violation_variant_resolution.sh`) fueron migrados a `scripts/lib/version.sh`, con enforcement global (`tests/test_no_local_version_resolvers_in_tests.sh`) que falla si cualquier archivo ejecutable de test vuelve a declarar un comparador local. Ver `docs/PHASE_6_VERSION_RESOLVER_CONSOLIDATION_FINALIZATION.md` para el detalle completo de esa consolidación final.
- `scripts/lib/version.sh` no introduce un componente ejecutable nuevo de runtime — sigue siendo lógica invocada sólo en tiempo de test/validación estática, consistente con que el Gateway MCP real permanece Fase 7.
- El `identity_status: IDENTITY_MISMATCH` de la variante moderna es un contrato de salida documentado (skill/query) — no se puede verificar contra datos reales sin runtime (Fase 7); certificado como `DOCUMENTATION_VALIDATED`, no `RUNTIME_VALIDATED`.

## Referencia

`docs/PHASE_6_QUERY_COMPATIBILITY_HARDENING.md`, `docs/QUERY_VARIANTS.md`, `scripts/lib/version.sh`, `skills/multitenant/plugin-violations/SKILL.md`, `queries/multitenant/Q-CDB-PLUGIN-VIOLATIONS-001.md`.

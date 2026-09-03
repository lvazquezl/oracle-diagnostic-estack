# Phase 2 — Oracle Core Compatibility Hardening

Branch: `phase/2-oracle-core`. Baseline: `v0.1.0-foundation`. Objetivo del baseline resultante: `v0.2.0-oracle-core`.

## Scope

No es una reconstrucción de Fase 2. Es una pasada de endurecimiento dirigida específicamente a corregir y validar la compatibilidad **real** (SQL ejecutable, no sólo metadata declarada) del catálogo de queries certificadas Oracle Core entre Oracle 10g y 23ai, antes de aprobar el baseline `v0.2.0-oracle-core`. Cubre las 28 queries materializadas del catálogo (`queries/oracle/**` + las 3 pre-existentes de Foundation Hardening revisadas por completitud: `Q-RAC-SESSION-DIST-001`, `Q-PERF-WAIT-AWR-001`, `Q-PERF-WAIT-ASH-001`).

## Problem detected

Antes de este hardening, una query certificaba `supported_oracle_versions: [10g...23ai]` como metadata suelta, sin garantía estructural de que su única sentencia SQL fuera válida en todo ese rango. Inspección completa del catálogo (no limitada a los ejemplos del prompt) encontró **7 discrepancias reales metadata↔SQL**, todas corregidas en este hardening:

1. `Q-DISC-IDENTITY-001` usaba `V$INSTANCE.VERSION_FULL` (18.0+) y `V$DATABASE.CDB` (12.1+) en una única sentencia declarada compatible desde 10g.
2. `Q-DISC-RAC-001` usaba `V$ACTIVE_INSTANCES.CON_ID` (12.1+) declarándose compatible desde 11gR2.
3. `Q-ORA-INSTANCE-STATE-001` usaba `V$INSTANCE.INSTANCE_ROLE` (11.0+) declarándose compatible desde 10g.
4. `Q-DBA-TBS-USAGE-001` usaba `DBA_TABLESPACE_USAGE_METRICS` (11.0+, sin vista real en 10g) en una única sentencia declarada compatible desde 10g, además de un bug de formato (dos sentencias en un mismo bloque ```sql```).
5. `Q-DISC-ASM-001` usaba `V$ASM_DISKGROUP` (dispara disk discovery) como `cost_class: LOW` para monitoreo rutinario.
6. `Q-ORA-JOBS-SUMMARY-001` declaraba `DBA_JOBS` en `objects_accessed` sin que su SQL lo consultara realmente (metadata sobre-declarada, no un problema de versión).
7. 7 queries (`Q-ORA-ARCHIVE-001`, `Q-ORA-CONTROLFILE-001`, `Q-ORA-DB-STATE-001`, `Q-ORA-REDO-001`, `Q-ORA-REDO-SWITCH-FREQ-001`, `Q-PERF-WAIT-AWR-001`, `Q-PERF-WAIT-ASH-001`) declaraban `container_scope: CDB_ROOT` — valor exclusivo de Multitenant (12c+) — mientras también declaraban soporte 10g/11g, versiones sin CDB. Encontrado por `tests/test_cdb_query_blocked_on_11g.sh`, un test nuevo de este hardening, no un caso descrito en el prompt original.

## Query variant architecture

Ver `docs/QUERY_VARIANTS.md` (documento nuevo, fuente normativa). Resumen: se separa **logical query** (`query_id`, lo que un skill referencia) de **physical SQL variant** (`variant_id`, una sentencia SQL concreta válida sólo dentro de un rango de versión/arquitectura). Cada logical query con diferencias reales de SQL por versión declara `variants: []` en su frontmatter YAML, con cada variante ancladas a un heading `# Statement / procedure (read-only) — Variant VN (label, rango)` en el mismo archivo Markdown — sin archivos `.sql` sueltos, manteniendo Fuente Única de Verdad por logical query.

5 logical queries requirieron variantes reales: `Q-DISC-IDENTITY-001` (3), `Q-DISC-RAC-001` (2), `Q-ORA-INSTANCE-STATE-001` (2), `Q-DBA-TBS-USAGE-001` (2), `Q-DISC-ASM-001` (2, por costo/propósito no por versión). Las 23 queries restantes verificaron **un único variante implícito** (`implicit_full_range`) — su SQL, validado contra `compatibility/oracle-dictionary/`, no usa ninguna columna/vista fuera de su `supported_oracle_versions` declarado.

## Resolver

Componente lógico documentado en `docs/QUERY_VARIANTS.md#query-variant-resolver` (sin runtime ejecutable — el Gateway MCP real es Fase 7): `Target Profile → oracle_version normalizado + architecture + container + database_role + platform → Logical Query ID → primera variante compatible en orden declarado → Certified SQL`. Nunca "closest version", nunca fallback silencioso — sin match, `status: UNSUPPORTED` con `reason`/`alternative` explícitos. El modelo/Claude nunca elige manualmente el bloque SQL; `agents/oracle-discovery-analyst/AGENT.md` y `agents/oracle-dba-analyst/AGENT.md` referencian únicamente `query_id` lógicos (sección "Evidence policy" de ambos).

Validado por 7 tests dedicados (`tests/test_query_variant_resolver_{10g,11g,12c,18c,19c,21c,23ai}.sh`) que confirman, por versión, qué logical queries resuelven variante y cuáles legítimamente no (ej. `Q-DISC-RAC-001`/`Q-DISC-ASM-001` no cubren 10g — RAC/ASM certificados desde 11g/11gR2), más `test_query_variant_resolver_no_match_returns_unsupported.sh` que confirma el comportamiento de no-match sobre un caso real del catálogo (no teórico).

## Compatibility matrix

`config/query-compatibility-matrix.yaml` (nuevo) — fuente estructurada por logical query: variantes/rango, `required_views`, `role_scope`, `cost_class`, `license_requirements`, `validation_status` (con campo `was:` registrando el estado pre-hardening cuando aplica). Espejo ejecutable de lo declarado en cada `queries/**/Q-*.md`, validado cruzadamente por `tests/test_documented_support_matches_query_variants.sh`.

Capa de conocimiento de esquema Oracle: `compatibility/oracle-dictionary/views.yaml` (nuevo) — sólo vistas/columnas realmente usadas por el catálogo actual (no todo el diccionario Oracle), con `min_version` por vista/columna. Fuente para el SQL Static Validator y para `compatibility_schema` de las 9 fixtures.

## Cost corrections

- `Q-DISC-ASM-001`: separado en variante `routine_stat` (`V$ASM_DISKGROUP_STAT`, `cost_class: LOW`, `default: true`, sin disk discovery) y variante `detailed_diskgroup` (`V$ASM_DISKGROUP`, `cost_class: MEDIUM`, `on_demand_only: true`, nunca default). Regla aplicada: "no usar una vista que dispare disk discovery para monitoreo rutinario si existe una vista stat diseñada para evitarlo".
- Revisión completa de `cost_class` sobre las 28 queries del catálogo (`config/query-compatibility-matrix.yaml`): ninguna `BLOCKED`; `HIGH` reservado a `Q-PERF-WAIT-ASH-001` (ventana × sesiones activas × muestreo 1s); `MEDIUM` en agregaciones/`GV$` cross-instance/ventanas históricas (`Q-ORA-PARAMETERS-RAC-DIFF-001`, `Q-ORA-REDO-SWITCH-FREQ-001`, `Q-RAC-SESSION-DIST-001`, etc.); `LOW` en el resto. Ningún ajuste adicional encontró una discrepancia real más allá de ASM.
- `open_mode_scope` (Query Contract, extensión opcional — `docs/CONTRACTS.md`): documentado y fundamentado con el caso real `Q-DBA-TBS-USAGE-001` sobre un target `MOUNTED` (`DBA_FREE_SPACE` no representativa) — resuelto vía degradación de `confidence: UNDETERMINED` (ver `tests/fixtures/19c-physical-standby.yaml`), no vía bloqueo estructural nuevo por query.

## Specific queries fixed

Ver "Problem detected" arriba para el detalle completo de las 7 discrepancias. Resumen de metadata final:

- **Identity fix**: `Q-DISC-IDENTITY-001` v3.0.0, 3 variantes (`legacy_10g_11g` 10.2–11.2 sin `CDB`/`VERSION_FULL`; `multitenant_12c` 12.1–12.2 con `CDB`; `modern_18plus` 18.0+ con `VERSION_FULL`). Resuelve el bootstrapping problem (V1 es siempre la primera invocación posible, sus columnas son subconjunto estricto de V2/V3).
- **RAC fix**: `Q-DISC-RAC-001` v2.0.0, 2 variantes (`pre_multitenant` 11.2 sin `CON_ID`; `multitenant_aware` 12.1+ con `CON_ID`). Confirmado mínimo real 11gR2, no "11g" genérico.
- **ASM cost fix**: ver "Cost corrections" arriba.
- **Temp compatibility**: `Q-ORA-TEMP-001` (`DBA_TEMP_FILES`/`DBA_TEMP_FREE_SPACE`, ambas `min_version: all` en el dictionary) verificado `implicit_full_range` sin discrepancia — no requería variante. `Q-DBA-TBS-USAGE-001` (tablespaces, relacionada) sí la requería — ver arriba.
- **Other query fixes**: `Q-ORA-JOBS-SUMMARY-001` — `objects_accessed`/`privileges_required` acotados a `DBMS_SCHEDULER`; `DBA_JOBS` documentado explícitamente como gap `PLANNED` (no un SELECT ficticio) tanto en la query como en `skills/oracle/jobs/SKILL.md` v1.1.0 (`capability_status: PARTIALLY_SUPPORTED`). 7 queries `container_scope: CDB_ROOT → ANY_CONTAINER` (ver "Problem detected" #7) — corrección propagada a `queries/REGISTRY.md`.

## Query cost review

Ver "Cost corrections" arriba — revisión completa de las 28 queries, un único ajuste real (`Q-DISC-ASM-001`).

## Container scope validation

Corregidas las 7 queries del punto #7 de "Problem detected". `tests/test_cdb_query_blocked_on_11g.sh` (nuevo) impide la regresión: ninguna query certificada puede declarar `container_scope: CDB_ROOT` junto con soporte 10g/11g. `tests/test_non_cdb_pdb_unsupported.sh` (Foundation Hardening) ajustado: su aserción original ("existe una query materializada con `CDB_ROOT`") quedó invalidada por esta misma corrección — ninguna query Oracle Core es hoy legítimamente root-exclusiva (las candidatas reales, `Q-CDB-PDB-STATE-001`/`Q-CDB-CONTAINERS-001`, son `registered`, no materializadas, fuera de Fase 2). El test ahora valida que `CDB_ROOT` sigue siendo un valor de enum válido en el Query Contract, no que exista un uso concreto.

## Database role validation

Sin cambios de `database_role_scope` — la clasificación PRIMARY/STANDBY/ANY de Foundation Hardening se mantuvo consistente durante la revisión completa del catálogo; ningún caso de `INCORRECT_ROLE_SCOPE` encontrado.

## Open mode validation

Ver "Cost corrections" — campo `open_mode_scope` documentado como extensión opcional del Query Contract (`docs/CONTRACTS.md`), no aplicado como gate obligatorio nuevo por query; el caso real conocido (TEMP/tablespaces sobre standby en mount) ya estaba cubierto por el modelo de Capability Degradation existente (`confidence: UNDETERMINED`).

## Privilege model update

`docs/ORACLE_READONLY_PRIVILEGES.md` — nueva sección "Query variant → privilege mapping": tabla explícita `logical query / variant / rango / objetos` para las 5 queries con variantes reales, con nota de mínimo privilegio para `Q-DISC-ASM-001-V2` (`V$ASM_DISKGROUP`, sólo otorgar si el target ejecutará diagnóstico ASM profundo bajo demanda).

## Capability matrix update

`config/capability-matrix.yaml`: fila `oracle-core` permanece `SUPPORTED` 10g–23ai — validado ahora contra el Query Variant Resolver, no sólo declarado. Nota extendida documentando el gap `DBA_JOBS`/legacy `DBMS_JOB` (`PLANNED`, no bloqueante para el resto de Oracle Core) y referenciando este documento como evidencia de validación.

## Skill support alignment

`skills/oracle/jobs/SKILL.md` v1.1.0 — alcance acotado a `DBMS_SCHEDULER`, `DBA_JOBS` legacy documentado `PARTIALLY_SUPPORTED`/`PLANNED`. `tests/test_documented_support_matches_query_variants.sh` (nuevo) valida cruzadamente que ningún `SKILL.md`/`manifest.yaml` declare soporte de versión que el catálogo de variantes no respalde — 2 skills verificados (`instance`, `tablespaces`), ambos consistentes.

## MCP certification model

`mcp/tool-manifest.md` — nueva sección "MCP Query Certification": una tool sólo se expone `CERTIFIED` para un target cuando el Resolver encuentra variante `SUPPORTED` para ese target específico (evaluado por target, no globalmente); nunca `NOT_CERTIFIED`/`PARTIAL sin variant compatible`/`UNKNOWN`. Documenta la regla que el Gateway MCP real (Fase 7) debe implementar — sin runtime activo hoy.

## Documentation updated

Creados: `docs/QUERY_VARIANTS.md`, `compatibility/oracle-dictionary/views.yaml`, `config/query-compatibility-matrix.yaml`, este documento. Actualizados (sólo donde aplicó): `docs/PHASE_2_ORACLE_CORE.md` (nota de referencia cruzada), `docs/CONTRACTS.md` (campo `open_mode_scope`), `docs/ORACLE_READONLY_PRIVILEGES.md`, `EVOLUTION.md` (checklist `/change compatibility` extendido), `mcp/tool-manifest.md`, `queries/REGISTRY.md`, `config/capability-matrix.yaml`. `CHANGELOG.md` actualizado con una entrada nueva (ver sección correspondiente). `ARCHITECTURE.md` — sin cambios; el modelo de Query Variants es una extensión del Query Contract v2 existente, no un cambio arquitectónico de componentes. `CLAUDE.md` — sin cambios, se mantiene compacto.

## Tests

28 tests nuevos (`tests/test_sql_static_validator.sh`, `test_every_logical_query_has_variant.sh`, `test_every_variant_has_version_range.sh`, `test_every_variant_has_sql_file.sh`, `test_every_variant_has_supported_dictionary_objects.sh`, `test_no_variant_references_unknown_column.sh`, `test_no_variant_references_unknown_view.sh`, `test_query_variant_ranges_do_not_overlap_invalidly.sh`, 7× `test_query_variant_resolver_<version>.sh`, `test_query_variant_resolver_no_match_returns_unsupported.sh`, `test_identity_10g_does_not_use_version_full.sh`, `test_identity_11g_does_not_use_cdb.sh`, `test_identity_12c_supports_cdb.sh`, `test_identity_18plus_uses_modern_variant.sh`, `test_rac_11g_does_not_use_con_id.sh`, `test_rac_12cplus_can_use_con_id.sh`, `test_asm_monitoring_does_not_use_diskgroup_discovery_view.sh`, `test_temp_query_10g_uses_supported_variant.sh`, `test_cdb_query_blocked_on_11g.sh`, `test_pdb_query_blocked_on_non_cdb.sh`, `test_documented_support_matches_query_variants.sh`, `test_fixture_query_variant_resolution.sh`). Todos siguen la convención existente (bash standalone, `[PASS]`/`[FAIL]`, sin librería compartida).

## Limitations

- El Query Variant Resolver está documentado y probado estáticamente (7 tests por versión + fixture-consistency), pero **no tiene runtime ejecutable** — es lógica que el agente aplica al preparar un Task Package; la automatización real en el Gateway MCP es Fase 7, sin cambios de alcance en este hardening.
- `DBA_HIST_SYSTEM_EVENT.TIME_WAITED_MICRO_FG` (columna foreground, introducida en 11g) no está en `RISKY_COLUMNS` del SQL Static Validator (`tests/test_sql_static_validator.sh`) — gap conocido y documentado en `compatibility/oracle-dictionary/views.yaml`, no corregido en este pase porque `Q-PERF-WAIT-AWR-001` es una query pre-existente de Foundation Hardening fuera del foco central de este hardening (revisada "por completitud"); no bloquea el tag porque no se declaró `SUPPORTED` sobre una versión donde falle — sigue siendo un candidato válido para un `/change query` futuro.
- La disponibilidad real de `DBA_HIST_*`/AWR consultado desde dentro de una PDB específica (vs. `CDB$ROOT`) varía por release de Oracle Multitenant y no se afirma con certeza en este documento — `Q-PERF-WAIT-AWR-001`/`Q-PERF-WAIT-ASH-001` declaran `ANY_CONTAINER` con una nota explícita exigiendo degradación a `capability_status: UNDETERMINED` si el target resuelve a una PDB y la query no retorna filas, en vez de asumir compatibilidad sin evidencia (sección 34 del prompt de hardening).
- `test_query_compatibility_container_scope.sh` (Foundation Hardening, pre-existente) tiene un bug de test no relacionado con este hardening: su rama "query no materializada" imprime `[FAIL]` pero no fija `FAIL=1`, por lo que el test sale en verde (exit 0) sin fallar realmente cuando `Q-CDB-PDB-STATE-001`/`Q-CDB-CONTAINERS-001` no existen. No corregido en este pase (fuera del inventario de queries Oracle Core); recomendado como `/change` de calidad de tests independiente.
- `open_mode_scope` se documentó como extensión del Query Contract pero no se populó explícitamente como campo YAML en ninguna query — el único caso real conocido ya está cubierto por el modelo de Capability Degradation existente.
- Fixture hardening (`compatibility_schema.available_views`/`available_columns`) cubre las columnas version-gated conocidas (`version_full`, `cdb`, `con_id`, `instance_role`, `time_waited_micro_fg`) — no reconstruye el 100% del dictionary por fixture, consistente con el principio "no modelar todo el diccionario Oracle".

## Final query catalog validation

Estados: `SUPPORTED` (Resolver encuentra variante) · `PARTIAL` (parcialmente cubierta — ver nota) · `UNSUPPORTED` (feature no existe en esa versión, no es límite del e-stack) · `NOT_APPLICABLE`.

| Logical Query | Variants | 10g | 11g | 12c | 18c | 19c | 21c | 23ai | Cost | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| Q-DISC-IDENTITY-001 | 3 | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | LOW | CERTIFIED |
| Q-DISC-RAC-001 | 2 | UNSUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | LOW | CERTIFIED |
| Q-ORA-INSTANCE-STATE-001 | 2 | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | LOW | CERTIFIED |
| Q-DBA-TBS-USAGE-001 | 2 | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | LOW | CERTIFIED |
| Q-DISC-ASM-001 | 2 (por costo) | UNSUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | LOW (default) / MEDIUM (on-demand) | CERTIFIED |
| Q-DISC-INSTANCE-001 | implicit | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | LOW | CERTIFIED |
| Q-ORA-DB-STATE-001 | implicit | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | LOW | CERTIFIED |
| Q-ORA-PARAMETERS-001 | implicit | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | LOW | CERTIFIED |
| Q-ORA-PARAMETERS-RAC-DIFF-001 | implicit | SUPPORTED* | SUPPORTED* | SUPPORTED* | SUPPORTED* | SUPPORTED* | SUPPORTED* | SUPPORTED* | MEDIUM | CERTIFIED |
| Q-ORA-SPFILE-001 | implicit | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | LOW | CERTIFIED |
| Q-ORA-CONTROLFILE-001 | implicit | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | LOW | CERTIFIED |
| Q-ORA-REDO-001 | implicit | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | LOW | CERTIFIED |
| Q-ORA-REDO-SWITCH-FREQ-001 | implicit | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | MEDIUM | CERTIFIED |
| Q-ORA-ARCHIVE-001 | implicit | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | LOW | CERTIFIED |
| Q-DBA-TBS-DATAFILES-001 | implicit | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | MEDIUM | CERTIFIED |
| Q-ORA-TEMP-001 | implicit | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | LOW | CERTIFIED |
| Q-ORA-UNDO-001 | implicit | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | LOW | CERTIFIED |
| Q-ORA-SESSIONS-SUMMARY-001 | implicit | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | MEDIUM | CERTIFIED |
| Q-ORA-PROCESSES-SUMMARY-001 | implicit | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | LOW | CERTIFIED |
| Q-ORA-JOBS-SUMMARY-001 | implicit | PARTIAL** | PARTIAL** | PARTIAL** | PARTIAL** | PARTIAL** | PARTIAL** | PARTIAL** | MEDIUM | CERTIFIED |
| Q-ORA-OBJECTS-INVENTORY-001 | implicit | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | MEDIUM | CERTIFIED |
| Q-ORA-INVALID-OBJECTS-001 | implicit | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | LOW | CERTIFIED |
| Q-ORA-COMPONENTS-001 | implicit | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | LOW | CERTIFIED |
| Q-ORA-RESOURCE-LIMITS-001 | implicit | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | LOW | CERTIFIED |
| Q-ORA-DIAGNOSTICS-ADR-001 | implicit | UNSUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | LOW | CERTIFIED |
| Q-ORA-DIAGNOSTICS-ALERTLOG-001 | implicit | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | MEDIUM | CERTIFIED |
| Q-RAC-SESSION-DIST-001 | implicit | UNSUPPORTED | SUPPORTED (11gR2) | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | MEDIUM | CERTIFIED |
| Q-PERF-WAIT-AWR-001 | implicit | SUPPORTED*** | SUPPORTED*** | SUPPORTED*** | SUPPORTED*** | SUPPORTED*** | SUPPORTED*** | SUPPORTED*** | MEDIUM | CERTIFIED |
| Q-PERF-WAIT-ASH-001 | implicit | SUPPORTED*** | SUPPORTED*** | SUPPORTED*** | SUPPORTED*** | SUPPORTED*** | SUPPORTED*** | SUPPORTED*** | HIGH | CERTIFIED |

\* RAC-only (arquitectura, no versión) — `NOT_APPLICABLE` sobre Standalone, `SUPPORTED` sobre RAC en toda versión declarada.
\** `DBMS_SCHEDULER` (`DBA_SCHEDULER_JOBS`) `SUPPORTED` en toda versión; legacy `DBMS_JOB` (`DBA_JOBS`) `PLANNED`, no cubierto — ver `skills/oracle/jobs/SKILL.md`.
\*** Requiere Diagnostics Pack (`LICENSE_DEPENDENT`, no es un gate de versión) — ver `policies/licensing-awareness-policy.md`. `ANY_CONTAINER` con degradación a `UNDETERMINED` si se resuelve sobre una PDB específica sin datos — ver "Limitations".

28/28 logical queries `CERTIFIED` (ninguna `NOT_CERTIFIED`) bajo el Quality Gate de `docs/QUERY_VARIANTS.md#quality-gate-por-logical-query` — metadata, variant coverage, version/view/column/container/role compatibility, cost classification, seguridad, privilege mapping y tests, todos `PASS` por logical query tras las correcciones de este hardening.

## Future compatibility process

Reforzado en `EVOLUTION.md#change-compatibility--checklist-obligatorio-oracle-core-compatibility-hardening`: toda versión Oracle nueva (o ajuste de rango) exige, en el mismo cambio, dictionary delta + query variants + compatibility matrix + fixture + test de Resolver por versión + alineación de skills + docs — antes de marcar `SUPPORTED`/`COMPATIBLE`. `docs/QUERY_VARIANTS.md#future-proof-version-policy` define `known_supported`/`known_unsupported`/`unknown_future` y establece que `latest` nunca se resuelve como alias permanente de la versión mayor actual (23ai) — una versión Oracle futura entra en `unknown_future` hasta integrarse explícitamente.

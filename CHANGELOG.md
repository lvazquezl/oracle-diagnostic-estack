# CHANGELOG

Versionado semántico del e-stack. Cambios por artefacto individual (agente/skill/query/workflow/policy) se versionan por separado según `EVOLUTION.md`; este changelog cubre el repositorio en su conjunto.

## [0.1.0] — 2026-09-02 — Fase 1: Foundation

### Added

- Arquitectura, planos del sistema y decisiones de diseño (`ARCHITECTURE.md`).
- Modelo de seguridad, amenazas y controles (`SECURITY.md`).
- Modelo de evolución gobernada `/change` (`EVOLUTION.md`).
- Modelo de distribución y bootstrap (`DISTRIBUTION.md`).
- Agent Contract, Skill Contract, Workflow Contract y Query Contract definitivos (`docs/CONTRACTS.md`).
- Registro completo de 18 agentes obligatorios con manifests conforme al Agent Contract (`agents/`).
- Registro completo del catálogo de skills por dominio (`skills/REGISTRY.md`) con materialización representativa por dominio.
- Catálogo certificado inicial de queries/tools semánticas read-only, extendido más allá de las 14 nombradas explícitamente para cubrir RMAN/backup, security posture y capacity trending (`queries/`).
- Diseño del MCP Diagnostic Gateway local y su tool manifest (`mcp/`).
- Política de sanitización y minimización de datos (`sanitizers/`).
- Políticas de seguridad, identidad, operaciones prohibidas, rate limiting, licensing y retención de evidencia (`policies/`).
- Modelo de evidencia (`raw/sanitized/derived`) y de análisis (`analysis/ANA-*`) con trazabilidad EVD→FND→REC→CHG.
- Modelo de documentación Markdown-first con entregables binarios bajo demanda (`docs/CONTRACTS.md`, `templates/`).
- 13 slash commands implementados en `.claude/commands/`, cada uno resolviendo a un Workflow Contract en `workflows/`.
- Taxonomía inicial de `knowledge/errors/` (ORA/TNS/RMAN/CRS) con entradas representativas validadas.
- Suite de tests de Fase 1: prohibición de escritura, prohibición de shell arbitrario, bloqueo de application data, detección de secretos, trazabilidad de evidencia, activación mínima de agentes, tests adversariales/prompt-injection (`tests/`).
- Scripts de bootstrap de estación de trabajo (`scripts/`).

### Known limitations

Ver reporte de cierre de Fase 1. En resumen: el Gateway MCP, los collectors y los generadores de documentos binarios son contratos/diseño, no runtime ejecutable; eso corresponde a Fases 2–9.

## [0.1.0-foundation] — 2026-09-02 — Foundation Hardening

Pass de endurecimiento sobre el mismo baseline de Fase 1 (no avanza a Fase 2). Ver reporte de cierre "FOUNDATION HARDENING RESULT".

### Added

- **Query Contract v2** (`docs/CONTRACTS.md`, `queries/_QUERY_CONTRACT_TEMPLATE.md`): `container_scope`, `database_role_scope`, `risk_class` (separado de `cost_class`), `cost_class`, `max_output_bytes`, `sanitization_required`, `license_requirements`, `execution_mode: READ_ONLY`.
- `policies/query-cost-policy.md` — clasificación LOW/MEDIUM/HIGH/BLOCKED, distinta de `risk_class`.
- `policies/capability-degradation-policy.md` — modelo formal de 8 estados (`SUPPORTED…ENVIRONMENT_UNKNOWN`) con `reason/impact/alternative/required_action`.
- `policies/version-awareness-policy.md` — representación normalizada de versión (`major/minor/release/ru/raw`) y degradación explícita por versión/arquitectura.
- `docs/CAPABILITY_MATRIX.md` + `config/capability-matrix.yaml` — cobertura por 17 dominios × 8 versiones Oracle.
- `skills/core/version-awareness.md` — materializado (`registered → active`).
- Bloque `gates:` (version/architecture/environment/license/privilege/security/cost/evidence) en el Workflow Contract y en los 13 workflows activos.
- Pipeline `DISCOVERY → CAPABILITY FILTER → AGENT FILTER → SKILL FILTER → CONTEXT PACKAGE` y métricas `agents_skipped_by_capability`/`skills_skipped_by_version`/`skills_skipped_by_license`/`queries_skipped_by_cost`/`tokens_avoided` en `docs/CONTRACTS.md` y `agents/oracle-operations-orchestrator.md`.
- 28 tests nuevos (IDs canónicos, Query Contract v2, cost class, los 8 estados de capability, gates de version/license/workflow, schema y consistencia de la Capability Matrix) — ver `tests/README.md`.

### Changed (breaking)

- **`skill_id` es siempre domain-qualified** (`dominio/skill`). `skills/REGISTRY.md` reescrito con `skill_id` explícito por fila; nombres cortos (`temp`, `undo`, `sga`, `pga`, `services`, `memory`, `io`) dejan de ser identificadores válidos — sólo `display_name`.
- `agents/os-platform-analyst.md` — `Allowed skills` corregido de `os/<skill>` a `os/<platform>/<skill>` para coincidir con el `skill_id` canónico real.
- `queries/REGISTRY.md`, `queries/_QUERY_CONTRACT_TEMPLATE.md` y las 3 queries materializadas migradas a Query Contract v2 (`objects_queried` → `objects_accessed`, `versions` → `supported_oracle_versions`, `platform` → `supported_os`, `architecture` → `supported_architectures`, `risk` → `risk_class` + `cost_class` nuevo).
- `policies/rate-limiting-policy.md` — la clasificación de costo se movió a `policies/query-cost-policy.md`; esta política mantiene sólo los límites por defecto.
- `policies/licensing-awareness-policy.md` — agregada la secuencia de gate explícita y el estado formal `LICENSE_RESTRICTED`.
- `EVOLUTION.md` — nueva sección 13 (`/change compatibility` — validaciones obligatorias); `GAP ANALYSIS`/`IMPACT ANALYSIS`/`TEST` amplían su alcance.
- `tests/test_application_data_blocked.sh`, `tests/test_version_awareness.sh`, `tests/test_query_limits.sh` actualizados a los nuevos nombres de campo.

### Known limitations

Las mismas de Fase 1 (Gateway MCP/collectors/generadores de documentos son contrato, no runtime). Adicional: `test_no_ambiguous_skill_references.sh` es una heurística de grep sobre backticks, no un parser real de Markdown — puede tener falsos negativos ante formatos de referencia no anticipados; se refuerza en Fase 2+ si aparecen casos reales.

## [Unreleased] — 2026-09-03 — Oracle Core Compatibility Hardening

Pasada de endurecimiento sobre `v0.2.0-oracle-core` (branch `phase/2-oracle-core`), previa a aprobar ese baseline — NO una reconstrucción de Fase 2. Ver `docs/PHASE_2_COMPATIBILITY_HARDENING.md` para el reporte de cierre completo.

### Added

- **Query Variant model** (`docs/QUERY_VARIANTS.md`) — separa logical query de physical SQL variant; Query Variant Resolver documentado (Target Profile → variante compatible → SQL certificado); nunca "closest version", nunca fallback silencioso.
- `compatibility/oracle-dictionary/views.yaml` — capa mínima de disponibilidad de vistas/columnas por versión Oracle, usada por el SQL Static Validator.
- `config/query-compatibility-matrix.yaml` — fuente estructurada por logical query (variantes, rango, vistas requeridas, `validation_status`).
- 28 tests nuevos: SQL Static Validator, contrato de variantes (7), Resolver por versión (7 + no-match), regresión específica Identity/RAC/ASM/TEMP/CDB/PDB (10), documentación-vs-realidad, fixture-resolution.
- `compatibility_schema` (`available_views`/`available_columns`) en las 9 fixtures existentes.

### Changed

- `Q-DISC-IDENTITY-001` (v3.0.0), `Q-DISC-RAC-001` (v2.0.0), `Q-ORA-INSTANCE-STATE-001` (v2.0.0), `Q-DBA-TBS-USAGE-001` (v2.0.0) — divididas en variantes reales; ya no declaran soporte de versión sin SQL validado para ese rango.
- `Q-DISC-ASM-001` (v2.0.0) — variante `routine_stat` (`V$ASM_DISKGROUP_STAT`, `cost_class: LOW`, default) separada de `detailed_diskgroup` (`V$ASM_DISKGROUP`, `cost_class: MEDIUM`, on-demand only).
- `Q-ORA-JOBS-SUMMARY-001` + `skills/oracle/jobs/SKILL.md` (v1.1.0) — alcance acotado a `DBMS_SCHEDULER`; gap `DBA_JOBS` legacy documentado `PARTIALLY_SUPPORTED`/`PLANNED`, no un SELECT ficticio.
- `Q-ORA-ARCHIVE-001`, `Q-ORA-CONTROLFILE-001`, `Q-ORA-DB-STATE-001`, `Q-ORA-REDO-001`, `Q-ORA-REDO-SWITCH-FREQ-001`, `Q-PERF-WAIT-AWR-001`, `Q-PERF-WAIT-ASH-001` — `container_scope: CDB_ROOT → ANY_CONTAINER` (CDB_ROOT es exclusivo de Multitenant 12c+, inválido junto a soporte 10g/11g declarado); propagado a `queries/REGISTRY.md`.
- `docs/CONTRACTS.md` — campo opcional `open_mode_scope` en el Query Contract.
- `docs/ORACLE_READONLY_PRIVILEGES.md` — mapping `query_variant → required object privilege`.
- `mcp/tool-manifest.md` — sección "MCP Query Certification" (sólo `CERTIFIED` por target, nunca `NOT_CERTIFIED`/`PARTIAL sin variant`/`UNKNOWN`).
- `EVOLUTION.md` — checklist obligatorio de `/change compatibility` extendido (dictionary delta + variants + matrix + fixtures + tests + skills + docs).
- `config/capability-matrix.yaml` — nota de `oracle-core` extendida (validación real vía Resolver, gap `DBA_JOBS` documentado).

### Fixed

- `tests/test_non_cdb_pdb_unsupported.sh` (Foundation Hardening) — su aserción de que existe una query materializada `container_scope: CDB_ROOT` quedó invalidada por la corrección de arriba; ajustada para validar la existencia del valor de enum en el contrato, no un uso concreto.
- 6 tests de extracción de bloque SQL por variante (`test_identity_*`/`test_rac_*`) tenían un bug de coincidencia de patrón `awk` que capturaba el bloque de metadata del frontmatter en vez del heading real del body.

## [0.2.0-oracle-core] — 2026-09-03 — Fase 2: Oracle Core

Primera capa funcional Oracle del e-stack, sobre baseline `v0.1.0-foundation`. Ver `docs/PHASE_2_ORACLE_CORE.md` para el reporte de cierre completo.

### Added

- **Target Profile** (`docs/TARGET_PROFILE.md`) — schema estructurado de identidad de ambiente (versión normalizada, arquitectura, rol, container, capabilities), publicado una vez por análisis y reutilizado por todo el pipeline.
- `agents/oracle-discovery-analyst/AGENT.md` (`v2.0.0`) — Discovery Sequence de 11 pasos, detección por dimensión, Discovery Cache diferenciado por volatilidad.
- `agents/oracle-dba-analyst/AGENT.md` (`v2.0.0`) — 18 áreas Oracle Core, DBA Command Generation formalizado.
- 18 skills `oracle/*` completamente materializadas (`SKILL.md` + `manifest.yaml`), reemplazando el único ejemplo representativo de Fase 1.
- ~20 queries nuevas `Q-ORA-*` (Query Contract v2) bajo `queries/oracle/<categoría>/`, más 3 queries de discovery/tablespaces previamente sólo-registro ahora materializadas.
- `policies/discovery-cache-policy.md` — TTL diferenciado por volatilidad de campo.
- `docs/ORACLE_READONLY_PRIVILEGES.md` — propuesta de `ESTACK_DIAGNOSTIC_ROLE` para Oracle Core (revisión humana, nunca ejecutado).
- 9 fixtures (`tests/fixtures/*.yaml`) para 10g/11g/12c/19c/21c/23ai × standalone/RAC/CDB/standby.
- 40 tests nuevos: 7 de detección por versión, 18 de skill Oracle Core, 12 de seguridad, 3 de compatibilidad de query.
- 15 nuevas tools MCP semánticas en `mcp/tool-manifest.md` (`get_database_state`, `get_controlfile_metadata`, etc.).

### Changed

- `agents/oracle-discovery-analyst.md` y `agents/oracle-dba-analyst.md` → reestructurados a `agents/<id>/AGENT.md` (extensión aditiva; el resto de agentes permanece plano).
- `skills/oracle/tablespaces.md` → `skills/oracle/tablespaces/SKILL.md` + `manifest.yaml`, extendido de v1.0.0 a v2.0.0.
- `config/capability-matrix.yaml` / `docs/CAPABILITY_MATRIX.md`: fila `oracle-core` de `PARTIAL` a `SUPPORTED` en las 8 columnas de versión.
- `workflows/healthcheck.md` → `v2.0.0`, cobertura ampliada a las 18 áreas Oracle Core.
- `skills/core/context-discovery.md` → `v1.1.0`, nota de supersesión de nomenclatura por el Target Profile (sin romper Foundation).
- Tests de Foundation/Hardening que escaneaban `queries/*.md` de forma plana actualizados para recorrer `queries/oracle/**` recursivamente.

### Known limitations

Ver `docs/PHASE_2_ORACLE_CORE.md#known-limitations`. En resumen: Gateway MCP/collectors/generadores de documentos siguen siendo contrato, no runtime; multi-PDB individual no iterado automáticamente; RAC One Node no confirmable sin query adicional; tests estáticos/basados en fixtures, no contra ambiente real.

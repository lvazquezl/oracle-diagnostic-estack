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

# Phase 2 — Oracle Core

Baseline: `v0.1.0-foundation`. Esta fase implementa la primera capa funcional Oracle del e-stack, sobre el mismo baseline arquitectónico de Foundation/Foundation Hardening — sin reconstruirlo.

## Scope

**En profundidad:** `oracle-discovery-analyst`, `oracle-dba-analyst`, las 18 skills `oracle/*` (Oracle Core), el catálogo certificado de ~24 queries (`Q-DISC-*`, `Q-DBA-TBS-*`, `Q-ORA-*`), el Target Profile (`docs/TARGET_PROFILE.md`), y los workflows `/healthcheck`, `/assessment`, `/diagnose` a nivel Oracle Core.

**Detectado, no profundizado:** RAC, ASM, Data Guard role, CDB/PDB — el Target Profile los detecta (`capabilities.*`) para permitir routing futuro, pero `oracle-performance-analyst`, `oracle-rac-analyst`, `oracle-asm-storage-analyst`, `oracle-dataguard-analyst`, `oracle-multitenant-analyst`, `oracle-backup-recovery-analyst` no se profundizan en esta fase (siguen en `v1.0.0`, contrato Foundation).

**Explícitamente fuera de alcance:** AWR/ASH/ADDM/SQL tuning profundo, RAC internals/Cache Fusion, ASM internals, Data Guard internals, RMAN internals, OS profundo, MCP productivo, conexiones PROD, DOCX/XLSX/PDF/PPTX, auto-remediation, SQL/shell arbitrario.

## Architecture

Sin cambios a Foundation. Dos extensiones estructurales, ambas aditivas:

1. **Agentes profundizados viven en carpeta**: `agents/oracle-discovery-analyst/AGENT.md`, `agents/oracle-dba-analyst/AGENT.md` (resto de agentes permanece `agents/<id>.md` plano).
2. **Skills Oracle Core con `SKILL.md` + `manifest.yaml`**: `skills/oracle/<skill>/{SKILL.md,manifest.yaml}` para las 18 áreas.

Nuevo contrato: **Target Profile** (`docs/TARGET_PROFILE.md`) — schema estructurado publicado por discovery y consumido por todo el resto del pipeline, evolución (no reemplazo) del Result Package genérico de Foundation.

## Agents implemented

- `oracle-discovery-analyst` (`v2.0.0`) — Discovery Sequence de 11 pasos, detección por dimensión (version/architecture/container/role/instance/RAC/ASM/capability), Discovery Cache con TTL diferenciado.
- `oracle-dba-analyst` (`v2.0.0`) — las 18 áreas Oracle Core, DBA Command Generation formalizado (`NOT_EXECUTED`/`HUMAN_REVIEW_REQUIRED`).

## Skills implemented

18/18 `oracle/*` — ver `skills/REGISTRY.md#oracle-18--completo-desde-fase-2-oracle-core`. Cada uno con las 30 secciones de documentación requeridas (Purpose → Change history), decision tree explícito, patrones normal/anormal/root-cause/falsos-positivos, consideraciones RAC/multitenant/standby, DBA command generation.

## Skills remaining planned

Todo lo demás del catálogo Foundation (`skills/REGISTRY.md`) permanece `registered`, a materializar en Fases 3–9 según `README.md#fases-de-construcción`: `performance/*` (Fase 3), `rac/*`/`asm/*` (Fase 4), `multitenant/*`/`dataguard/*`/`rman/*` (Fase 5), `os/*` (Fase 6), etc.

## Query catalog

24 queries certificadas Query Contract v2 bajo `queries/oracle/` (4 discovery relocalizadas sin duplicar + 2 tablespaces materializadas + ~20 nuevas `Q-ORA-*`). Ver `queries/REGISTRY.md#oracle-core-queries-fase-2`. Todas `execution_mode: READ_ONLY`, `risk_class: R0`; `cost_class` favorece `LOW` (17/20), `MEDIUM` donde necesario (3/20 nuevas: `Q-ORA-PARAMETERS-RAC-DIFF-001`, `Q-ORA-JOBS-SUMMARY-001`, `Q-ORA-OBJECTS-INVENTORY-001`, más `Q-ORA-REDO-SWITCH-FREQ-001` y `Q-ORA-DIAGNOSTICS-ALERTLOG-001`), ninguna `HIGH` en el catálogo Oracle Core nuevo (`HIGH` sólo preexistía en `Q-PERF-WAIT-ASH-001` de Foundation Hardening).

## Query Contract validation

Las 24 queries del catálogo Oracle Core cumplen el schema completo (`container_scope`, `database_role_scope`, `risk_class`+`cost_class`, `max_output_bytes`, `sanitization_required`, `license_requirements: none`, `execution_mode: READ_ONLY`) — validado por `tests/test_query_contract_requires_*.sh` y los 4 tests de `test_query_cost_*.sh`, todos ejecutados sobre el catálogo completo (incluye Foundation + Hardening + Fase 2).

> **Nota (Oracle Core Compatibility Hardening)**: cumplir el schema de metadata no garantiza por sí solo que el SQL certificado sea ejecutable en todo el rango de versión declarado — ver `docs/PHASE_2_COMPATIBILITY_HARDENING.md` para el modelo de Query Variants/Resolver que cierra esa brecha y la corrección de 6 discrepancias metadata/SQL reales encontradas post-Fase 2.

## Supported Oracle versions

10g, 11g, 12c, 18c, 19c, 21c, 23ai, `latest` — todas `SUPPORTED` para Oracle Core (`config/capability-matrix.yaml`). `oracle/diagnostics` (ADR) degrada a `UNSUPPORTED` en 10g (sin ADR); el resto de las 17 áreas aplica igual en las 7 versiones.

## Supported architectures

Standalone/RAC, NON-CDB/CDB/PDB, ASM/Filesystem, Primary/Physical Standby/Logical Standby/Snapshot Standby (los dos últimos detectables, no profundizados).

## Target Profile

`docs/TARGET_PROFILE.md` — schema fijo con 12 secciones (`database`, `oracle_version` normalizado, `architecture`, `database_role`/`open_mode`/`log_mode`/`force_logging`, `instance`, `cluster`, `container`, `platform`, `capabilities`, `discovery` metadata). Publicado una vez por análisis, reutilizado por todo el pipeline vía `policies/discovery-cache-policy.md`.

## Discovery model

Discovery Sequence de 11 pasos fija (`agents/oracle-discovery-analyst/AGENT.md#discovery-sequence`): connection validation → version → architecture → container → role → instance → RAC → ASM → capability → assembly → publish. Normalización de versión como tupla `{major, minor, release, ru, raw}` — nunca comparación de strings (`policies/version-awareness-policy.md`).

## Capability Matrix update

`config/capability-matrix.yaml` / `docs/CAPABILITY_MATRIX.md`: fila `oracle-core` pasa de `PARTIAL` a `SUPPORTED` en las 8 columnas. Filas `rac`/`asm`/`multitenant`/`dataguard` (deep diagnostics) **sin cambio** — se documenta explícitamente la distinción "detection" (ahora `SUPPORTED` vía Target Profile) vs. "deep diagnostics" (sigue `PARTIAL`/`PLANNED`, fases futuras), siguiendo el ejemplo de la sección 41 del prompt de Fase 2.

## Oracle read-only privilege model

`docs/ORACLE_READONLY_PRIVILEGES.md` — ~30 `GRANT SELECT` explícitos e individuales sobre vistas específicas, propuesta para revisión humana, nunca ejecutados por el e-stack. `SELECT_CATALOG_ROLE`/vistas diagnósticas propias documentadas como alternativas, no como default. Nunca `SELECT ANY TABLE`/`DBA`/`SYSDBA`/`SYSOPER`/`SYSASM`.

## Workflows implemented

`/healthcheck` (`v2.0.0`) extendido a las 18 áreas Oracle Core. `/assessment`, `/diagnose`, `/analyze`, `/awr` heredan la cobertura ampliada vía `oracle-dba-analyst` sin requerir cambio de contrato propio (activación mínima sin cambios).

## Evidence model

Sin cambios de schema respecto a Foundation (`docs/CONTRACTS.md#evidence-model`) — las nuevas queries producen `EVD-*` con la misma estructura. `oracle/diagnostics` es la única área con `sensitivity: HIGH` (contenido de alert log), sanitización reforzada.

## Sanitization

Sin cambios de política — `sanitizers/data-classification-policy.md` aplica igual; `Q-ORA-DIAGNOSTICS-ALERTLOG-001` es el caso de mayor sensibilidad nuevo (`DROP` de cualquier patrón de secreto detectado antes de construir el `EVD-*`).

## Context/token model

Sin cambios de contrato — `constraints.area_scope` en el Task Package de `oracle-dba-analyst` permite acotar a un subconjunto de las 18 áreas (usado por `/analyze`), reduciendo el presupuesto por invocación.

## Documentation generated

`docs/TARGET_PROFILE.md`, `docs/ORACLE_READONLY_PRIVILEGES.md`, `docs/PHASE_2_ORACLE_CORE.md` (este documento), `policies/discovery-cache-policy.md`. `README.md`/`ARCHITECTURE.md`/`CHANGELOG.md` actualizados donde correspondía; `CLAUDE.md` sin cambios (se mantiene compacto, Fase 2 no altera routing/principios base).

## Skill Quality Gate

Las 18 skills Oracle Core pasan las 13 dimensiones (Contract, Documentation, Evidence Model, Decision Logic, Version Awareness, Architecture Awareness, Security, Queries, Tests, Token/Context Policy, Related Skills, Examples, Change History) — validado por `tests/test_oracle_core_<skill>.sh` (18 tests) más la suite general de Foundation/Hardening.

## Agent Quality Gate

`oracle-discovery-analyst`/`oracle-dba-analyst` pasan las 10 dimensiones (Agent Contract, Documentation, Routing, Allowed skills, Forbidden operations, Context policy, Evidence policy, Output schema, Collaboration, Security) — validado por la suite general más los tests de detección por versión/arquitectura.

## Security validation

Ninguna query Oracle Core contiene DML/DDL/PL·SQL con side effects; ninguna toca tablas de aplicación, bind values, o password hashes; ninguna tool MCP acepta parámetro de texto libre; todas respetan `container_scope`/`database_role_scope`/`cost_class`/license gate — validado por 12 tests de seguridad dedicados (`tests/test_no_oracle_core_*.sh`, `tests/test_oracle_core_respects_*.sh`, etc.), todos en verde.

## Test results

**86/86 tests pasaron** (`bash tests/run-all.sh`): 46 de Fase 1 + Foundation Hardening (sin regresión) + 40 nuevos de Fase 2 (7 de versión, 18 de skill, 12 de seguridad, 3 de compatibilidad de query).

## Regression results

Los 46 tests de Fase 1/Hardening siguen pasando sin modificación de su lógica de negocio — sólo 2 tests (`test_rac_standalone_detection.sh`, `test_registries_consistency.sh`, `test_no_credential_exposure.sh`, `test_no_ambiguous_skill_references.sh`) se actualizaron para reconocer la nueva convención `agents/<id>/AGENT.md` junto a la plana `agents/<id>.md`, y 6 tests de queries (`test_application_data_blocked.sh`, `test_no_write_operations.sh`, `test_no_srvctl_crsctl_systemctl_write.sh`, `test_query_contract_requires_*.sh` ×3, `test_query_cost_*.sh` ×4, `test_query_limits.sh`, `test_version_awareness.sh`) se actualizaron para escanear recursivamente `queries/oracle/**` — ningún cambio de la lógica de negocio Foundation, sólo de alcance de escaneo.

## Known limitations

- El Gateway MCP, los collectors reales y los generadores de documentos binarios siguen siendo contrato/diseño (Fases 7 y 9), sin runtime ejecutable — igual que en Foundation.
- `oracle-dba-analyst` no distingue automáticamente entre PDBs individuales dentro de un CDB — opera a nivel de la conexión actual; iteración multi-PDB pertenece a `oracle-multitenant-analyst` (Fase 5).
- La detección de RAC One Node es "candidata, no confirmable" sin una query certificada adicional (nota en `agents/oracle-discovery-analyst/AGENT.md#architecture-detection`).
- Los tests son estáticos (análisis del repositorio + fixtures), no contra un ambiente Oracle real — las 9 fixtures (`tests/fixtures/*.yaml`) validan estructura y lógica de decisión, no ejecución real.

## Next phase

**Fase 3 — Performance**: AWR/ASH/ADDM/Statspack profundo, `oracle-performance-analyst`, licensing gate real para Diagnostics/Tuning Pack, SQL tuning, memoria (SGA/PGA) detallada.

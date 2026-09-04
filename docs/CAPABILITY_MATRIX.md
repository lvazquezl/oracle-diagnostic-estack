# Capability Matrix

Vista legible de [`config/capability-matrix.yaml`](../config/capability-matrix.yaml), que es la **fuente estructurada de verdad**. Este Markdown debe mantenerse consistente con el YAML — ver `tests/test_capability_matrix_registry_consistency.sh`. Consumida por el gate `version`/`architecture` de todo Workflow Contract (`docs/CONTRACTS.md#workflow-contract`) y por `policies/version-awareness-policy.md`.

## Leyenda

| Status | Significado |
|---|---|
| `PLANNED` | La feature Oracle existe en esa versión, pero el e-stack aún no tiene contrato/skill/query ni siquiera registrado para ella. |
| `FOUNDATION_ONLY` | El dominio tiene agente/contrato/skills `registered`, pero ningún skill materializado (`status: active`) cubre esta versión todavía. |
| `PARTIAL` | Al menos un skill materializado cubre esta versión, pero no el dominio completo. |
| `SUPPORTED` | Cobertura completa certificada (no ocurre aún en Fase 1/Hardening, salvo `/change` como proceso). |
| `UNSUPPORTED` | La feature Oracle **no existe** en esa versión/arquitectura — no es una limitación del e-stack. |
| `LICENSE_DEPENDENT` | Depende de licenciamiento adicional (Diagnostics/Tuning Pack, etc.) independientemente de la cobertura del e-stack — ver `policies/licensing-awareness-policy.md`. |

`latest` trackea la versión mayor soportada más reciente (hoy: 23ai) hasta que se agregue una nueva vía `/change compatibility`.

## Matriz

| Dominio | 10g | 11g | 12c | 18c | 19c | 21c | 23ai | latest |
|---|---|---|---|---|---|---|---|---|
| Oracle Core | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| Performance | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| AWR | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT |
| ASH | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT |
| ADDM | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT |
| Statspack | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |
| RAC | PLANNED | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| GI | UNSUPPORTED | FOUNDATION_ONLY | FOUNDATION_ONLY | FOUNDATION_ONLY | FOUNDATION_ONLY | FOUNDATION_ONLY | FOUNDATION_ONLY | FOUNDATION_ONLY |
| ASM | PLANNED | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Multitenant | UNSUPPORTED | UNSUPPORTED | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Data Guard | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| RMAN | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Network | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| OS | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Capacity | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Documentation | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| /change | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED | SUPPORTED |

## Notas por dominio

- **Oracle Core**: `SUPPORTED` desde Fase 2 — las 18 skills `oracle/*` completamente materializadas (`SKILL.md` + `manifest.yaml`), ~20 queries `Q-ORA-*` certificadas (Query Contract v2), 40 tests dedicados. `oracle/diagnostics` (ADR) requiere 11g+; en 10g esa sub-capacidad específica degrada a `UNSUPPORTED` sin afectar el resto del dominio.
- **Performance**: `SUPPORTED` desde Fase 3 — 31 skills `performance/*` completamente materializadas (`SKILL.md` + `manifest.yaml`), catálogo `queries/performance/**` (21 queries certificadas, Query Contract v2 + Query Variant Contract). Esta fila mide el core no licenciado (ruta estándar sin Diagnostics Pack, Statspack); AWR/ASH/ADDM son capacidades `LICENSE_DEPENDENT` independientes, filas propias abajo.
- **AWR/ASH/ADDM**: requieren Diagnostics Pack en todas las versiones donde existen (10g+) — `LICENSE_DEPENDENT` no es una limitación del e-stack sino del contrato de licenciamiento del cliente; ver `policies/licensing-awareness-policy.md`. Los 3 skills (`performance/awr-analysis`, `performance/ash-analysis`, `performance/addm-analysis`) están completamente materializados y funcionan cuando la licencia se confirma.
- **Statspack**: `SUPPORTED` desde Fase 3, cobertura multi-sección completa desde Fase 3 Completion Hardening — no requiere licencia adicional; `skills/performance/statspack-analysis` cubre Load Profile, Instance Efficiency, Top Wait Events, SQL ordered by CPU/elapsed/executions/gets/reads, Instance Activity, Library Cache, Latch, Enqueue, I/O (incl. ASM), Memory/Cache Sizes, Redo/Commit y Parsing derivados, vía consulta en vivo (`Q-PERF-WAIT-STATSPACK-001`, sólo wait events) y vía ingesta de reporte texto (`parsers/performance/statspack_parser.py`). Cobertura por-sección es `SUPPORTED`/`PARTIALLY_SUPPORTED`/`UNSUPPORTED` según el reporte concreto suministrado — ver `docs/PHASE_3_COMPLETION_HARDENING.md#gap-1--statspack-completion`.
- **RAC**: esta fila mide **deep diagnostics** (`skills/rac/session-distribution.md`, desde 11gR2). 10g/11gR1 no certificado → `PLANNED` (la feature Oracle sí existe), no `UNSUPPORTED`. **RAC detection** (presencia/topología básica) es distinta y está `SUPPORTED` desde Fase 2 vía el Target Profile (`docs/TARGET_PROFILE.md`, `capabilities.rac`).
- **GI (Grid Infrastructure)**: como marca/arquitectura formal es 11gR2+ (antes: Oracle Clusterware) → `UNSUPPORTED` en 10g. Ningún skill de `rac/ocr`, `rac/voting-disk`, `rac/crs-resources` está materializado aún → `FOUNDATION_ONLY` desde 11g.
- **ASM**: fila = **deep diagnostics** (`skills/asm/capacity.md`, desde 11g). **ASM detection** (presencia, `storage_mode`) está `SUPPORTED` desde Fase 2 vía el Target Profile.
- **Multitenant**: no existe antes de 12c → `UNSUPPORTED` real. Más de 1 PDB por CDB es `LICENSE_DEPENDENT` según edición. Fila = **deep diagnostics** (`skills/multitenant/container-state.md`, 12c+). **Container detection** (CDB/PDB, listado de PDBs) está `SUPPORTED` desde Fase 2 vía el Target Profile.
- **Data Guard**: fila = **deep diagnostics** (`skills/dataguard/lag.md`, 10g–23ai). Active Data Guard (lectura en standby) es `LICENSE_DEPENDENT` y se señala por finding específico. **Role detection** (primary/standby/logical/snapshot) está `SUPPORTED` desde Fase 2 vía el Target Profile.
- **RMAN, Network, OS, Capacity, Documentation**: un skill representativo materializado por dominio; el resto `registered` (ver `skills/REGISTRY.md`). OS y Documentation no dependen de la versión Oracle — la tabla los repite igual en las 8 columnas por consistencia estructural con el resto de la matriz.
- **/change**: el proceso de gobierno está completo y probado (`tests/test_change_governance_flow.sh`) independientemente de la versión del target — es un proceso sobre el propio e-stack, no sobre el ambiente Oracle.

## Actualización

Toda incorporación de una nueva versión Oracle o ampliación de cobertura de un dominio entra vía `/change compatibility` o `/change skill`/`/change query`, actualizando **ambos** archivos (`config/capability-matrix.yaml` y este Markdown) en el mismo cambio — ver `EVOLUTION.md#13-change-compatibility`.

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
| Oracle Core | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| Performance | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL |
| AWR | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT |
| ASH | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT |
| ADDM | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT | LICENSE_DEPENDENT |
| Statspack | FOUNDATION_ONLY | FOUNDATION_ONLY | FOUNDATION_ONLY | FOUNDATION_ONLY | FOUNDATION_ONLY | FOUNDATION_ONLY | FOUNDATION_ONLY | FOUNDATION_ONLY |
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

- **Oracle Core**: `skills/oracle/tablespaces.md` materializado (id `oracle/tablespaces`); resto de `oracle/*` `registered`.
- **Performance**: `skills/performance/wait-events.md` materializado (id `performance/wait-events`) con fallback AWR→Statspack; no bloqueado por licencia por sí solo (a diferencia de AWR/ASH/ADDM como dominios propios).
- **AWR/ASH/ADDM**: requieren Diagnostics Pack en todas las versiones donde existen (10g+) — `LICENSE_DEPENDENT` no es una limitación del e-stack sino del contrato de licenciamiento del cliente; ver `policies/licensing-awareness-policy.md`.
- **Statspack**: no requiere licencia adicional; `skills/performance/statspack-analysis` está `registered`, no materializado — usado como fallback conceptual por `performance/wait-events` pero sin skill propio activo aún.
- **RAC**: `skills/rac/session-distribution.md` materializado desde 11gR2. 10g/11gR1 RAC no está certificado en el catálogo → `PLANNED` (la feature Oracle sí existe), no `UNSUPPORTED`.
- **GI (Grid Infrastructure)**: como marca/arquitectura formal es 11gR2+ (antes: Oracle Clusterware) → `UNSUPPORTED` en 10g. Ningún skill de `rac/ocr`, `rac/voting-disk`, `rac/crs-resources` está materializado aún → `FOUNDATION_ONLY` desde 11g.
- **ASM**: `skills/asm/capacity.md` materializado desde 11g (declarado en su Skill Contract). ASM en 10g existe en Oracle pero no está certificado en el catálogo → `PLANNED`.
- **Multitenant**: no existe antes de 12c → `UNSUPPORTED` real. Más de 1 PDB por CDB es `LICENSE_DEPENDENT` según edición (se señala por finding, no a nivel de dominio completo en esta matriz). `skills/multitenant/container-state.md` materializado 12c+.
- **Data Guard**: `skills/dataguard/lag.md` materializado 10g–23ai. Active Data Guard (lectura en standby) es `LICENSE_DEPENDENT` y se señala por finding específico, no a nivel de dominio completo.
- **RMAN, Network, OS, Capacity, Documentation**: un skill representativo materializado por dominio; el resto `registered` (ver `skills/REGISTRY.md`). OS y Documentation no dependen de la versión Oracle — la tabla los repite igual en las 8 columnas por consistencia estructural con el resto de la matriz.
- **/change**: el proceso de gobierno está completo y probado (`tests/test_change_governance_flow.sh`) independientemente de la versión del target — es un proceso sobre el propio e-stack, no sobre el ambiente Oracle.

## Actualización

Toda incorporación de una nueva versión Oracle o ampliación de cobertura de un dominio entra vía `/change compatibility` o `/change skill`/`/change query`, actualizando **ambos** archivos (`config/capability-matrix.yaml` y este Markdown) en el mismo cambio — ver `EVOLUTION.md#13-change-compatibility`.

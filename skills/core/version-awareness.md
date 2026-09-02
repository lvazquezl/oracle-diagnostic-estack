---
name: version-awareness
display_name: "Version Awareness"
id: core/version-awareness
version: 1.0.0
domain: core
status: active
---

# Purpose

Normalizar la versión Oracle de un target a una representación estructurada (no un string a comparar léxicamente) y evaluar, junto con arquitectura/tenancy/rol/OS, si una capability es `SUPPORTED/PARTIAL/FOUNDATION_ONLY/PLANNED/UNSUPPORTED/LICENSE_DEPENDENT` para ese ambiente **antes** de que el orquestador la active — implementa el gate `version`/`architecture` del Workflow Contract.

# Supported Oracle versions

10g, 11g, 12c, 18c, 19c, 21c, 23ai, y releases posteriores mediante extensión gobernada (`/change compatibility`). Ver tabla de mapeo `raw → normalizado` en `policies/version-awareness-policy.md`.

# Supported OS/platforms

Todas — este skill opera sobre el string de versión reportado por Oracle, no depende del OS (el OS es una de las dimensiones que evalúa, no una restricción de su propia ejecución).

# Supported architectures

Standalone, RAC, RAC One Node, NON-CDB, CDB, PDB, ASM, Filesystem, Primary, Physical Standby, Active Data Guard — es agnóstico, evalúa cualquiera de estas dimensiones según lo que `core/context-discovery` haya reportado.

# Prerequisites

Requiere el output de `core/context-discovery` (versión raw, `instance_mode`, `container_mode`, `database_role`, `storage_mode`, `os_platform`) ya resuelto en la sesión/análisis.

# Required evidence

- Ninguna evidencia nueva — consume el `findings` de `core/context-discovery` y `config/capability-matrix.yaml`.

# Optional evidence

- Ninguna.

# Read-only operations

Lectura de `config/capability-matrix.yaml`; ningún acceso al ambiente Oracle/OS por sí mismo.

# Forbidden operations

No ejecuta ninguna operación de escritura. No modifica `config/capability-matrix.yaml` (eso es exclusivamente vía `/change compatibility`).

# Decision logic

1. Normalizar `product_version` (raw) a `{major, minor, release, ru, raw}` según `policies/version-awareness-policy.md#representación-normalizada`.
2. Mapear `major` (y, si aplica, `minor`) a la etiqueta de release conocida (`10g, 11g, 12c, 18c, 19c, 21c, 23ai`); si `major` excede el máximo conocido, tratarlo como `latest` y señalarlo (no rechazarlo — degradación graceful, no error duro).
3. Para la capability solicitada (dominio del Workflow/Agent que la pide), consultar `config/capability-matrix.yaml` cruzando `domain × release_label`.
4. Cruzar además con `instance_mode`, `container_mode`, `database_role`, `storage_mode` contra lo declarado por el agente/skill/query específico (`Supported architectures`/`container_scope`/`database_role_scope`) — la matriz da el estado por dominio×versión; el contrato del artefacto específico puede ser más restrictivo aún (ej. una query certificada sólo para `PRIMARY` aunque el dominio Data Guard sea `PARTIAL` en general).
5. Devolver el estado más restrictivo entre (a) lo que dice la matriz y (b) lo que declara el artefacto específico — nunca el más permisivo.
6. Si el resultado no es `SUPPORTED`/`PARTIAL`, producir el bloque `capability_status` completo (`docs/CONTRACTS.md#capability-status-model`) en vez de dejar que el agente/skill lo intente igual.

# Confidence model

No aplica el modelo RCA (`FACT/HYPOTHESIS/...`) — este skill produce un `capability_status`, no un hallazgo diagnóstico. La única gradación es si la normalización de versión fue posible (`ENVIRONMENT_UNKNOWN` si `core/context-discovery` no pudo confirmar la versión).

# Output schema

```yaml
oracle_version:
  major: number
  minor: number
  release: number|null
  ru: string|null
  raw: string
capability_evaluations:
  - domain: string
    capability_status: SUPPORTED|PARTIALLY_SUPPORTED|UNSUPPORTED|LICENSE_RESTRICTED|POLICY_BLOCKED|ENVIRONMENT_UNKNOWN
    reason: string
    impact: string
    alternative: string|null
    required_action: string|null
```

# Related skills

`core/context-discovery`, `core/platform-awareness`, `change/compatibility-evolution`.

# Escalation

Si `core/context-discovery` no resolvió la versión con al menos `OBSERVATION`, este skill devuelve `ENVIRONMENT_UNKNOWN` para toda capability evaluada — no asume una versión por defecto ni "la más reciente probable".

# Data sensitivity

Ninguna — opera sobre metadata de versión y el propio catálogo del e-stack, no sobre evidencia del ambiente.

# Context budget

Bajo — una lectura de `config/capability-matrix.yaml` (cacheable por sesión) más el output ya existente de discovery.

# Tests

`tests/test_capability_matrix_schema.sh`, `tests/test_capability_matrix_registry_consistency.sh`, `tests/test_10g_multitenant_unsupported.sh`, `tests/test_standalone_rac_unsupported.sh`, `tests/test_non_cdb_pdb_unsupported.sh`.

# Documentation requirements

Alimenta `context.md` del análisis con el bloque `oracle_version` normalizado, y `findings.md` con cualquier `capability_status` distinto de `SUPPORTED` detectado durante la evaluación.

# Evolution via `/change`

Cambios a la lógica de normalización vía `/change skill`; cobertura de nuevas versiones/dominios vía `/change compatibility` (actualiza `config/capability-matrix.yaml` + este skill si la lógica de mapeo cambia).

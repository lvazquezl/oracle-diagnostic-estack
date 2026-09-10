---
name: assessment
id: multitenant/assessment
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Orquestar `/assessment multitenant` — resultado mínimo: arquitectura, versión, estado CDB, inventario PDB, open modes, servicios, RAC placement, storage, TEMP/UNDO, parameter scope, componentes, plug-in violations, Resource Manager, lockdown profiles, riesgos y recomendaciones (`# 42` del prompt de Fase 6).

# Supported Oracle versions

12c–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/architecture` resuelto.

# Required evidence

Ninguna propia — orquesta todos los skills `multitenant/*` relevantes al scope solicitado.

# Optional evidence

`multitenant/application-containers`/`proxy-pdb` cuando el target los tiene presentes.

# Licensing requirements

Ninguno propio — hereda el de cada skill orquestado.

# Query IDs

Ninguno propio.

# Collector IDs

Ninguno propio.

# Read-only operations

Ninguna propia.

# Forbidden operations

Ninguna acción de escritura.

# Decision logic

1. Recopilar el resultado mínimo declarado en `# 42` desde cada skill orquestado, por referencia (`evidence_refs`), nunca duplicando evidencia cruda.
2. Producir `risks`/`recommendations` consolidados — cada recomendación con su propio Manual Action Contract.
3. Para CDBs grandes, aplicar el mismo principio de `top_n`/anomaly-first que `multitenant/healthcheck` (`# 49`, `# 50`).

# Normal state

Assessment completo sin riesgos `HIGH`/`CRITICAL`.

# Abnormal patterns

Cualquier riesgo consolidado de severidad `HIGH`/`CRITICAL` en cualquiera de las dimensiones orquestadas.

# False positives

Heredados de cada skill orquestado.

# Correlation rules

Orquesta sin re-analizar — cada dimensión la produce el skill correspondiente, este skill consolida.

# Confidence model

Hereda de cada skill orquestado.

# Severity

Consolidada desde cada skill orquestado, nunca colapsada en un score único.

# Output schema

```yaml
assessment:
  architecture: {...}
  version: string
  cdb_status: string
  pdb_inventory_summary: {...}
  open_modes_summary: {...}
  services_summary: {...}
  rac_placement_summary: {...}|null
  storage_summary: {...}
  temp_undo_summary: {...}
  parameter_scope_summary: {...}
  components_summary: {...}
  plugin_violations_summary: {...}
  resource_manager_summary: {...}
  lockdown_profiles_summary: {...}
  risks: [{summary: string, severity: string, evidence_refs: [EVD-...]}]
  recommendations: [{summary: string, manual_action: {...}}]
  evidence_refs: [EVD-...]
```

# Related skills

`multitenant/healthcheck`.

# Escalation

Riesgo `CRITICAL` → `incident-root-cause-analyst`.

# Manual remediation guidance

Cada recomendación usa el Manual Action Contract, `execution_status: NOT_EXECUTED`.

# Security

Hereda de cada skill orquestado.

# Tests

`tests/test_multitenant_agent_manifest.sh`.

# Documentation requirements

Genera el Markdown de cierre de `/assessment multitenant` — `analysis/ANA-*/analysis.md`.

# Change history

v1.0.0 — Fase 6, creación inicial.

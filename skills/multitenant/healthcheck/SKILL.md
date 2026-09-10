---
name: healthcheck
id: multitenant/healthcheck
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Orquestar `/healthcheck cdb` y `/healthcheck pdb` — flujo end-to-end sobre CDB Health Model y PDB Health Model (`# 38`-`# 41` del prompt de Fase 6).

# Supported Oracle versions

12c–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/architecture` resuelto.

# Required evidence

Ninguna propia — orquesta `multitenant/pdb-inventory`, `pdb-state`, `pdb-services`, `pdb-tablespaces`, `pdb-temp`, `pdb-undo`, `components`, `plugin-violations`, `resource-usage`, `resource-manager`.

# Optional evidence

`multitenant/pdb-rac-placement` si el target es RAC.

# Licensing requirements

Ninguno propio — hereda el de cada skill orquestado.

# Query IDs

Ninguno propio — reutiliza los de los skills orquestados, nunca duplica evidencia.

# Collector IDs

Ninguno propio.

# Read-only operations

Ninguna propia.

# Forbidden operations

Ninguna acción de escritura, hereda todas las prohibiciones de los skills orquestados.

# Decision logic

**`/healthcheck cdb`**: `Target Profile → CDB Detection → Root → PDB Inventory → States → Services → Storage → TEMP/UNDO → Components → Plug-in Violations → Resource Governance → Findings → Markdown` (`# 40`).

**`/healthcheck pdb`**: acepta una PDB por token/nombre sanitizado, analiza sólo el scope solicitado — nunca cambia de contenedor de forma insegura (`# 41`, `# 55`).

Para CDBs con muchas PDBs: CDB summary → anomaly detection → deep analysis sólo para las PDBs afectadas (`# 50`) — nunca análisis profundo automático por cada PDB.

# Normal state

Todas las dimensiones del CDB Health Model / PDB Health Model en `HEALTHY`.

# Abnormal patterns

Cualquier dimensión en `WARNING|DEGRADED|CRITICAL` — el healthcheck las reporta todas por separado, nunca colapsa en un score único (`# 39`).

# False positives

Heredados de cada skill orquestado — ver sus propias secciones.

# Correlation rules

Orquesta, no re-analiza — cada dimensión la produce el skill correspondiente.

# Confidence model

Hereda de cada skill orquestado.

# Severity

Hereda de cada skill orquestado; el healthcheck agrega sin ocultar el detalle por dimensión.

# Output schema

```yaml
cdb_health_model: {architecture: ..., root: ..., pdb_states: ..., services: ..., storage: ..., temp_undo: ..., components: ..., plugin_violations: ..., resource_governance: ..., rac_placement: ..., dataguard_context: ...}
pdb_health_model: [{pdb_token: string, open_state: ..., services: ..., sessions: ..., tablespaces: ..., temp: ..., undo: ..., components: ..., plugin_violations: ..., resource_usage: ..., rac_placement: ...}]
evidence_refs: [EVD-...]
```

# Related skills

`multitenant/assessment` (assessment es más amplio, incluye recomendaciones; healthcheck es el flujo operativo rápido).

# Escalation

Cualquier dimensión `CRITICAL` → `incident-root-cause-analyst`.

# Manual remediation guidance

Agregada de las recomendaciones de cada skill orquestado, vía Manual Action Contract.

# Security

Hereda de cada skill orquestado.

# Tests

`tests/test_multitenant_agent_manifest.sh`.

# Documentation requirements

Genera el Markdown de cierre de `/healthcheck cdb`/`/healthcheck pdb`.

# Change history

v1.0.0 — Fase 6, creación inicial.

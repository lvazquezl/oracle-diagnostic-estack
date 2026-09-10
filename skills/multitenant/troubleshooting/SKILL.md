---
name: troubleshooting
id: multitenant/troubleshooting
version: 1.0.0
domain: multitenant
status: active
---

# Purpose

Troubleshooting dirigido por síntoma para escenarios Multitenant (`cdb`/`pdb`/`pdb-open-state`/`pdb-service`/`pdb-temp`/`pdb-undo`/`plugin-violation`/`pdb-resource`/`pdb-rac-placement`), extendiendo `/diagnose` (`# 43` del prompt de Fase 6). No crea slash command por cada código ORA.

# Supported Oracle versions

12c–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`multitenant/architecture` resuelto; síntoma reportado por el DBA.

# Required evidence

Ninguna propia — activa el skill específico correspondiente al síntoma reportado (`pdb-state`, `pdb-services`, `pdb-temp`, `pdb-undo`, `plugin-violations`, `resource-usage`, `pdb-rac-placement`).

# Optional evidence

Conocimiento de errores organizado (`knowledge/errors/`) para familias ORA-650xx/651xx cuando estén validadas — nunca códigos inventados (`# 44`).

# Licensing requirements

Ninguno propio — hereda el del skill activado.

# Query IDs

Ninguno propio.

# Collector IDs

Ninguno propio.

# Read-only operations

Ninguna propia.

# Forbidden operations

Ninguna acción de escritura.

# Decision logic

1. Mapear el síntoma reportado al skill correspondiente (`cdb`→`architecture`/`pdb-state` de CDB$ROOT, `pdb`→`pdb-state`, `pdb-open-state`→`pdb-open-mode`, `pdb-service`→`pdb-services`, `pdb-temp`→`pdb-temp`, `pdb-undo`→`pdb-undo`, `plugin-violation`→`plugin-violations`, `pdb-resource`→`resource-usage`, `pdb-rac-placement`→`pdb-rac-placement`).
2. Activar únicamente el/los skill(s) mínimos necesarios — nunca todos los skills `multitenant/*` por defecto.
3. Correlacionar con `knowledge/errors/` sólo para patrones ya validados, agrupados por familia, no un archivo por código individual (`# 44`).

# Normal state

N/A — este skill sólo se activa ante un síntoma reportado.

# Abnormal patterns

Definidos por el skill activado según el síntoma.

# False positives

Heredados del skill activado.

# Correlation rules

Cruza con `incident-root-cause-analyst` cuando el síntoma escala a incidente formal (`# 69`).

# Confidence model

Hereda del skill activado.

# Severity

Hereda del skill activado.

# Output schema

```yaml
troubleshooting_result:
  symptom: string
  skill_activated: string
  findings: [...]
  evidence_refs: [EVD-...]
```

# Related skills

`multitenant/pdb-state`, `multitenant/plugin-violations`, todo skill `multitenant/*` según el síntoma.

# Escalation

Ver `collaboration.yaml#escalation_conditions` del agente.

# Manual remediation guidance

Hereda del skill activado, siempre vía Manual Action Contract.

# Security

Hereda del skill activado.

# Tests

`tests/test_multitenant_agent_manifest.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/pdb-findings.md` cuando el troubleshooting produce un análisis formal.

# Change history

v1.0.0 — Fase 6, creación inicial.

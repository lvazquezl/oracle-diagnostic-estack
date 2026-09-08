---
name: assessment
id: dataguard/assessment
version: 1.0.0
domain: dataguard
status: active
---

# Purpose

Orquestar `/assessment dataguard` (`# 47` del prompt de Fase 5): informe de arquitectura/riesgos/recomendaciones — arquitectura, roles, versiones, protección, transporte, apply, lag, gaps, SRL, Broker, FSFO, dependencias de red/RAC/storage, riesgos, recomendaciones, readiness.

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported Data Guard architectures

PHYSICAL_STANDBY (foco); LOGICAL_STANDBY/SNAPSHOT_STANDBY/FAR_SYNC reconocidos con `PARTIALLY_SUPPORTED`.

# Prerequisites

Target Profile con `dataguard.enabled = true`.

# Required evidence

Evidencia agregada de todos los skills `dataguard/*` relevantes a la topología detectada.

# Optional evidence

Resumen de `dataguard/switchover-readiness`/`dataguard/failover-readiness` cuando el análisis lo requiere.

# Licensing requirements

Ninguno propio — hereda el de cada skill subordinado; señala explícitamente Active Data Guard cuando corresponde (`# 38`).

# Query IDs

Ninguna propia.

# Collector IDs

Ninguno propio.

# Read-only operations

Orquesta lecturas ya cubiertas por skills subordinados.

# Forbidden operations

No ejecuta ninguna acción.

# Decision logic

1. Recolectar evidencia de arquitectura/roles/versiones/protección/transporte/apply/lag/gaps/SRL/Broker/FSFO.
2. Clasificar dependencias cross-domain (red, RAC, storage) — señaladas, no re-analizadas en profundidad aquí.
3. Clasificar riesgos encontrados por severidad y generar recomendaciones — siempre `manual_action`.
4. Incluir readiness de switchover/failover como parte del resultado.

# Normal state

Arquitectura consistente con la topología esperada, sin riesgos `HIGH`/`CRITICAL`.

# Abnormal patterns

Cualquier riesgo `HIGH`/`CRITICAL` no accionable de forma automática.

# False positives

Ninguno propio — hereda de los skills subordinados.

# Correlation rules

Consolida todos los skills `dataguard/*`, sin reconstruir su lógica.

# Confidence model

Hereda el de cada skill subordinado.

# Severity

Consolidada del máximo de los componentes.

# Output schema

```yaml
findings:
  - architecture: string
    versions: [string]
    risks: [{observation: string, severity: string, evidence_refs: [EVD-...]}]
    recommendations: [{summary: string}]
    readiness_summary: {switchover: string, failover: string}
```

# Related skills

`dataguard/healthcheck`, `dataguard/switchover-readiness`, `dataguard/failover-readiness`.

# Escalation

Riesgo `HIGH`/`CRITICAL` no accionable de forma automática → `change-advisor`.

# Manual remediation guidance

Ninguna propia — cada riesgo aporta la suya vía su skill subordinado.

# Security

Hereda la sensibilidad de cada dimensión.

# Tests

`tests/test_no_write_operations.sh`.

# Documentation requirements

Genera el assessment en Markdown vía `technical-documentation-manager`.

# Change history

v1.0.0 — Fase 5, creación inicial.

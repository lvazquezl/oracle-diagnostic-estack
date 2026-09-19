---
name: rca-report
id: incident/rca-report
version: 1.0.0
domain: incident
status: active
---

# Purpose

Genera el reporte de Root Cause Analysis enfocado (`# 1133`-`# 1145` del prompt de Fase 11) —
versión condensada y reproducible del análisis causal: hipótesis evaluadas (incluidas las
rechazadas, con su razón), causal_chain completa, evidencia de confirmación, nivel de confianza —
diseñado para ser reproducible por otro DBA con la misma evidencia.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/root-cause`, `incident/hypothesis-testing`, `incident/contradiction-analysis`
ejecutados.

# Required evidence

- `hypotheses[]` completo (incluidas `REJECTED`/`WEAKENED`, no sólo la confirmada),
  `root_cause` con `causal_chain`.

# Optional evidence

Ninguna adicional.

# Read-only operations

Renderizado de Markdown local.

# Forbidden operations

Nunca omite las hipótesis rechazadas del reporte — "RCA MUST BE REPRODUCIBLE" (non-negotiable del
prompt) exige que otro analista pueda seguir el mismo razonamiento, incluyendo por qué se
descartaron alternativas.

# Decision logic

1. Listar TODAS las hipótesis evaluadas con su `status` final (`SUPPORTED|WEAKENED|REJECTED|
   CONFIRMED|INSUFFICIENT_EVIDENCE`) y la evidencia/contradicción que determinó cada una — nunca
   sólo la ganadora.
2. Presentar el `causal_chain` completo de la causa confirmada/probable, cada eslabón con su
   evidencia de soporte (nunca un salto directo de alerta a causa raíz).
3. Declarar explícitamente el nivel de `confidence`/`completeness` final, incluyendo
   `UNDETERMINED` cuando la evidencia fue insuficiente — nunca inflado para parecer más
   concluyente de lo que la evidencia permite.
4. Incluir el `change_correlation`/`capacity_correlation` relevante distinguiendo
   `CHANGE_CORRELATED` de `CHANGE_CAUSED` explícitamente.

# Normal state

Reporte de RCA completo, reproducible, con todas las hipótesis trazadas.

# Abnormal patterns

N/A directo.

# False positives

Un RCA report que omite las hipótesis descartadas o presenta la conclusión sin las alternativas
consideradas es exactamente el defecto de reproducibilidad que este skill previene.

# Correlation rules

Consume `incident/root-cause`, `incident/hypothesis-testing`, `incident/contradiction-analysis`,
`incident/change-correlation`, `incident/capacity-correlation`. Es consumido por
`incident/incident-report` (lo referencia) y `incident/post-incident-review`.

# Confidence model

Refleja fielmente el `confidence`/`completeness` del `root_cause` — nunca los recalcula ni los
suaviza para el reporte.

# Severity

N/A directa.

# Output schema

Ver `docs/INCIDENT_ROOT_CAUSE_MODEL.md` y `output-schema.yaml` del agente.

# Related skills

`incident/incident-report`, `incident/root-cause`, `incident/hypothesis-testing`.

# Escalation

N/A directa.

# Manual remediation guidance

Referencia (no duplica) el `manual_remediation_plan` del `incident-report` completo.

# Security

Hereda estrictamente `sanitizers/data-classification-policy.md`.

# Tests

`tests/test_incident_rca_report_generation.sh`.

# Documentation requirements

Este skill ES la generación de `incident-rca.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

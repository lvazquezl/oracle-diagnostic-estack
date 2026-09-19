---
name: hypothesis-generation
id: incident/hypothesis-generation
version: 1.0.0
domain: incident
status: active
---

# Purpose

Genera hipótesis explícitas a partir de síntomas, timeline, estado de recursos, known errors,
cambios recientes y evidencia cross-domain (`# 592`-`# 601` del prompt de Fase 11) — aplicando
Top-N, nunca decenas de hipótesis irrelevantes (`# 603`-`# 605`).

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/symptom-clustering`, `incident/timeline` ejecutados.

# Required evidence

- Symptom clusters, timeline, `known_error_matches` (cuando disponibles).

# Optional evidence

- `change_correlation` de `incident/change-correlation`, cuando disponible.

# Read-only operations

Cálculo/razonamiento local sobre evidencia ya correlacionada.

# Forbidden operations

Nunca genera una hipótesis sin al menos un elemento de evidencia de soporte inicial (símbolo,
patrón, o correlación) — nunca especulación sin ancla en evidencia.

# Decision logic

1. Generar hipótesis candidatas a partir de: síntomas, timeline, estado de recursos (evidencia
   cross-domain), known errors, cambios recientes (`# 592`-`# 601` del prompt).
2. Aplicar Top-N (`incident.max_hypotheses` del Target Profile, `docs/TARGET_PROFILE.md#schema`,
   default recomendado 5 — configurable, nunca universal) — nunca generar decenas de hipótesis
   irrelevantes.
3. Cada hipótesis se registra con el modelo `hypothesis` completo
   (`docs/INCIDENT_HYPOTHESIS_MODEL.md#schema`): `hypothesis_id`, `statement`, `domain`,
   `supporting_evidence`, `contradicting_evidence`, `missing_evidence`, `confidence`, `status`.
4. Estado inicial de toda hipótesis nueva: `OPEN` (`# 577`-`# 586` del prompt) — nunca se crea ya
   `CONFIRMED`.

# Normal state

Top-N hipótesis (`≤ max_hypotheses`) con `status: OPEN`, cada una con al menos un elemento de
`supporting_evidence`.

# Abnormal patterns

Más de `max_hypotheses` candidatas generadas — se recorta explícitamente al Top-N por scoring
(ver `incident/hypothesis-testing#ranking`), nunca se presentan todas sin filtrar.

# False positives

Generar una hipótesis puramente especulativa sin ningún elemento de evidencia de soporte es el
falso positivo que este skill evita.

# Correlation rules

Consume `incident/symptom-clustering`, `incident/timeline`, `incident/known-error-correlation`,
`incident/change-correlation`. Alimenta `incident/hypothesis-testing`.

# Confidence model

Cada hipótesis inicia sin confidence asignado hasta que `incident/hypothesis-testing` la evalúe —
este skill sólo genera el `statement` y la evidencia de soporte inicial.

# Severity

N/A directa.

# Output schema

Ver `docs/INCIDENT_HYPOTHESIS_MODEL.md#schema`.

# Related skills

`incident/hypothesis-testing`, `incident/contradiction-analysis`, `incident/root-cause`.

# Escalation

Si generar una hipótesis plausible requiere evidencia de un dominio fuera del scope activado,
solicita al orquestador activar el especialista mínimo necesario.

# Manual remediation guidance

N/A directa.

# Security

Sin datos sensibles adicionales.

# Tests

`tests/test_incident_hypothesis_generation.sh`.

# Documentation requirements

Alimenta `incident-hypotheses.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

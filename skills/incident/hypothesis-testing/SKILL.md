---
name: hypothesis-testing
id: incident/hypothesis-testing
version: 1.0.0
domain: incident
status: active
---

# Purpose

Prueba cada hipótesis generada contra evidencia adicional puntual, rankea por fuerza de evidencia
y actualiza su `status`/`confidence` (`docs/INCIDENT_HYPOTHESIS_MODEL.md`) — nunca rankea sólo por
frecuencia histórica (`# 609`-`# 622` del prompt de Fase 11).

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/hypothesis-generation` ejecutado.

# Required evidence

- Hipótesis `OPEN` generadas.

# Optional evidence

- Evidencia adicional puntual solicitada a un especialista específico para validar/descartar una
  hipótesis (nunca recolección exploratoria sin hipótesis asociada).

# Read-only operations

Cálculo local — evaluación de evidencia ya recolectada o solicitada puntualmente.

# Forbidden operations

Nunca promueve una hipótesis a `CONFIRMED` sin cumplir `incident/root-cause#confirmation-rule`.

## Ranking

Rankear por (`# 611`-`# 621` del prompt): `evidence strength`, `temporal consistency`,
`mechanistic plausibility`, `cross-domain consistency`, `contradiction count`, `missing critical
evidence` — nunca por frecuencia histórica de patrones similares únicamente.

# Decision logic

1. Para cada hipótesis `OPEN`, definir qué evidencia adicional la confirmaría o descartaría (plan
   de validación) — solicitarla al especialista correspondiente si no está ya disponible.
2. Evaluar `supporting_evidence` vs. `contradicting_evidence` (ver `incident/contradiction-analysis`
   para el detalle del manejo de contradicciones).
3. Actualizar `status`: `SUPPORTED` (evidencia consistente, aún no suficiente para `CONFIRMED`),
   `WEAKENED` (contradicción parcial detectada), `REJECTED` (contradicción fuerte, sin soporte
   viable), `INSUFFICIENT_EVIDENCE` (ni soporte ni contradicción suficiente para decidir).
4. `confidence` (`HIGH|MEDIUM|LOW|INSUFFICIENT`) se deriva del ranking — siempre con
   `confidence_score` opcional (0.0-1.0) acompañado de explicación, nunca un número aislado
   (`# 637`-`# 643` del prompt).
5. Promoción a `CONFIRMED` está gobernada por `incident/root-cause#confirmation-rule` — este skill
   nunca la aplica unilateralmente sin cumplir esa regla.

# Normal state

Hipótesis con `status` actualizado y `confidence` explicado, ordenadas por ranking.

# Abnormal patterns

Múltiples hipótesis con ranking similar y ninguna claramente dominante — reportado como ambigüedad
explícita, nunca resuelto arbitrariamente.

# False positives

Promover una hipótesis por ser la más frecuente históricamente, sin evidencia directa suficiente
para este incidente, es el falso positivo que este skill evita.

# Correlation rules

Consume `incident/hypothesis-generation`, `incident/contradiction-analysis`. Alimenta
`incident/root-cause`, `incident/contributing-factors`.

# Confidence model

`HIGH|MEDIUM|LOW|INSUFFICIENT` con `confidence_score` opcional, siempre con explicación de la
razón (nunca sólo el número).

# Severity

N/A directa.

# Output schema

Ver `docs/INCIDENT_HYPOTHESIS_MODEL.md#schema`.

# Related skills

`incident/hypothesis-generation`, `incident/contradiction-analysis`, `incident/root-cause`.

# Escalation

Hipótesis que requiere validación fuera del scope activado escala como solicitud de activación
mínima del especialista correspondiente.

# Manual remediation guidance

N/A directa.

# Security

Sin datos sensibles adicionales.

# Tests

`tests/test_incident_hypothesis_support.sh`, `tests/test_incident_hypothesis_rejection.sh`,
`tests/test_incident_hypothesis_insufficient_evidence.sh`.

# Documentation requirements

Alimenta `incident-hypotheses.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

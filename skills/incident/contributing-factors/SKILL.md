---
name: contributing-factors
id: incident/contributing-factors
version: 1.0.0
domain: incident
status: active
---

# Purpose

Separa explícitamente los factores contribuyentes del root cause propiamente dicho
(`# 681`-`# 703` del prompt de Fase 11) — cada factor con su propio rol
(`AMPLIFIER|PRECONDITION|LATENT_RISK|RECOVERY_DELAY|OBSERVABILITY_GAP`), nunca mezclado dentro del
`causal_chain` de la causa raíz.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/root-cause` ejecutado (al menos parcialmente — factores contribuyentes pueden
identificarse incluso cuando el root cause queda `INCONCLUSIVE`).

# Required evidence

- Hipótesis `WEAKENED`/`SUPPORTED` que no alcanzaron root cause pero sí aportaron evidencia de
  haber amplificado/precondicionado el incidente.

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local.

# Forbidden operations

Nunca reclasifica un contributing factor como root cause sin cumplir
`incident/root-cause#confirmation-rule` — los roles son distintos por diseño, no intercambiables.

# Decision logic

1. Para cada hipótesis que no calificó como root cause pero tiene evidencia de haber influido en
   el incidente, clasificar su rol: `AMPLIFIER` (empeoró el impacto), `PRECONDITION` (condición
   necesaria pero no suficiente), `LATENT_RISK` (riesgo preexistente no relacionado directamente),
   `RECOVERY_DELAY` (retrasó la recuperación sin causar el incidente), `OBSERVABILITY_GAP` (falta
   de visibilidad que dificultó el diagnóstico — ver también `incident/post-incident-review`).
2. Cada factor se registra con su propio `confidence` — independiente del confidence del root
   cause principal.

# Normal state

Factores contribuyentes identificados con rol y evidencia propia, separados del `causal_chain`
del root cause.

# Abnormal patterns

Un factor con evidencia fuerte que en realidad debería ser el root cause (o co-root-cause) —
reevaluado contra `incident/root-cause#multiple-root-causes` en vez de forzarlo como
"contribuyente" para simplificar el reporte.

# False positives

Etiquetar cualquier condición preexistente como "contributing factor" sin evidencia de que
realmente influyó en este incidente específico es el falso positivo que este skill evita.

# Correlation rules

Consume `incident/root-cause`, `incident/hypothesis-testing`. Alimenta `incident/rca-report`,
`incident/post-incident-review`.

# Confidence model

`HIGH|MEDIUM|LOW|INSUFFICIENT` por cada factor, independiente del confidence del root cause.

# Severity

N/A directa.

# Output schema

```yaml
contributing_factor:
  factor_id: string
  statement: string
  evidence_ids: [EVD-...]
  role: AMPLIFIER|PRECONDITION|LATENT_RISK|RECOVERY_DELAY|OBSERVABILITY_GAP
  confidence: HIGH|MEDIUM|LOW|INSUFFICIENT
```

# Related skills

`incident/root-cause`, `incident/post-incident-review`, `incident/lessons-learned`.

# Escalation

Un `OBSERVABILITY_GAP` identificado aquí se reporta también como `observability_gap` independiente
en el RCA final (ver `incident/post-incident-review`).

# Manual remediation guidance

`manual_action` puede recomendar abordar un `LATENT_RISK`/`PRECONDITION` como prevención — siempre
`NOT_EXECUTED`.

# Security

Sin datos sensibles adicionales.

# Tests

`tests/test_incident_contributing_factors.sh`.

# Documentation requirements

Alimenta `incident-root-cause.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

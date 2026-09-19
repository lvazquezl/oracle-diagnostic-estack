---
name: contradiction-analysis
id: incident/contradiction-analysis
version: 1.0.0
domain: incident
status: active
---

# Purpose

Toda hipótesis debe considerar evidencia contradictoria explícitamente — nunca ocultar
contradicciones (`# 1008`-`# 1026` del prompt de Fase 11). Ejemplo del propio prompt: hipótesis de
"storage latency" soportada por `high db file sequential read`, pero contradicha por
`storage latency normal` y `OS iostat normal` — ambas se reportan, nunca sólo la que soporta la
hipótesis preferida.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/hypothesis-generation` ejecutado.

# Required evidence

- Evidencia de soporte y de contradicción disponible para cada hipótesis.

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local.

# Forbidden operations

Nunca descarta silenciosamente evidencia contradictoria para "limpiar" el caso a favor de una
hipótesis preferida.

# Decision logic

1. Para cada hipótesis, buscar activamente evidencia que la contradiga, no sólo la que la
   respalda — sesgo de confirmación es el error que este skill existe para prevenir.
2. Registrar cada contradicción explícitamente (`contradictions` en el output schema del agente):
   `hypothesis_id`, `supporting`, `contradicting`, `resolution` (si se resolvió, o `null` si
   permanece abierta).
3. Una contradicción no resuelta mantiene la hipótesis en `WEAKENED`/`INSUFFICIENT_EVIDENCE` — 
   nunca se promueve a `CONFIRMED` con una contradicción activa sin resolución explícita
   (ver `incident/root-cause#confirmation-rule`).
4. Resolver una contradicción requiere evidencia adicional específica (ej. una fuente resulta ser
   menos confiable/desactualizada) — nunca se resuelve por preferencia o conveniencia narrativa.

# Normal state

Toda hipótesis con contradicciones evaluadas explícitamente, resueltas o declaradas abiertas.

# Abnormal patterns

Hipótesis con contradicción fuerte no resuelta que de todos modos mantiene `status: SUPPORTED` —
defecto que este skill existe para prevenir (debería degradar a `WEAKENED` como mínimo).

# False positives

Ignorar una fuente de evidencia que contradice la hipótesis favorita del analista (sesgo de
confirmación) es exactamente el falso positivo que este skill previene estructuralmente.

# Correlation rules

Consume `incident/hypothesis-generation`, `incident/evidence-correlation`. Alimenta
`incident/hypothesis-testing`, `incident/root-cause`.

# Confidence model

Cada contradicción se reporta con su propia evidencia — no colapsa a un único score.

# Severity

N/A directa.

# Output schema

```yaml
contradictions:
  - hypothesis_id: string
    supporting: [string]
    contradicting: [string]
    resolution: string|null
```

# Related skills

`incident/hypothesis-generation`, `incident/hypothesis-testing`, `incident/root-cause`.

# Escalation

Contradicción irresoluble con la evidencia disponible escala como limitación explícita del RCA
(`root_cause.limitations`).

# Manual remediation guidance

N/A directa.

# Security

Sin datos sensibles adicionales.

# Tests

`tests/test_incident_hypothesis_contradiction.sh`.

# Documentation requirements

Alimenta `incident-hypotheses.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

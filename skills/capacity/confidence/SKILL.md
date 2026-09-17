---
name: confidence
id: capacity/confidence
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Determina y explica el nivel de confianza de todo forecast/trend/risk del dominio capacity —
nunca un número aislado sin explicación. Consolida el modelo de confianza usado por
`capacity/trend-analysis`, `capacity/forecasting`, `capacity/threshold-crossing` y
`capacity/risk-classification`, garantizando que ningún resultado de baja confianza se presente
como certeza.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`capacity/data-quality` ejecutado para el recurso en cuestión.

# Required evidence

- `data_quality.status` del recurso.
- longitud de histórico disponible vs. `capacity.forecasting.minimum_history_days`/
  `preferred_history_days` del Target Profile.

# Optional evidence

- `fit_quality`/residual analysis del forecast, cuando ya calculado.

# Read-only operations

Cálculo local sobre metadata de calidad/histórico ya disponible.

# Forbidden operations

Ninguna.

# Decision logic

1. Estados mínimos: `HIGH`, `MEDIUM`, `LOW`, `INSUFFICIENT` (`# 968`-`# 979` del prompt de
   Fase 10) — nunca un score numérico sin uno de estos estados adjunto.
2. `INSUFFICIENT` cuando el histórico disponible está por debajo de
   `capacity.forecasting.minimum_history_days`/`minimum_samples` — nunca se produce un forecast
   con confianza `LOW` en ese caso, es directamente `INSUFFICIENT` (ver
   `capacity/forecasting#history-requirements`).
3. `LOW` cuando hay histórico mínimo pero por debajo de `preferred_history_days`, alta
   volatilidad, o `data_quality.status: DEGRADED`.
4. `MEDIUM`/`HIGH` requieren histórico igual o superior a `preferred_history_days`,
   `data_quality.status: GOOD`/`ACCEPTABLE`, y bondad de ajuste (`fit_quality`) razonable para el
   método usado.
5. Cada nivel de confianza se acompaña de una explicación breve (razón concreta: histórico corto,
   alta volatilidad, calidad de datos degradada, etc.) — nunca sólo la etiqueta sin razón (`# 979`
   del prompt: "no usar sólo un número sin explicación").
6. `RISK: HIGH` + `CONFIDENCE: LOW` es un resultado válido y esperado — este skill nunca sube
   artificialmente la confianza para simplificar un hallazgo de riesgo alto (`# 1266`-`# 1277` del
   prompt: "risk must include confidence").

# Normal state

Confianza `HIGH`/`MEDIUM` con histórico suficiente y datos de buena calidad.

# Abnormal patterns

Confianza `LOW`/`INSUFFICIENT` sostenida — reportado explícitamente como limitación, nunca oculto.

# False positives

Ninguno — la confianza refleja fielmente la evidencia disponible, nunca se ajusta para parecer
mejor de lo que la evidencia soporta.

# Correlation rules

Alimenta `capacity/trend-analysis`, `capacity/forecasting`, `capacity/threshold-crossing`,
`capacity/risk-classification`.

# Confidence model

Este skill ES el modelo de confianza — no tiene un meta-nivel de confianza propio distinto.

# Severity

N/A directa.

# Output schema

```yaml
confidence_assessment:
  level: HIGH|MEDIUM|LOW|INSUFFICIENT
  reason: string
  history_days_available: number|null
  history_days_required: number|null
  data_quality_status: string|null
```

# Related skills

`capacity/data-quality`, `capacity/trend-analysis`, `capacity/forecasting`,
`capacity/risk-classification`.

# Escalation

Confianza `INSUFFICIENT` sostenida para un recurso crítico escala como limitación explícita en
`capacity/capacity-assessment` — nunca bloquea el resto del reporte.

# Manual remediation guidance

N/A directa — mejorar la confianza requiere más histórico/mejor calidad de datos, no una acción
ejecutable por este skill.

# Security

Sin datos sensibles.

# Tests

`tests/test_forecast_confidence.sh`, `tests/test_capacity_insufficient_history.sh`.

# Documentation requirements

Alimenta `capacity-forecast.md`, `capacity-risk.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.

---
name: seasonality-awareness
id: capacity/seasonality-awareness
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Detecta awareness de estacionalidad (semanal/mensual/business-cycle) en una serie de capacidad —
sin prometer modelos estacionales avanzados en el MVP cuando no hay suficiente historia.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`capacity/trend-analysis` ejecutado (estadísticas baseline disponibles).

# Required evidence

- serie normalizada/segmentada del recurso, con al menos varias semanas de historia para
  evaluar estacionalidad semanal.

# Optional evidence

Ninguna.

# Read-only operations

Cálculo local.

# Forbidden operations

Ninguna.

# Decision logic

1. Estados: `NOT_DETECTED` (sin patrón estacional identificable), `POSSIBLE` (patrón sugerido
   pero sin confirmación estadística sólida), `DETECTED` (patrón estacional confirmado con
   evidencia suficiente), `INSUFFICIENT_HISTORY` (historia insuficiente para evaluar) (`# 913`-
   `# 920` del prompt de Fase 10).
2. Evaluar awareness de patrones `weekly`, `monthly`, `business-cycle` — nunca prometer un modelo
   estacional avanzado (ej. descomposición STL completa) en el MVP si no hay historia suficiente
   (`# 901`-`# 911` del prompt).
3. Cuando `DETECTED`, `capacity/forecasting` puede considerarlo como factor de selección de
   método (ver `capacity/forecasting#method-selection`) — pero el MVP no implementa un forecast
   estacional propio, sólo reporta el estado detectado.

# Normal state

`NOT_DETECTED`/`INSUFFICIENT_HISTORY` para recursos sin historia suficiente; `POSSIBLE`/`DETECTED`
reportado explícitamente cuando corresponda.

# Abnormal patterns

`DETECTED` no considerado por `capacity/forecasting` en la selección de método — sería un defecto
de integración, no de este skill.

# False positives

Declarar `DETECTED` con menos de unas pocas semanas de historia es el falso positivo que este
skill evita — en ese caso el estado correcto es `INSUFFICIENT_HISTORY`.

# Correlation rules

Alimenta `capacity/forecasting`.

# Confidence model

`OBSERVATION` para patrones sugeridos (`POSSIBLE`); `FACT` sólo cuando el patrón está confirmado
estadísticamente (`DETECTED`) sobre suficiente historia.

# Severity

N/A directa.

# Output schema

```yaml
seasonality:
  resource: string
  weekly: NOT_DETECTED|POSSIBLE|DETECTED|INSUFFICIENT_HISTORY
  monthly: NOT_DETECTED|POSSIBLE|DETECTED|INSUFFICIENT_HISTORY
  business_cycle: NOT_DETECTED|POSSIBLE|DETECTED|INSUFFICIENT_HISTORY
  evidence_refs: [EVD-...]
```

# Related skills

`capacity/trend-analysis`, `capacity/forecasting`.

# Escalation

Ninguna directa.

# Manual remediation guidance

N/A directa.

# Security

Sin datos sensibles.

# Tests

Cubierto indirectamente por `tests/test_forecast_outlier_awareness.sh` y los tests de
`capacity/trend-analysis` — sin test dedicado adicional en el alcance MVP de Fase 10.

# Documentation requirements

Alimenta `capacity-forecast.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.

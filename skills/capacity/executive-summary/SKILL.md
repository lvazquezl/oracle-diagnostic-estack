---
name: executive-summary
id: capacity/executive-summary
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Produce el resumen ejecutivo del assessment de capacidad — responde qué está en riesgo, cuándo,
por qué, con qué confianza, y qué acción debería planearse — evitando relleno (filler). Ordena
"Top Risks" y detecta cambios respecto al assessment previo cuando exista.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`capacity/capacity-assessment` (o `capacity/capacity-healthcheck`) ejecutado.

# Required evidence

- `risk`, `forecast`, `threshold_crossing` de todos los recursos en scope.

# Optional evidence

- assessment previo (mismo target), cuando exista, para `change detection`.

# Read-only operations

Redacción local a partir de resultados ya calculados.

# Forbidden operations

Ninguna.

# Executive summary questions

Debe responder explícitamente (`# 1792`-`# 1804` del prompt de Fase 10):

```text
What is at risk?
When?
Why?
Confidence?
What action should be planned?
```

Evitar relleno — cada respuesta es concreta y basada en evidencia, nunca prosa genérica sin
sustancia.

# Capacity table

Formato sugerido (`# 1808`-`# 1815` del prompt):

```text
Resource | Current | 1M | 3M | 6M | Threshold Date | Risk | Confidence
```

# Top risks

Ordenados por: `criticality`, `time-to-threshold`, `forecast confidence`, `resource impact`
(`# 1818`-`# 1827` del prompt) — nunca un orden arbitrario.

# Change detection

Si existe un assessment previo, comparar y reportar (`# 1906`-`# 1923` del prompt):

```text
trend acceleration
risk change
threshold-date movement
capacity event
```

# Decision logic

1. Construir la tabla de capacidad con todos los recursos en scope, incluyendo los `NOT_APPLICABLE`/
   `NOT_AVAILABLE`/`PARTIALLY_SUPPORTED` explícitos (`# 1939`-`# 1957` del prompt: consistencia de
   reporte entre tecnologías).
2. Ordenar "Top Risks" por los 4 factores arriba, nunca sólo por porcentaje de utilización.
3. Si hay assessment previo disponible, ejecutar `change detection` y reportarlo en una sección
   separada — nunca mezclado silenciosamente con el estado actual sin distinguir qué cambió.
4. Responder las 5 preguntas ejecutivas de forma concreta — nunca texto de relleno.

# Normal state

Resumen ejecutivo completo, tabla de capacidad poblada, top risks ordenados correctamente.

# Abnormal patterns

Preguntas ejecutivas respondidas con generalidades sin sustento en evidencia — evitado por
diseño.

# False positives

Ninguno propio.

# Correlation rules

Consume `capacity/risk-classification`, `capacity/forecasting`, `capacity/threshold-crossing`,
`capacity/manual-capacity-plan`. Es la salida final de `capacity/capacity-assessment`.

# Confidence model

Reporta la `confidence` de cada fila de la tabla explícitamente — nunca colapsada en un resumen
sin esa columna.

# Severity

Consolidada en "Top Risks", heredada de `capacity/risk-classification`.

# Output schema

```yaml
executive_summary:
  what_is_at_risk: [string]
  when: [string]
  why: [string]
  confidence: [string]
  planned_action: [string]
  capacity_table:
    - resource: string
      current: string
      forecast_1m: string
      forecast_3m: string
      forecast_6m: string
      threshold_date: string|null
      risk: string
      confidence: string
  top_risks: [{resource: string, criticality: string, time_to_threshold: string|null, confidence: string, resource_impact: string}]
  change_detection:
    - resource: string
      change_type: trend_acceleration|risk_change|threshold_date_movement|capacity_event
      description: string
```

# Related skills

`capacity/risk-classification`, `capacity/forecasting`, `capacity/threshold-crossing`,
`capacity/manual-capacity-plan`, `capacity/capacity-assessment`.

# Escalation

Top risk `CRITICAL` escala según `collaboration.yaml` del agente.

# Manual remediation guidance

N/A directa — referencia a `capacity/manual-capacity-plan`.

# Security

Sin datos sensibles.

# Tests

Cubierto transversalmente por los tests de reproducibilidad y risk/threshold — sin test dedicado
adicional en el alcance MVP de Fase 10.

# Documentation requirements

Produce el executive summary del reporte (ver `docs/CAPACITY_REPORTING_MODEL.md`).

# Change history

v1.0.0 — Fase 10, creación inicial.

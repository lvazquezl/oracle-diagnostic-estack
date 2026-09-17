---
name: risk-classification
id: capacity/risk-classification
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Clasifica el riesgo de capacidad de un recurso — `HEALTHY|WATCH|WARNING|HIGH|CRITICAL|UNKNOWN` —
combinando utilización actual, forecast, threshold crossing, headroom, growth rate, confidence y
criticidad de negocio/HA cuando se provea. **El riesgo siempre incluye confidence explícito** —
`RISK: HIGH` + `CONFIDENCE: LOW` es un resultado válido, nunca se convierte un forecast de baja
confianza en certeza.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`capacity/forecasting`, `capacity/threshold-crossing` ejecutados para el recurso.

# Required evidence

- `forecast` y `threshold_crossing` del recurso, con sus respectivos `confidence`.

# Optional evidence

- criticidad de negocio/HA declarada explícitamente por el DBA en el Target Profile, cuando
  disponible — nunca inventada.

# Read-only operations

Cálculo local.

# Forbidden operations

Ninguna.

# Decision logic

1. Estados: `HEALTHY`, `WATCH`, `WARNING`, `HIGH`, `CRITICAL`, `UNKNOWN` (`# 1239`-`# 1250` del
   prompt de Fase 10).
2. Basar la clasificación en: `current utilization`, `forecast utilization`, `threshold
   crossing`, `headroom`, `growth rate`, `confidence`, `business/HA criticality` cuando se provea
   (`# 1252`-`# 1263` del prompt).
3. `UNKNOWN` cuando la evidencia es insuficiente para clasificar (nunca se fuerza `HEALTHY` por
   defecto ante falta de evidencia).
4. **El riesgo siempre reporta su propio `confidence`**, independiente del nivel de riesgo — un
   riesgo `HIGH`/`CRITICAL` calculado sobre un forecast de confianza `LOW` se reporta como tal,
   nunca oculto ni "mejorado" para simplificar el reporte (`# 1266`-`# 1277` del prompt).

# Normal state

`HEALTHY`/`WATCH` con `confidence: HIGH`/`MEDIUM`.

# Abnormal patterns

`HIGH`/`CRITICAL` en cualquier nivel de confianza — la severidad del riesgo y la confianza del
forecast son dimensiones independientes, ambas siempre reportadas.

# False positives

Convertir un forecast de confianza `LOW`/`INSUFFICIENT` en un riesgo `HEALTHY` por defecto (en
vez de `UNKNOWN`) es el falso positivo que este skill evita — la ausencia de evidencia nunca se
interpreta como "sano".

# Correlation rules

Consume `capacity/forecasting`, `capacity/threshold-crossing`. Alimenta
`capacity/manual-capacity-plan`, `capacity/executive-summary`, `capacity/capacity-assessment`.

# Confidence model

Reporta su propio `confidence` explícito junto al `risk` — nunca uno sin el otro.

# Severity

Este skill ES el modelo de severidad/riesgo del dominio capacity.

# Output schema

```yaml
risk:
  resource: string
  risk: HEALTHY|WATCH|WARNING|HIGH|CRITICAL|UNKNOWN
  confidence: HIGH|MEDIUM|LOW|INSUFFICIENT
  basis: [current_utilization, forecast_utilization, threshold_crossing, headroom, growth_rate, confidence, business_ha_criticality]
  evidence_refs: [EVD-...]
```

# Related skills

`capacity/forecasting`, `capacity/threshold-crossing`, `capacity/manual-capacity-plan`,
`capacity/executive-summary`.

# Escalation

`HIGH`/`CRITICAL` escala a `capacity/manual-capacity-plan`; consumo actual ya crítico (no
forecast) escala a `incident-root-cause-analyst` vía `collaboration.yaml` del agente.

# Manual remediation guidance

N/A directa — informa a `capacity/manual-capacity-plan`.

# Security

Sin datos sensibles.

# Tests

Cubierto transversalmente por `tests/test_forecast_confidence.sh` y los tests de threshold —
sin test dedicado adicional en el alcance MVP de Fase 10 más allá de los ya declarados en
secciones 77-78 del prompt.

# Documentation requirements

Alimenta `capacity-risk.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.

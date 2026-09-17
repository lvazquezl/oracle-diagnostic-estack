---
name: capacity-healthcheck
id: capacity/capacity-healthcheck
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Orquesta el flujo fijo de `/healthcheck capacity` — Target Profile → Source Inventory → Data
Quality → Normalize → Current Utilization → Trend → Forecast 1/3/6m → Threshold Crossing → Risk
→ Recommendations → Markdown.

# Supported Oracle versions

N/A directo — orquestación transversal.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

Target Profile publicado (bloque `capacity` cuando exista).

# Required evidence

- Resultado de cada paso del flujo (por referencia a los skills correspondientes).

# Optional evidence

Ninguna adicional.

# Read-only operations

Orquestación local de skills ya certificados — ninguna recolección propia.

# Forbidden operations

Ninguna — hereda todas las prohibiciones de los skills orquestados.

# Decision logic

1. Ejecutar en orden fijo (`# 1281`-`# 1313` del prompt de Fase 10):

```text
Target Profile
  ↓
capacity/data-source-inventory
  ↓
capacity/data-quality
  ↓
capacity/normalization
  ↓
capacity/cpu + capacity/memory + capacity/storage (+ capacity/oracle/asm/tablespace según scope)
  ↓
capacity/trend-analysis
  ↓
capacity/forecasting (1/3/6m)
  ↓
capacity/threshold-crossing
  ↓
capacity/risk-classification
  ↓
capacity/manual-capacity-plan
  ↓
Markdown (capacity-summary.md)
```

2. Si falta uno de los 3 recursos base (CPU/memoria/storage), el healthcheck continúa con
   `PARTIAL_CAPACITY_ASSESSMENT` — nunca bloquea el resto (`# 1407`-`# 1424` del prompt).

# Normal state

Flujo completo ejecutado con todos los pasos `SUPPORTED`/`PARTIALLY_SUPPORTED` reportados
explícitamente.

# Abnormal patterns

Cualquier paso con `data_quality: INSUFFICIENT`/`INVALID` sostenido, o riesgo `HIGH`/`CRITICAL`
detectado.

# False positives

Ninguno propio — hereda la disciplina anti-falso-positivo de cada skill orquestado.

# Correlation rules

Orquesta todos los skills `capacity/*`.

# Confidence model

Hereda el modelo de confianza de cada paso — no colapsa en un único número agregado.

# Severity

Heredada de `capacity/risk-classification` por recurso.

# Output schema

Ver `output-schema.yaml` del agente `capacity-analyst` — este skill produce el `capacity_result`
completo del flujo `/healthcheck capacity`.

# Related skills

Todos los skills `capacity/*`.

# Escalation

Riesgo `HIGH`/`CRITICAL` escala según `collaboration.yaml` del agente.

# Manual remediation guidance

Consolida las `manual_action` de `capacity/manual-capacity-plan` — siempre `NOT_EXECUTED`.

# Security

Sin datos sensibles — hereda la sanitización de cada skill orquestado.

# Tests

Cubierto transversalmente por los tests de cada skill orquestado — sin test dedicado adicional
más allá de la verificación de flujo en `docs/CAPACITY_REPORTING_MODEL.md`.

# Documentation requirements

Produce `capacity-summary.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.

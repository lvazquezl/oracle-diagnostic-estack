---
name: anomaly-awareness
id: capacity/anomaly-awareness
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Detecta cambios estructurales en una serie de capacidad — step changes, spikes, drops, reset de
fuente, eventos de resize de capacidad — y produce el modelo de segmentación que
`capacity/trend-analysis`/`capacity/forecasting` usan para nunca tratar datos pre/post-evento
como una sola serie continua sin awareness.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`capacity/normalization` ejecutado para la serie.

# Required evidence

- serie normalizada del recurso.

# Optional evidence

- eventos de cambio de capacidad declarados explícitamente por el DBA (ej. "el datastore se
  amplió el 15 de marzo"), cuando disponibles — nunca inventados si no hay evidencia.

# Read-only operations

Cálculo local (detección estadística de cambios estructurales).

# Forbidden operations

Ninguna.

# Decision logic

1. Detectar: `step changes` (cambio abrupto y sostenido del nivel de la serie), `spikes` (pico
   transitorio que vuelve al nivel previo), `drops` (caída transitoria), `source reset` (la serie
   reinicia su base, típico de un cambio de collector/fuente), `capacity resize event` (el
   `total_capacity` mismo cambió) (`# 1110`-`# 1122` del prompt de Fase 10).
2. Un `capacity resize event` se modela explícitamente:

```yaml
capacity_event:
  timestamp: string
  resource: string
  event_type: string
  old_total: number|null
  new_total: number|null
  source: string
  evidence_id: string
```

   Ejemplos: incremento de CPU de VM, incremento de memoria, extensión de filesystem, disco
   agregado a ASM, expansión de datastore (`# 1126`-`# 1149` del prompt) — **sólo detección,
   nunca ejecución**.

3. Segmented forecast: si existe un `capacity_event` significativo, segmentar la serie temporal y
   usar preferentemente los datos posteriores al último cambio estructural para
   `capacity/trend-analysis`/`capacity/forecasting` (`# 1155`-`# 1163` del prompt) — nunca
   mezclar el `total_capacity` anterior y posterior como si fueran la misma capacidad base.

# Normal state

Sin eventos detectados, o eventos detectados y correctamente segmentados en el forecast
resultante.

# Abnormal patterns

`capacity_event` detectado pero no reflejado en la segmentación del forecast — este es el defecto
que este skill existe para prevenir, nunca debería ocurrir si `capacity/forecasting` consume
correctamente su salida.

# False positives

Un spike/drop transitorio aislado no es un `capacity_event` — sólo un `step change` sostenido en
`total_capacity` o `used_capacity` califica.

# Correlation rules

Alimenta `capacity/trend-analysis`, `capacity/forecasting`, `capacity/data-quality`.

# Confidence model

`FACT` para eventos confirmados por cambio de `total_capacity` reportado por la fuente;
`OBSERVATION` para step changes/spikes detectados estadísticamente sin confirmación de causa.

# Severity

N/A directa — informativo para el modelo de segmentación, no un hallazgo de capacidad por sí
mismo.

# Output schema

```yaml
capacity_events:
  - timestamp: string
    resource: string
    event_type: step_change|spike|drop|source_reset|capacity_resize
    old_total: number|null
    new_total: number|null
    source: string
    evidence_id: string
```

# Related skills

`capacity/trend-analysis`, `capacity/forecasting`, `capacity/data-quality`.

# Escalation

Ninguna directa — alimenta el modelo de segmentación de otros skills.

# Manual remediation guidance

N/A directa.

# Security

Sin datos sensibles.

# Tests

`tests/test_capacity_resize_segmentation.sh`.

# Documentation requirements

Alimenta `capacity-forecast.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.

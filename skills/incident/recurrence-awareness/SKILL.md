---
name: recurrence-awareness
id: incident/recurrence-awareness
version: 1.0.0
domain: incident
status: active
---

# Purpose

Detecta si un patrón de incidente/error es primera ocurrencia, recurrente, o presenta un patrón
específico (`# 968`-`# 983` del prompt de Fase 11) — `UNKNOWN` cuando no hay historial disponible,
nunca asumido "primera vez" por defecto sin verificar.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/known-error-correlation` ejecutado (para comparar contra error signatures previos, si
existe historial local).

# Required evidence

- `error_signatures` del incidente actual.

# Optional evidence

- Historial de incidentes previos del mismo target, cuando el e-stack tiene acceso a ese registro
  local (`analysis/ANA-*`/`incident/INC-*` previos).

# Read-only operations

Cálculo local (comparación de firmas).

# Forbidden operations

Nunca asume `first_occurrence` sin verificar contra el historial disponible.

# Decision logic

1. Comparar la(s) `error_signature`(s) del incidente actual contra incidentes previos conocidos
   localmente (si existen).
2. Clasificar: `first_occurrence` (sin coincidencia previa), `recurrent` (coincidencia exacta
   repetida), `patterned` (variación del mismo patrón subyacente, no idéntica), `unknown` (sin
   historial disponible para comparar) (`# 972`-`# 977` del prompt).
3. Sin historial (`no history`), el resultado es `UNKNOWN` explícito — nunca `first_occurrence`
   asumido por defecto (`# 979`-`# 983` del prompt).

# Normal state

Clasificación de recurrencia con trazabilidad al historial comparado (o `UNKNOWN` explícito si no
hay historial).

# Abnormal patterns

`recurrent`/`patterned` con alta frecuencia — señal fuerte para `incident/lessons-learned` sobre
una causa raíz no resuelta permanentemente en incidentes previos.

# False positives

Asumir `first_occurrence` simplemente porque el e-stack no tiene memoria de incidentes previos
(en vez de declarar `UNKNOWN`) es el falso positivo que este skill evita.

# Correlation rules

Consume `incident/known-error-correlation`. Alimenta `incident/lessons-learned`,
`incident/post-incident-review`.

# Confidence model

`FACT` para la comparación cuando hay historial disponible; `UNKNOWN` sin él.

# Severity

N/A directa.

# Output schema

```yaml
recurrence: first_occurrence|recurrent|patterned|unknown
compared_against: [string]
```

# Related skills

`incident/known-error-correlation`, `incident/lessons-learned`.

# Escalation

Recurrencia confirmada de un patrón ya documentado escala como hallazgo para
`incident/post-incident-review` ("what did not work" en la remediación previa).

# Manual remediation guidance

N/A directa.

# Security

Sin datos sensibles adicionales.

# Tests

Cubierto transversalmente por `tests/test_incident_root_cause.sh` y los tests de playbooks —
sin test dedicado adicional en el alcance MVP de Fase 11.

# Documentation requirements

Alimenta `incident-lessons-learned.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.

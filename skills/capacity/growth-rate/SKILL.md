---
name: growth-rate
id: capacity/growth-rate
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Calcula la tasa de crecimiento de un recurso de capacidad — absoluta, porcentual, por día, por
mes — a partir de la serie normalizada y segmentada por `capacity/trend-analysis`. Nunca infiere
crecimiento desde sólo dos puntos si la política de forecasting requiere más evidencia.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`capacity/trend-analysis` ejecutado para el recurso.

# Required evidence

- serie normalizada/segmentada del recurso con `slope`/`baseline_statistics` ya calculados.

# Optional evidence

Ninguna.

# Read-only operations

Cálculo local.

# Forbidden operations

Ninguna.

# Decision logic

1. Calcular `absolute growth` (delta en unidades del recurso), `percentage growth`, `growth per
   day`, `growth per month` (`# 814`-`# 823` del prompt de Fase 10).
2. **Nunca inferir growth rate desde sólo dos puntos** cuando
   `capacity.forecasting.minimum_samples` de la política lo exija — en ese caso, `growth_rate:
   INSUFFICIENT_EVIDENCE`, nunca una extrapolación de dos puntos presentada como tendencia
   confiable (`# 825` del prompt).
3. El growth rate calculado alimenta directamente `capacity/forecasting` como uno de los factores
   de selección de método (junto con longitud de histórico, volatilidad, estacionalidad, calidad
   de datos, presencia de outliers).

# Normal state

`growth_rate` calculado con evidencia suficiente (≥ `minimum_samples`), consistente con la
clasificación de `capacity/trend-analysis`.

# Abnormal patterns

`growth_rate` alto sostenido en un recurso con threshold cercano — correlacionado directamente con
`capacity/threshold-crossing`.

# False positives

Un growth rate calculado sobre dos puntos aislados (ej. una lectura antes y una después de un
evento atípico) es el falso positivo que este skill evita explícitamente.

# Correlation rules

Alimenta `capacity/forecasting`, `capacity/threshold-crossing`.

# Confidence model

Hereda `capacity/confidence`.

# Severity

N/A directa.

# Output schema

```yaml
growth_rate:
  resource: string
  absolute_growth: number|null
  percentage_growth: number|null
  growth_per_day: number|null
  growth_per_month: number|null
  samples_used: int|null
  insufficient_evidence: bool
  evidence_refs: [EVD-...]
```

# Related skills

`capacity/trend-analysis`, `capacity/forecasting`, `capacity/threshold-crossing`.

# Escalation

`insufficient_evidence: true` sostenido escala como limitación explícita.

# Manual remediation guidance

N/A directa.

# Security

Sin datos sensibles.

# Tests

`tests/test_capacity_storage_growth.sh`.

# Documentation requirements

Alimenta `capacity-forecast.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.

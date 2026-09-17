---
name: trend-analysis
id: capacity/trend-analysis
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Clasifica la tendencia de una serie de capacidad normalizada — `INCREASING`/`DECREASING`/
`STABLE`/`VOLATILE`/`UNKNOWN` — con `slope`, `normalized growth rate` y `confidence` explícitos.
Calcula estadísticas baseline (mean/median/min/max/p95/desviación estándar/growth rate) como
insumo para `capacity/forecasting`.

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas — opera sobre series numéricas normalizadas.

# Supported architectures

Todas.

# Prerequisites

`capacity/normalization` y `capacity/data-quality` ejecutados para el recurso — `data_quality`
debe ser al menos `ACCEPTABLE` para clasificar tendencia con confianza distinta de `INSUFFICIENT`.

# Required evidence

- serie normalizada de `capacity_metric` para el recurso, con `data_quality.status` conocido.

# Optional evidence

- `capacity_event`(s) detectados por `capacity/anomaly-awareness` — usados para segmentar la
  serie antes de calcular tendencia (ver "Decision logic").

# Read-only operations

Cálculo local (Python/runtime) sobre la serie ya normalizada.

# Forbidden operations

Ninguna.

# Baseline statistics

Calcular como mínimo, según aplicabilidad: `mean`, `median`, `min`, `max`, `p95`, `standard
deviation`, `growth rate` (`# 774`-`# 789` del prompt de Fase 10).

# Decision logic

1. Si existe un `capacity_event` (resize) dentro de la ventana evaluada, segmentar la serie y usar
   preferentemente los datos posteriores al último cambio estructural (ver
   `capacity/anomaly-awareness#segmented-forecast`) — nunca tratar datos pre/post-resize como una
   sola serie sin awareness.
2. Calcular `slope` (regresión simple sobre la serie segmentada) y `normalized growth rate`
   (crecimiento normalizado por unidad de tiempo, comparable entre recursos de distinta escala).
3. Clasificar: `INCREASING` (slope positivo, significativo), `DECREASING` (slope negativo,
   significativo), `STABLE` (slope no significativo), `VOLATILE` (alta desviación estándar
   relativa al rango, sin tendencia clara), `UNKNOWN` (datos insuficientes o `data_quality:
   INSUFFICIENT`/`INVALID`).
4. `confidence` de la clasificación sigue el modelo de `capacity/confidence` — nunca un número
   aislado.
5. Awareness de estacionalidad (semanal/mensual/business-cycle) se delega a
   `capacity/seasonality-awareness` — este skill nunca promete un modelo estacional avanzado por
   su cuenta.

# Normal state

Tendencia clasificada con `confidence: HIGH`/`MEDIUM` y estadísticas baseline completas.

# Abnormal patterns

`VOLATILE` sostenido, o `INCREASING` con `normalized growth rate` alto en un recurso con threshold
cercano.

# False positives

Clasificar `INCREASING`/`DECREASING` a partir de una serie con outliers no excluidos/no marcados
es el falso positivo que este skill evita — ver `capacity/anomaly-awareness` para el tratamiento
de outliers antes del ajuste.

# Correlation rules

Alimenta `capacity/growth-rate`, `capacity/forecasting`, `capacity/seasonality-awareness`,
`capacity/risk-classification`.

# Confidence model

Hereda `capacity/confidence` — `HIGH|MEDIUM|LOW|INSUFFICIENT`.

# Severity

N/A directa — la tendencia en sí no es un hallazgo de severidad hasta correlacionarse con
threshold/forecast.

# Output schema

```yaml
trend:
  resource: string
  classification: INCREASING|DECREASING|STABLE|VOLATILE|UNKNOWN
  slope: number|null
  normalized_growth_rate: number|null
  confidence: HIGH|MEDIUM|LOW|INSUFFICIENT
  baseline_statistics: {mean: number|null, median: number|null, min: number|null, max: number|null, p95: number|null, stddev: number|null}
  segmented: bool
  evidence_refs: [EVD-...]
```

# Related skills

`capacity/growth-rate`, `capacity/forecasting`, `capacity/anomaly-awareness`,
`capacity/seasonality-awareness`, `capacity/confidence`.

# Escalation

`VOLATILE`/`UNKNOWN` sostenido escala como limitación explícita a `capacity/forecasting` (método
seleccionado se ajusta en consecuencia).

# Manual remediation guidance

N/A directa.

# Security

Sin datos sensibles.

# Tests

`tests/test_capacity_cpu_trend.sh`, `tests/test_capacity_memory_trend.sh`,
`tests/test_capacity_storage_growth.sh`.

# Documentation requirements

Alimenta `capacity-forecast.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.

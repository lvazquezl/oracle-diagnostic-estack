---
name: data-quality
id: capacity/data-quality
version: 1.0.0
domain: capacity
status: active
---

# Purpose

Evalúa la calidad de cada serie de capacidad antes de calcular tendencia/forecast — consistencia
de intervalo de muestreo, samples faltantes, samples duplicados, outliers, consistencia de
reloj/timezone, cambios de fuente. Nunca se produce un forecast si el dataset no cumple el mínimo
de calidad (`# 695`-`# 708` del prompt de Fase 10).

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas — la evaluación de calidad opera sobre series numéricas normalizadas.

# Supported architectures

Todas.

# Prerequisites

`capacity/data-source-inventory` ya ejecutado; `capacity/normalization` para la serie en cuestión.

# Required evidence

- serie normalizada del recurso (vía `capacity/normalization`)

# Optional evidence

- historial de cambios de fuente/collector para ese recurso, cuando esté disponible.

# Read-only operations

Cálculo local sobre datos ya normalizados — ninguna lectura adicional de fuente.

# Forbidden operations

Ninguna — este skill sólo evalúa, nunca modifica la serie ni la fuente.

# Decision logic

1. Evaluar `sampling interval consistency` — intervalos irregulares degradan calidad.
2. Contar `missing samples`/`duplicate samples` dentro de la ventana evaluada.
3. Detectar `outliers` (ver `capacity/anomaly-awareness` para clasificación detallada) — su sola
   presencia no invalida el dataset, pero se refleja en `outlier_ratio`.
4. Verificar `clock/timezone consistency` — timestamps sin offset normalizado degradan a
   `DEGRADED` como mínimo.
5. Detectar `source changes` dentro de la ventana — un cambio de fuente/collector sin
   normalización explícita degrada la calidad y puede requerir segmentación (ver
   `capacity/anomaly-awareness`).
6. Asignar `status`: `GOOD` (cobertura alta, sin gaps significativos, sin cambios de fuente),
   `ACCEPTABLE` (gaps menores, dentro de tolerancia), `DEGRADED` (gaps significativos o
   inconsistencia de timezone/muestreo), `INSUFFICIENT` (por debajo del mínimo de historia/samples
   configurado en `capacity.forecasting.minimum_samples`/`minimum_history_days`), `INVALID`
   (datos corruptos/no interpretables).
7. `INSUFFICIENT`/`INVALID` bloquean el forecast para ese recurso específico — nunca el resto del
   reporte (`PARTIAL_CAPACITY_ASSESSMENT`).

# Normal state

`status: GOOD`/`ACCEPTABLE` con `coverage` alto y `outlier_ratio` bajo.

# Abnormal patterns

`status: DEGRADED`/`INSUFFICIENT`/`INVALID` — reportado explícitamente, nunca oculto ni
compensado silenciosamente con un forecast igualmente confiado.

# False positives

Un único outlier aislado no degrada la calidad por sí solo — sólo una proporción significativa
(`outlier_ratio` alto) o un patrón sostenido.

# Correlation rules

Alimenta `capacity/trend-analysis`, `capacity/forecasting`, `capacity/confidence`.

# Confidence model

`FACT` para las métricas de calidad calculadas directamente sobre la serie.

# Severity

Informativo — la calidad de datos no es un "hallazgo" de capacidad per se, pero condiciona la
`confidence` de todo lo que dependa de ella.

# Output schema

```yaml
data_quality:
  - metric: string
    status: GOOD|ACCEPTABLE|DEGRADED|INSUFFICIENT|INVALID
    coverage: number|null
    freshness_hours: number|null
    consistency: number|null
    missingness_pct: number|null
    outlier_ratio: number|null
    source_reliability: string|null
```

`coverage`/`freshness`/`consistency`/`missingness`/`outlier_ratio`/`source_reliability` (`# 726`-
`# 739` del prompt) se exponen siempre — nunca se oculta el scoring.

# Related skills

`capacity/normalization`, `capacity/anomaly-awareness`, `capacity/trend-analysis`,
`capacity/forecasting`, `capacity/confidence`.

# Escalation

`status: INVALID` sostenido escala como limitación a `capacity/capacity-assessment` — nunca se
silencia.

# Manual remediation guidance

`manual_action` sugiere revisar la configuración de muestreo/retención de la fuente — siempre
`NOT_EXECUTED`, dirigida al owner de la herramienta de monitoreo.

# Security

Sin datos sensibles — sólo metadata de calidad de serie.

# Tests

`tests/test_capacity_missing_samples.sh`, `tests/test_capacity_duplicate_samples.sh`,
`tests/test_capacity_timezone_normalization.sh`, `tests/test_capacity_sampling_consistency.sh`,
`tests/test_capacity_insufficient_history.sh`, `tests/test_capacity_data_quality_status.sh`.

# Documentation requirements

Alimenta `capacity-data-quality.md`.

# Change history

v1.0.0 — Fase 10, creación inicial.

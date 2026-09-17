# Capacity Data Quality Model — Fase 10

## Principio

No se produce un forecast si el dataset no cumple el mínimo de calidad (`# 695`-`# 708` del
prompt de Fase 10).

## Dimensiones evaluadas

```text
sampling interval consistency
missing samples
duplicate samples
outliers
clock/timezone consistency
source changes
```

## Estados

```text
GOOD
ACCEPTABLE
DEGRADED
INSUFFICIENT
INVALID
```

## Score (opcional, nunca oculto)

```text
coverage
freshness
consistency
missingness
outlier_ratio
source_reliability
```

`# 726`-`# 739` del prompt: el scoring, cuando se calcula, nunca se oculta.

## Time normalization

Toda serie normaliza `timezone`/`timestamp`/`sampling interval` — nunca se mezclan timestamps
locales sin offset (`# 743`-`# 753` del prompt).

## Aggregation

```text
hourly
daily
weekly
monthly
```

según horizonte — nunca se hace forecast sobre puntos demasiado ruidosos si la agregación
recomendada es diaria (`# 757`-`# 770` del prompt).

## History requirements

```yaml
forecasting:
  minimum_samples:
  minimum_history_days:
  preferred_history_days:
```

Ejemplo recomendado, **no universal**: `minimum history: 30 days`, `preferred: 90+ days`
(`# 671`-`# 692` del prompt) — configurable en el Target Profile, nunca hardcodeado sin policy.

## Implementación ejecutable

**PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING**: `capacity_engine/quality.py`
implementa `assess_quality()` — calcula `coverage`, `missingness_pct`, `gap_count`,
`duplicate_count`, `independent_observations` (días distintos, nunca conteo de muestras crudas —
ver `capacity_engine/aggregation.py`) y `outlier_days` (regla MAD robusta —
`capacity_engine/stats.py#robust_outliers`, umbral configurable `outlier_mad_threshold`, default
documentado 3.5, nunca forzado). `minimum_samples`/`minimum_history_days`/`preferred_history_days`
son claves de policy opcionales — un gate ausente simplemente no se aplica, nunca un default
universal implícito. Ejercitado numéricamente por `tests/test_capacity_engine_insufficient_history.sh`
y `tests/test_capacity_engine_missing_irregular_duplicates.sh` (LOCAL_RUNTIME_TESTED).

## Referencias

`skills/capacity/data-quality/SKILL.md`, `docs/CAPACITY_FORECASTING_MODEL.md`.

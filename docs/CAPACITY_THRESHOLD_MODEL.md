# Capacity Threshold Model — Fase 10

## Threshold configurable (Target Profile)

```yaml
capacity:
  warning_percent:
  critical_percent:
  emergency_percent:
```

Nunca se impone universalmente `80/90/95`, aunque puedan ofrecerse como ejemplo (`# 997`-`# 1014`
del prompt de Fase 10).

## Threshold crossing date

Estados:

```text
DATE_ESTIMATED
NOT_EXPECTED_WITHIN_HORIZON
ALREADY_EXCEEDED
INSUFFICIENT_EVIDENCE
NON_MONOTONIC
```

## Saturation / exhaustion date

Para recursos de crecimiento acumulativo (disk, ASM, tablespace, FRA) — **nunca aplicado
automáticamente a CPU** (`# 1038`-`# 1056` del prompt).

## CPU forecast semantics

CPU es utilización, no un recurso consumido acumulativamente. Nunca "days until CPU exhausted".
Preferir `threshold crossing probability/date`, `sustained utilization risk` (`# 1059`-`# 1074`
del prompt).

## Memory forecast semantics

Distinguir `allocated capacity growth`, `working usage trend`, `Oracle configured memory growth`
— nunca extrapolar memoria de cache sin sentido (`# 1078`-`# 1088` del prompt).

## Storage forecast semantics

Storage sí puede modelarse acumulativamente cuando `used capacity` crece sostenidamente —
priorizar growth rate, threshold crossing, exhaustion date (`# 1092`-`# 1106` del prompt).

## Implementación ejecutable

**PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING**: `capacity_engine/threshold.py`
implementa `evaluate_threshold()` — resuelve matemáticamente `x_cross = (threshold_percent -
intercept) / slope` sobre el ajuste OLS de la serie diaria de `utilization_percent` (nunca sobre
una serie absoluta con denominador variable; la segmentación por resize —
`capacity_engine/segmentation.py` — garantiza que `total_capacity` sea estable dentro del segmento
analizado). CPU (`resource_type == "cpu"`) recibe el mismo cálculo de cruce de umbral pero
`ForecastResult` nunca expone un campo `exhaustion_date`/`saturation_date` para ese recurso —
verificado estructuralmente por `tests/test_capacity_engine_cpu_semantics.sh` (recorre el `dict`
completo del resultado buscando esas claves). Ejercitado con fórmula exacta conocida por
`tests/test_capacity_engine_threshold_crossing.sh` (LOCAL_RUNTIME_TESTED).

## Referencias

`skills/capacity/threshold-crossing/SKILL.md`, `skills/capacity/risk-classification/SKILL.md`,
`docs/PHASE_10_FORECASTING_EXECUTION_NUMERICAL_VALIDATION_HARDENING.md`.

## Capacity Risk Model

Estados: `HEALTHY`, `WATCH`, `WARNING`, `HIGH`, `CRITICAL`, `UNKNOWN`. Basado en: utilización
actual, forecast, threshold crossing, headroom, growth rate, confidence, criticidad de negocio/HA
si se provee (`# 1239`-`# 1263` del prompt). **El riesgo siempre incluye confidence** — `RISK:
HIGH` + `CONFIDENCE: LOW` es válido, nunca se convierte un forecast de baja confianza en certeza
(`# 1266`-`# 1277` del prompt).

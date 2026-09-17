# Capacity Forecasting Model — Fase 10

## Principio

Los forecasts deben incluir confidence y data-quality status. No se produce forecast desde
historia insuficiente sin una limitación explícita (`# 52`-`# 54` del prompt de Fase 10).

## Métodos

```text
linear regression
robust linear regression (cuando el runtime/librería lo permita)
moving average
exponential smoothing (cuando esté justificado)
```

Sin ML complejo sin necesidad (`# 829`-`# 840` del prompt).

## Método por defecto (MVP)

`linear trend over normalized daily aggregates`, con `confidence`, `R²`/bondad de ajuste
equivalente, y análisis de residuales (`# 861`-`# 877` del prompt). Fusiona la lógica original de
`capacity/forecast.md` (Foundation): regresión lineal simple sobre la serie vs. tiempo.

## Selección de método

Según: longitud de histórico, fuerza de tendencia, volatilidad, estacionalidad, calidad de datos,
presencia de outliers — nunca siempre regresión lineal (`# 844`-`# 857` del prompt).

## Robustez ante outliers

Detectar, marcar, comparar. Nunca eliminar silenciosamente. Si se excluyen del ajuste, registrar
la regla de exclusión (`# 881`-`# 897` del prompt).

## Horizontes obligatorios

```text
FORECAST_1M
FORECAST_3M
FORECAST_6M
```

Parten siempre del último dato válido (`# 924`-`# 935` del prompt).

## Output

```yaml
forecast:
  metric:
  method:
  forecast_contract_version:
  history_start:
  history_end:
  samples:
  horizon_1m: {expected:, lower:, upper:}
  horizon_3m: {expected:, lower:, upper:}
  horizon_6m: {expected:, lower:, upper:}
  fit_quality:
  confidence:
  limitations:
  algorithm_version:
  input_evidence_ids:
  time_window:
  excluded_samples:
  generated_at:
```

## Confidence

Estados mínimos: `HIGH`, `MEDIUM`, `LOW`, `INSUFFICIENT` — nunca sólo un número sin explicación
(`# 968`-`# 979` del prompt).

## Forecast intervals

`lower`/`expected`/`upper` cuando sea técnicamente viable — nunca se presenta un forecast puntual
como certeza (`# 983`-`# 994` del prompt).

## Semántica por tipo de recurso

Ver `docs/CAPACITY_THRESHOLD_MODEL.md#cpu-memory-storage-forecast-semantics` — CPU nunca usa
"días hasta agotar"; memoria distingue allocated growth de working usage trend; storage sí puede
modelarse acumulativamente.

## Anomaly awareness / capacity change events

Ver `skills/capacity/anomaly-awareness/SKILL.md` — step changes, spikes, drops, source reset,
capacity resize event; `capacity_event` sólo detección, nunca ejecución. Series segmentadas tras
un cambio estructural, usando preferentemente datos posteriores (`# 1109`-`# 1163` del prompt).

## Seasonality

Estados: `NOT_DETECTED`, `POSSIBLE`, `DETECTED`, `INSUFFICIENT_HISTORY` — sin modelos estacionales
avanzados prometidos en MVP sin historia suficiente (`# 901`-`# 921` del prompt).

## Reproducibility

Cada forecast registra `algorithm_version`, `input evidence IDs`, `time window`, `aggregation`,
`excluded samples`, `threshold policy`, `generated_at` (`# 1527`-`# 1539` del prompt).
`forecast_contract_version` evita que cambios matemáticos alteren reportes sin trazabilidad
(`# 1543`-`# 1551` del prompt).

## Local computation / token optimization

```text
raw series
   ↓
local aggregation
   ↓
statistics
   ↓
forecast result
   ↓
top anomalies
   ↓
evidence refs
   ↓
LLM interpretation
```

Nunca se envían millones de datapoints al modelo (`# 1456`-`# 1500` del prompt).

## Motor local ejecutable (`capacity_engine/`)

**PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING**: el modelo de arriba deja de
ser sólo un contrato declarativo — `capacity_engine/` (Python 3, sólo stdlib) implementa el
pipeline completo de forma ejecutable y determinista:

```text
capacity_engine/
  common.py          # enums, dataclasses, ForecastResult (implementa el Output de arriba 1:1)
  normalization.py   # validación de esquema/unidades/tiempo, GB decimal vs GiB binario
  quality.py         # coverage/freshness/missingness/gaps/outliers -> GOOD|ACCEPTABLE|DEGRADED|INSUFFICIENT|INVALID
  segmentation.py     # detección de capacity_resize + segmentación post-evento
  aggregation.py      # agregación diaria determinista (mean/p95/peak), x = day_offset entero
  stats.py            # OLS puro, intervalo de predicción (aproximación normal), aritmética de meses calendario
  trend.py            # clasificación INCREASING|DECREASING|STABLE|VOLATILE|UNKNOWN + exclusión de outliers del ajuste
  threshold.py         # ALREADY_EXCEEDED|DATE_ESTIMATED|NOT_EXPECTED_WITHIN_HORIZON|NON_MONOTONIC|INSUFFICIENT_EVIDENCE|INVALID_THRESHOLD
  reconciliation.py    # SOURCE_CONFLICT entre dos fuentes, nunca promedio ciego
  engine.py            # orquestador: run_capacity_forecast(raw_samples, policy, thresholds, as_of)
  report.py            # tabla de capacidad Markdown (docs/CAPACITY_REPORTING_MODEL.md) desde un ForecastResult real
  cli.py                # adaptador local invocable: python3 -m capacity_engine.cli --fixture ... --policy ...
```

`run_capacity_forecast()` es la API programática estable — determinista, sin LLM/MCP/red/Oracle.
El origen del forecast es siempre `history_end` (el último timestamp válido de la serie), nunca el
reloj de pared; `as_of` sólo afecta metadata de auditoría (`freshness_hours`/`generated_at`), nunca
el cálculo. Ver `docs/PHASE_10_FORECASTING_EXECUTION_NUMERICAL_VALIDATION_HARDENING.md` para el
mapa completo contrato↔código y la evidencia de los 18 tests numéricos que lo ejercitan
(`tests/test_capacity_engine_*.sh`, más `test_forecast_linear_growth.sh`/
`test_forecast_reproducible_same_input.sh` endurecidos).

**Interval method**: los intervalos `lower/upper` usan una aproximación normal (z≈1.96) a la
distribución t de Student — documentado explícitamente en `method_parameters.interval_method` y
`diagnostics.interval_note` de cada `ForecastResult`, nunca presentado como un intervalo t exacto
(no hay dependencia a scipy). Con `n<=2` el intervalo es `NOT_ESTIMABLE` (`lower`/`upper` en
`null`), nunca un número inventado.

**Runtime status**: `capacity_engine` es `LOCAL_RUNTIME_TESTED` (ejecutado directamente por los
tests numéricos, sin mocks). Los entrypoints `/healthcheck capacity`/`/assessment capacity`
descritos en `docs/PHASE_10_CAPACITY_MANAGEMENT_FORECASTING.md` siguen siendo `CONTRACT_ONLY` /
`NOT_RUNTIME_CERTIFIED` — la orquestación de un agente vivo depende del MCP Gateway (fase
posterior); `capacity_engine.cli` es el adaptador local que demuestra el recorrido completo
fixture→motor→resultado→reporte sin ese runtime.

## Referencias

`skills/capacity/forecasting/SKILL.md`, `skills/capacity/trend-analysis/SKILL.md`,
`skills/capacity/growth-rate/SKILL.md`, `skills/capacity/confidence/SKILL.md`,
`docs/CAPACITY_THRESHOLD_MODEL.md`,
`docs/PHASE_10_FORECASTING_EXECUTION_NUMERICAL_VALIDATION_HARDENING.md`.

---
name: forecasting
id: capacity/forecasting
version: 2.0.0
domain: capacity
status: active
---

# Purpose

Proyecta un recurso de capacidad a los horizontes obligatorios de 1/3/6 meses a partir de la
tendencia histórica (`capacity/trend-analysis`), seleccionando un método simple, auditable y
robusto, y declarando siempre `confidence`/`data_quality`/`limitations` explícitos — un forecast
nunca se presenta como certeza. **PHASE 10 — CAPACITY MANAGEMENT & FORECASTING**: skill autoridad
del forecasting reproducible — funde y reemplaza `skills/capacity/forecast.md` (Foundation, único
skill activo del dominio antes de esta fase); su lógica de regresión lineal simple y umbrales de
riesgo por headroom se preserva como el método MVP por defecto, extendida con selección de método,
robustez ante outliers, intervalos de confianza y reproducibilidad completa.

# Supported Oracle versions

N/A directo — opera sobre series de tiempo ya normalizadas, agnóstico de versión Oracle
específica.

# Supported OS/platforms

Todas — el forecast es un cálculo sobre series numéricas normalizadas.

# Supported architectures

Todas (heredan el alcance del recurso que se proyecta).

# Prerequisites

`capacity/trend-analysis`, `capacity/growth-rate`, `capacity/data-quality` ejecutados para el
recurso.

# Required evidence

- serie normalizada/segmentada del recurso, con `data_quality.status` y `trend.classification`
  ya calculados.

# Optional evidence

- `capacity_event`(s) de `capacity/anomaly-awareness` para segmentación; awareness de
  estacionalidad de `capacity/seasonality-awareness`.

# Read-only operations

Todo el cálculo (normalización, agregación, regresión, intervalos de confianza) se ejecuta
localmente (Python/runtime) — nunca se envían series completas al modelo (`# 1456`-`# 1476` del
prompt de Fase 10).

# Forbidden operations

Ninguna — el forecast nunca modifica ni recomienda una ampliación automática, sólo el número
proyectado y el riesgo asociado.

# History requirements

```yaml
forecasting:
  minimum_samples: int          # configurable, ejemplo recomendado 30 días, NO universal
  minimum_history_days: int
  preferred_history_days: int   # ejemplo recomendado 90+, NO universal
```

Sin `minimum_samples`/`minimum_history_days` cumplidos, el forecast para ese recurso es
`confidence: INSUFFICIENT` — nunca se produce un forecast sin esa limitación declarada
explícitamente (`# 671`-`# 692`, `# 54` del prompt: "no forecast from insufficient history
without explicit limitation").

# Forecasting methods

Métodos iniciales, simples y auditables:

```text
linear regression
robust linear regression (cuando el runtime/librería lo permita)
moving average
exponential smoothing (cuando esté justificado)
```

Nada de ML complejo sin necesidad real (`# 829`-`# 840` del prompt).

# Method selection

El método se selecciona según: longitud de histórico, fuerza de la tendencia, volatilidad,
estacionalidad, calidad de datos, presencia de outliers — **nunca se usa siempre regresión
lineal** por defecto sin considerar estos factores (`# 844`-`# 857` del prompt).

# Default MVP forecast method

Para el MVP, el método principal es **regresión lineal sobre agregados diarios normalizados**
(heredado directamente de la lógica original de `capacity/forecast.md`: ajustar una tendencia
lineal simple sobre `used_pct`/valor absoluto vs. tiempo), con:

```text
confidence
R² (o bondad de ajuste equivalente)
residual analysis
```

siempre que la serie sea apropiada para ese método (`# 861`-`# 877` del prompt).

# Robustness

Si existen outliers: detectar, marcar (`flag`), comparar — **nunca eliminarlos silenciosamente**.
Si se excluyen del ajuste, registrar la regla de exclusión explícitamente en `excluded_samples`
(`# 881`-`# 897` del prompt).

# Decision logic

1. Verificar `history requirements` — si no se cumplen, `confidence: INSUFFICIENT`, forecast no
   se calcula, limitación declarada explícitamente.
2. Seleccionar método según "Method selection" arriba.
3. Ajustar el método seleccionado sobre la serie segmentada (post-último `capacity_event`
   relevante, ver `capacity/anomaly-awareness#segmented-forecast`).
4. Proyectar el valor esperado a los horizontes `1m`/`3m`/`6m`, partiendo siempre del último dato
   válido (`# 924`-`# 935` del prompt) — nunca desde un punto arbitrario intermedio.
5. Calcular intervalos de confianza (`lower`/`expected`/`upper`) cuando sea técnicamente viable —
   nunca presentar sólo el valor esperado como si fuera certeza (`# 983`-`# 994` del prompt).
6. Declarar `confidence`: `HIGH`/`MEDIUM`/`LOW`/`INSUFFICIENT` (hereda `capacity/confidence`).
7. Registrar reproducibilidad completa: `algorithm_version`, `input_evidence_ids`, `time_window`,
   `aggregation`, `excluded_samples`, `threshold_policy` (referenciada, no copiada), `generated_at`
   (`# 1527`-`# 1539` del prompt) — bajo un `forecast_contract_version` propio que evita que
   cambios matemáticos alteren reportes previos sin trazabilidad (`# 1543`-`# 1551`).

# Normal state

Forecast calculado con `confidence: HIGH`/`MEDIUM`, intervalos razonables, `fit_quality`
aceptable para el método usado.

# Abnormal patterns

`confidence: LOW`/`INSUFFICIENT` sostenida; residuales altos indicando mal ajuste del método
seleccionado (correlaciona con `capacity/trend-analysis#volatile`).

# False positives

Presentar un forecast puntual sin intervalo ni confianza como si fuera un valor cierto es el
falso positivo que este skill evita explícitamente en todo momento.

# Correlation rules

Consume `capacity/trend-analysis`, `capacity/growth-rate`, `capacity/data-quality`,
`capacity/anomaly-awareness`, `capacity/seasonality-awareness`. Alimenta
`capacity/threshold-crossing`, `capacity/risk-classification`, `capacity/capacity-assessment`.

# Confidence model

Hereda `capacity/confidence` — `HIGH|MEDIUM|LOW|INSUFFICIENT`. El forecast en sí nunca declara
`CONFIRMED_ROOT_CAUSE` (una proyección no es una causa).

# Severity

N/A directa — la severidad la determina `capacity/risk-classification` combinando forecast +
threshold + confidence.

# Output schema

```yaml
forecast:
  metric: string
  method: linear_regression|robust_linear_regression|moving_average|exponential_smoothing
  forecast_contract_version: string
  history_start: string|null
  history_end: string|null
  samples: int|null
  horizon_1m: {expected: number|null, lower: number|null, upper: number|null}
  horizon_3m: {expected: number|null, lower: number|null, upper: number|null}
  horizon_6m: {expected: number|null, lower: number|null, upper: number|null}
  fit_quality: number|null
  confidence: HIGH|MEDIUM|LOW|INSUFFICIENT
  limitations: [string]
  algorithm_version: string
  input_evidence_ids: [EVD-...]
  time_window: {start: string, end: string, aggregation: hourly|daily|weekly|monthly}
  excluded_samples: [string]
  threshold_policy_ref: string|null
  generated_at: string
```

# Related skills

`capacity/trend-analysis`, `capacity/growth-rate`, `capacity/threshold-crossing`,
`capacity/anomaly-awareness`, `capacity/seasonality-awareness`, `capacity/confidence`,
`capacity/risk-classification`.

# Escalation

Threshold cruzado dentro de un horizonte con `confidence` no `INSUFFICIENT` escala a
`capacity/threshold-crossing`/`capacity/manual-capacity-plan`, con el supuesto de método (lineal
u otro) documentado explícitamente — nunca válido implícitamente para crecimiento no lineal (ej.
eventos estacionales) sin esa declaración.

# Manual remediation guidance

N/A directa — el forecast informa, `capacity/manual-capacity-plan` convierte en recomendación.

# Data sensitivity

Baja: series numéricas de utilización, sin datos de negocio.

# Context budget

Bajo en el resultado final (agregado/resumen); el cálculo pesado ocurre localmente, nunca se
envían series crudas extensas al modelo.

# Tests

`tests/test_forecast_linear_growth.sh`, `tests/test_forecast_flat.sh`,
`tests/test_forecast_decreasing.sh`, `tests/test_forecast_outlier_awareness.sh`,
`tests/test_forecast_insufficient_history.sh`, `tests/test_forecast_confidence.sh`,
`tests/test_forecast_1m.sh`, `tests/test_forecast_3m.sh`, `tests/test_forecast_6m.sh`,
`tests/test_forecast_records_algorithm_version.sh`, `tests/test_forecast_records_input_evidence.sh`,
`tests/test_forecast_records_time_window.sh`, `tests/test_forecast_records_exclusions.sh`,
`tests/test_forecast_reproducible_same_input.sh`.

# Documentation requirements

Alimenta `capacity-forecast.md` con la tabla de horizontes/confianza por recurso, y declara el
método usado y sus límites — nunca válido implícitamente fuera de esos límites.

# Evolution via `/change`

Métodos nuevos (ej. incorporar estacionalidad avanzada) vía `/change skill`; umbrales de riesgo
vía `/change policy`; cambios matemáticos que alteren resultados existentes requieren bump de
`forecast_contract_version`.

# Change history

v1.0.0 — Foundation, `skills/capacity/forecast.md` — regresión lineal simple sobre `used_pct` vs.
tiempo, umbrales de riesgo por headroom, degradación de confianza cuando histórico < 20% del
horizonte solicitado.
v2.0.0 — PHASE 10 — CAPACITY MANAGEMENT & FORECASTING: fusiona v1.0.0 como base del método MVP;
agrega selección de método, robustez ante outliers (nunca eliminados silenciosamente), intervalos
de confianza, horizontes 1/3/6m obligatorios desde el último dato válido, y reproducibilidad
completa (`algorithm_version`/`input_evidence_ids`/`time_window`/`excluded_samples`/
`forecast_contract_version`).

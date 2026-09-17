# PHASE 10 — FORECASTING EXECUTION & NUMERICAL VALIDATION HARDENING

Hardening sobre Fase 10 (Capacity Management & Forecasting) base, misma rama
`phase/10-capacity-forecasting`, baseline `v0.9.0-os-platform`. Cierra la brecha entre los
contratos declarativos de `skills/capacity/*` y un motor local **ejecutable** que normaliza series,
calcula estadísticas y produce forecasts a 1/3/6 meses verificables con pruebas numéricas.

## Diagnóstico inicial (gap reproducido)

Antes de este hardening, `tests/test_forecast_linear_growth.sh` y
`tests/test_forecast_reproducible_same_input.sh` — nombrados explícitamente por el prompt como el
"falso PASS documental" a reproducir — pasaban comprobando únicamente que
`skills/capacity/forecasting/SKILL.md` contuviera ciertas cadenas de texto (`grep -q
'forecast_method: linear_regression'` contra un fixture YAML, `grep -q 'forecast_contract_version'`
contra el SKILL.md). Ninguna línea de código ejecutable calculaba una regresión real; el "motor"
era puramente un contrato Markdown/YAML. Esto es precisamente el patrón que
`docs/PHASE_10_CAPACITY_MANAGEMENT_FORECASTING.md` (fase base) documentó honestamente como
`CONTRACT_DEFINED` — este hardening lo promueve a `LOCAL_RUNTIME_TESTED`.

## Addendum — PHASE 10 — CLI END-TO-END & CROSS-PLATFORM PATH HARDENING

Hardening posterior y acotado sobre el mismo motor (sin tocar normalización/regresión/umbrales —
ver "Revisión de alcance" del prompt correspondiente). Corrige un defecto real, verificado por
revisión externa del ZIP publicado, en `tests/test_capacity_engine_end_to_end.sh`.

**Root cause reproducido**: el test original construía las rutas absolutas para `--fixture`/
`--policy`/`--thresholds`/`--out`/`--markdown` como `"$WTMPDIR\\archivo.json"` — la barra invertida
se concatenaba **incondicionalmente**, sin verificar si el intérprete Python invocado realmente la
necesitaba. Cuando `cygpath` no estaba disponible, `$WTMPDIR` permanecía una ruta POSIX; en POSIX
la barra invertida **no es un separador de directorio**, así que Python recibía un nombre de
archivo literal con un `\` incrustado y fallaba con `FileNotFoundError`. Reproducido verbatim en
`tests/test_capacity_engine_end_to_end_linux_paths.sh`:

```text
FileNotFoundError: [Errno 2] No such file or directory: '.../tests/.tmp_capacity_e2e_NNN\fixture.json'
```

**Fix de raíz** (`tests/lib/capacity_engine_e2e_helpers.sh`): en vez de construir strings de ruta
absoluta con un separador adivinado, cada test hace `cd` (bash builtin, resuelto correctamente por
el sistema operativo sin importar qué intérprete se invoque después) al directorio de trabajo y
pasa al CLI **nombres de archivo relativos** — el problema de ambigüedad de separador desaparece
por construcción, sin necesidad de `cygpath` en el camino principal. Para el caso residual donde
una ruta absoluta es genuinamente necesaria, `capacity_engine_to_interp_path()` pregunta al propio
intérprete `python3` (`sys.platform`, nunca `uname`/`$OSTYPE`) si necesita una ruta estilo Windows,
y sólo entonces invoca `cygpath -w`.

**Tests nuevos** (`tests/test_capacity_engine_end_to_end_*.sh`): `linux_paths` (reproduce el
defecto + confirma el fix sobre el mismo directorio POSIX), `paths_with_spaces` (workdir con un
espacio en el nombre), `missing_fixture_fail_fast` (fixture ausente → falla de inmediato, sin
artefactos parciales), `cli_nonzero_exit` (JSON malformado → código distinto de cero, stderr real
expuesto, nunca enmascarado con `grep`/`|| true`), `output_consistency` (método, versión de
algoritmo, horizontes 1/3/6m, consistencia numérica JSON↔Markdown para los 3 horizontes,
trazabilidad de `evidence_id`, ausencia de secretos).

**Plataformas realmente ejecutadas en esta sesión**: Windows 11 + Git Bash (Cygwin bash 5.3) +
Python 3.13.14 nativo de Windows (`sys.platform == 'win32'`) — el entorno de desarrollo real de
este repositorio. No se ejecutó sobre un Linux/WSL real independiente en esta sesión; el escenario
POSIX puro (backslash inválido) se reprodujo simulando esa condición (rutas POSIX del propio Git
Bash, sin depender de `cygpath`) dentro del mismo entorno Windows, no en una máquina Linux nativa —
ver "Known limitations" abajo para el alcance exacto de esta certificación.

## Local engine location / invocation

```text
capacity_engine/
  __init__.py          # re-exporta CONTRACT_VERSION, ALGORITHM_VERSION, ForecastResult,
                          run_capacity_forecast, reconcile_daily_series
  common.py            # enums + dataclasses + ForecastResult (implementa el schema de
                          docs/CAPACITY_FORECASTING_MODEL.md 1:1)
  normalization.py      # validación de esquema/unidades/tiempo — GB decimal vs GiB binario,
                          total<=0/NaN/inf/negativo excluidos, nunca clamped
  quality.py             # coverage/freshness/missingness/gaps/independent_observations/outliers
  segmentation.py         # detección de capacity_resize + segmentación post-evento
  aggregation.py           # agregación diaria (mean/p95/peak), x = day_offset entero
  stats.py                 # OLS puro stdlib, intervalo de predicción (aprox. normal),
                              aritmética de meses calendario, outliers robustos (MAD)
  trend.py                  # INCREASING/DECREASING/STABLE/VOLATILE/UNKNOWN
  threshold.py                # ALREADY_EXCEEDED/DATE_ESTIMATED/NOT_EXPECTED_WITHIN_HORIZON/
                                 NON_MONOTONIC/INSUFFICIENT_EVIDENCE/INVALID_THRESHOLD
  reconciliation.py            # SOURCE_CONFLICT entre 2 fuentes, nunca promedio ciego
  engine.py                     # run_capacity_forecast() — orquestador del pipeline completo
  report.py                     # tabla de capacidad Markdown desde un ForecastResult real
  cli.py                        # adaptador local: python3 -m capacity_engine.cli --fixture ...
```

Invocación programática:

```python
from capacity_engine import run_capacity_forecast
result = run_capacity_forecast(raw_samples, policy=policy, thresholds=thresholds, as_of=as_of)
result.to_dict()   # JSON-serializable, implementa el forecast_result schema de la sección 8
```

Invocación local (sin LLM/MCP/red — adaptador CLI, sección 9):

```bash
python3 -m capacity_engine.cli --fixture samples.json --policy policy.json \
    --thresholds thresholds.json --out result.json --markdown report.md
```

Python 3 estándar únicamente — sin numpy/scipy/pandas (verificado estáticamente por
`tests/test_capacity_engine_security.sh`, que analiza el AST de cada módulo y compara sus imports
contra un allowlist de stdlib).

## Algorithm version / input-output contract

`ALGORITHM_VERSION = "capacity_engine.forecast.linear_ols/1.0.0"`,
`CONTRACT_VERSION = "1.0.0"` (`capacity_engine/common.py`). `ForecastResult` implementa
exactamente el `forecast_result` schema de la sección 8 del prompt de hardening (`contract_version`,
`algorithm_version`, `target_id`, `metric`, `unit`, `input_evidence_ids`, `source_id`,
`history_start`, `history_end`, `sample_count`, `daily_aggregate_count`, `data_quality`,
`exclusions`, `capacity_events`, `method`, `method_parameters`, `diagnostics`, `horizons`,
`thresholds`, `confidence`, `limitations`, `generated_at`). Cada campo de entrada requerido
(`target_id`, `technology`, `resource_type`, `metric_name`, `timestamp` con offset,
`total_capacity`, `used_capacity` o `utilization_percent`, `unit`, `source_id`, `evidence_id`) se
valida explícitamente — un dato faltante o inválido excluye la muestra con un
`ValidationIssue` tipado, nunca la repara silenciosamente.

## Normalization / data quality / source reconciliation

- **Normalización**: `total_capacity <= 0` → excluido (`INVALID_CAPACITY_INPUT`); `used < 0` →
  excluido (`NEGATIVE_USED`); `used > total` más allá de 1% de tolerancia → excluido
  (`USED_EXCEEDS_TOTAL`), nunca clamped; duplicados exactos → se conserva el primero
  (`DUPLICATE_TIMESTAMP`); GB decimal (10⁹) vs GiB binario (2³⁰) se convierten con factores
  distintos a bytes canónicos, nunca mezclados sin conversión explícita; CPU cores vs percentage
  detectado como `UNIT_MISMATCH` si se mezclan dentro de una misma serie.
- **Calidad**: `coverage`/`missingness_pct`/`gap_count`/`duplicate_count`/
  `independent_observations` (días distintos, nunca conteo de filas crudas) + outliers robustos
  (MAD, `capacity_engine/stats.py#robust_outliers`). `INSUFFICIENT`/`INVALID` bloquean el forecast
  con `method: INSUFFICIENT_HISTORY`, nunca un número inventado.
- **Reconciliación de fuentes**: `capacity_engine/reconciliation.py#reconcile_daily_series` compara
  series día-a-día de dos fuentes y marca `SOURCE_CONFLICT`/`RECONCILED` — `blind_average_used:
  False` es un campo fijo en el resultado, nunca calcula ni expone un valor promediado.

## Actual regression implementation

`capacity_engine/stats.py#ols_fit` — mínimos cuadrados ordinarios puro (sin numpy): pendiente,
intercepto, R², error estándar de la pendiente, desviación estándar residual — sobre `x = day_offset`
entero (agregado diario), nunca sobre timestamps crudos irregulares. Clasificación de tendencia
(`capacity_engine/trend.py`) vía una regla heurística documentada (±2×SE de la pendiente para
significancia, ratio de ruido residual/rango para distinguir STABLE de VOLATILE) — nunca
presentada como una prueba de hipótesis formal con p-valor exacto.

## Forecast 1m/3m/6m — ejemplos numéricos verificados

De `tests/test_forecast_linear_growth.sh` (serie sintética `used = 100 + 2×día`, 90 días desde
2026-01-01): `slope = 2.0` exacto, `intercept = 100.0` exacto, horizontes en
`2026-04-30`/`2026-06-30`/`2026-09-30` (aritmética de mes calendario, ver
`tests/test_capacity_engine_calendar.sh` para años bisiestos y fin de mes). De
`tests/test_capacity_engine_no_false_pass_mutation.sh`: tres series con pendientes 1.0/9.0/-4.0
producen slopes de salida 1.0/9.0/-4.0 respectivamente — el motor refleja el dato real, nunca un
valor fijo.

## Confidence / intervals / limitations

`confidence` (`HIGH|MEDIUM|LOW|INSUFFICIENT`) se deriva de reglas documentadas
(`capacity_engine/engine.py#_compute_confidence`): calidad de datos, clasificación de tendencia,
bondad de ajuste (R² y SE relativo), y — explícitamente — la **razón de extrapolación** del
horizonte de 6 meses contra la extensión real de la historia; un horizonte que extrapola más allá
de lo que la historia cubre nunca recibe `HIGH`, sin importar cuán bueno sea el ajuste histórico
(sección 6/80 del prompt). Los intervalos `lower/upper` usan una aproximación normal (z≈1.96) a la
t de Student — documentado en `method_parameters.interval_method` y
`diagnostics.interval_note` de cada resultado —, `NOT_ESTIMABLE` (`None`/`None`) con `n<=2`. Nunca
se recortan silenciosamente predicciones negativas o por encima de la capacidad física: se
preserva el valor bruto y se marca `OUT_OF_PHYSICAL_RANGE` en el horizonte correspondiente.

## Threshold crossing — ejemplo numérico verificado

De `tests/test_capacity_engine_threshold_crossing.sh`: serie `used = 100 + 5×día`, `total=1000`,
umbral `warning_percent=80` → cruce resuelto matemáticamente en el día 140
(`(80 - intercept)/slope`), `estimated_date` calculada exactamente contra esa fórmula. Caso
`ALREADY_EXCEEDED` y `INVALID_THRESHOLD` (umbral fuera de `(0, 100]`) verificados por separado.

## Resize / outlier / missing data handling

- **Resize**: `capacity_engine/segmentation.py` detecta un cambio de `total_capacity` >0.5%
  relativo entre muestras consecutivas, segmenta y usa sólo los datos posteriores — si ese
  segmento no alcanza `minimum_samples`/`minimum_history_days`, el resultado es
  `INSUFFICIENT_HISTORY` explícito, nunca mezcla épocas con denominador distinto
  (`tests/test_capacity_engine_resize_segmentation.sh`).
- **Outliers**: detectados por MAD, excluidos del ajuste con el día trazado en
  `diagnostics.trend.excluded_days` y en `limitations` — nunca eliminados sin registro
  (`tests/test_capacity_engine_outliers.sh`, que compara el ajuste con/sin exclusión).
- **Missing/irregular**: agregación diaria determinista con gaps/duplicados correctamente
  contabilizados y reproducible entre ejecuciones (`tests/test_capacity_engine_missing_irregular_duplicates.sh`).

## Workflow integration status (local vs contract-only)

| Componente | Estado |
|---|---|
| `capacity_engine.run_capacity_forecast` (API programática) | `LOCAL_RUNTIME_TESTED` |
| `capacity_engine.cli` (adaptador local end-to-end) | `LOCAL_RUNTIME_TESTED` |
| `/healthcheck capacity`, `/assessment capacity` (agente vivo vía MCP Gateway) | `CONTRACT_ONLY` / `NOT_RUNTIME_CERTIFIED` |
| Fuentes externas (Site24x7/Prophecy/Reporting Services/VMware/SQL Server) | sin cambio — `NOT_CONFIGURED`/`NOT_CERTIFIED` según `docs/CAPACITY_DATA_SOURCE_MODEL.md` |

No se declara ejecución integrada de `/healthcheck capacity`/`/assessment capacity` — esos
entrypoints siguen dependiendo del runtime de agente (Fase 13, MCP Gateway) que no es parte de
este hardening. `capacity_engine.cli` es la demostración end-to-end local que sí es real hoy.

## Evidence / reproducibility / sanitization

Dos ejecuciones con los mismos `samples`/`policy`/`as_of` producen un `ForecastResult` idéntico
excluyendo `generated_at` (metadata de auditoría de reloj, nunca insumo del cálculo) —
`tests/test_forecast_reproducible_same_input.sh`. `target_id`/`source_id`/`evidence_id` viajan
como los strings ya sanitizados que el llamador entrega (tokenización/enmascarado es
responsabilidad de la capa de evidencia existente, Fase 2 en adelante — el motor nunca decide qué
sanitizar, sólo preserva lo que recibe).

## New and rewritten executable tests

23 tests ejecutan el motor real y comparan salidas numéricas contra valores calculados de forma
independiente en el propio test (nunca contra un valor pre-calculado embebido silenciosamente en
el motor):

```text
tests/test_forecast_linear_growth.sh                          (endurecido — ejecución real añadida)
tests/test_forecast_reproducible_same_input.sh                 (endurecido — ejecución real añadida)
tests/test_capacity_engine_flat.sh
tests/test_capacity_engine_decreasing.sh
tests/test_capacity_engine_threshold_crossing.sh
tests/test_capacity_engine_calendar.sh
tests/test_capacity_engine_insufficient_history.sh
tests/test_capacity_engine_missing_irregular_duplicates.sh
tests/test_capacity_engine_outliers.sh
tests/test_capacity_engine_resize_segmentation.sh
tests/test_capacity_engine_source_conflict.sh
tests/test_capacity_engine_units.sh
tests/test_capacity_engine_interval_semantics.sh
tests/test_capacity_engine_storage_layers.sh
tests/test_capacity_engine_cpu_semantics.sh
tests/test_capacity_engine_security.sh
tests/test_capacity_engine_end_to_end.sh                       (reescrito — CLI E2E HARDENING, rutas relativas)
tests/test_capacity_engine_end_to_end_linux_paths.sh            (nuevo — CLI E2E HARDENING)
tests/test_capacity_engine_end_to_end_paths_with_spaces.sh       (nuevo — CLI E2E HARDENING)
tests/test_capacity_engine_end_to_end_missing_fixture_fail_fast.sh  (nuevo — CLI E2E HARDENING)
tests/test_capacity_engine_end_to_end_cli_nonzero_exit.sh        (nuevo — CLI E2E HARDENING)
tests/test_capacity_engine_end_to_end_output_consistency.sh      (nuevo — CLI E2E HARDENING)
tests/test_capacity_engine_no_false_pass_mutation.sh
```

`tests/lib/capacity_engine_e2e_helpers.sh` — helper compartido por los 6 tests `end_to_end*`:
`capacity_engine_run`/`capacity_engine_write_linear_fixture` (estrategia de rutas relativas, root
cause del defecto de separador corregido de raíz) y `capacity_engine_to_interp_path` (fallback para
ruta absoluta, pregunta a `python3` su `sys.platform` real antes de decidir si usar `cygpath -w`).

`test_capacity_engine_no_false_pass_mutation.sh` implementa el requisito anti-falso-PASS de la
sección 10: corre el motor sobre tres series con pendientes conocidas y distintas (1.0/9.0/-4.0) y
exige que los slopes de salida difieran en consecuencia; incluye además un doble deliberadamente
incorrecto ("motor constante") para demostrar que la misma aserción SÍ lo detectaría como
defectuoso, confirmando que la prueba tiene poder discriminante real.

Los checks documentales originales (contra `skills/capacity/forecasting/SKILL.md` y el fixture
YAML) se **conservaron**, etiquetados `(documental)` dentro de los dos tests endurecidos — nunca
reemplazados, sólo complementados con ejecución real.

## Targeted tests: passed / failed / skipped

23/23 tests numéricos nuevos/endurecidos — **PASSED**. 0 failed. 0 skipped. (18 del hardening de
forecasting/quality/threshold + 5 nuevos de CLI end-to-end/cross-platform, medidos en esta sesión,
no copiados de una corrida anterior.)

## Full regression: passed / failed / skipped / timeout / not run

Ver la salida final de este mismo reporte — ejecutada tras los tests dirigidos, cubriendo
Foundation, Oracle Core, Performance, RAC/GI/ASM/Network, Data Guard, Multitenant,
Backup/Recovery/RMAN, Security/Compliance, OS Platform, Capacity (Fase 10 base + este hardening),
Shared Version Resolver, Static Validator, Collector Safety, Security Blocking, Portability.

## Security validation

`tests/test_capacity_engine_security.sh`: (1) ningún módulo de `capacity_engine/` contiene un
patrón de red/subprocess/eval/exec/SQL-shell arbitrario (grep estático); (2) análisis AST de cada
módulo confirma que sólo se importa la librería estándar de Python — ninguna dependencia externa;
(3) ningún módulo declara una función de mutación (`resize`/`extend_`/`alter_`/`create_datafile`/
`add_disk`/`modify_vmware`/`execute_`). El motor opera exclusivamente sobre datos ya en memoria
(fixtures o evidencia ya recolectada) — nunca abre una conexión, nunca ejecuta un comando externo.

## Portability / git diff --check

`git diff --check` sin conflictos de merge ni espacios en blanco al final de línea en los archivos
de este hardening. Todo el código nuevo es Python 3 estándar puro — sin dependencias de plataforma
(probado sobre Windows/Git Bash + Cygwin en esta sesión; sin `os.path` hardcodeado a un separador
de plataforma específico donde importa — `pathlib`/`os.path.join` usados en `cli.py`).

## Known limitations / NOT_CERTIFIED sources

- El intervalo de predicción usa una aproximación normal, no una distribución t exacta (sin
  dependencia a scipy) — documentado explícitamente en cada resultado, nunca oculto.
- La reconciliación de fuentes (`reconciliation.py`) opera sobre series ya normalizadas de DOS
  fuentes proporcionadas por el llamador — no incluye descubrimiento/conexión a Site24x7/Prophecy/
  Reporting Services (siguen `NOT_CONFIGURED`/`NOT_CERTIFIED`, sin cambio respecto a la fase base).
- VMware/SQL Server capacity: sin cambio — contract diseñado, `NOT_CERTIFIED` en runtime,
  disponibles sólo vía `MANUAL_IMPORT`.
- `/healthcheck capacity`/`/assessment capacity` como comandos de agente vivo: `CONTRACT_ONLY`/
  `NOT_RUNTIME_CERTIFIED` — el runtime de agente/MCP Gateway es una fase posterior.
- Modelos estacionales avanzados y `robust_linear_regression`/`moving_average`/
  `exponential_smoothing` como métodos alternativos: no implementados en este hardening — el MVP
  ejecutable cubre exclusivamente OLS lineal, tal como exige la sección 6 como mínimo.
- **CLI E2E HARDENING**: certificado realmente sólo sobre Windows 11 + Git Bash (Cygwin) + Python
  3.13.14 nativo (`win32`) en esta sesión — el entorno real de desarrollo del repositorio. No se
  ejecutó sobre una máquina Linux/WSL/macOS independiente; el escenario POSIX se reprodujo
  simulando la condición (ruta POSIX + backslash inválido) dentro del mismo entorno Windows/Git
  Bash, que sí resuelve rutas POSIX de forma nativa para sus propios builtins — no es un sustituto
  de una corrida real en Linux. Un `PLATFORM(S) ACTUALLY TESTED` explícito acompaña el reporte de
  cierre de cada hardening en vez de asumir portabilidad no verificada.

## Referencias

`docs/CAPACITY_FORECASTING_MODEL.md`, `docs/CAPACITY_DATA_QUALITY_MODEL.md`,
`docs/CAPACITY_THRESHOLD_MODEL.md`, `docs/CAPACITY_REPORTING_MODEL.md`,
`docs/PHASE_10_CAPACITY_MANAGEMENT_FORECASTING.md`.

---
name: db-time
display_name: "DB Time"
id: performance/db-time
version: 1.0.0
domain: performance
status: active
---

# Purpose

Distinguir DB Time, DB CPU y non-idle waits, y correlacionar DB Time con el workload/elapsed time de la ventana — nunca interpretar un DB Time alto de forma aislada.

# Scope

**En alcance:** DB Time/DB CPU sobre ventana AWR (licenciado) o acumulado desde arranque (ruta estándar, sin licencia).
**Fuera de alcance:** desglose por wait class (`performance/wait-events`), por SQL (`performance/top-sql`).

# Supported Oracle versions

10g–23ai. `DBA_HIST_SYS_TIME_MODEL`/`V$SYS_TIME_MODEL` estables en todo el rango.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (por instancia — DB Time no se suma ingenuamente entre instancias). NON-CDB y CDB. Primary (foco principal).

# Licensing

`Q-PERF-DBTIME-001` (AWR) requiere Diagnostics Pack. `Q-PERF-DBTIME-CURRENT-001` (ruta estándar) no requiere licencia — usado automáticamente si Diagnostics Pack no está confirmado.

# Prerequisites

Target Profile publicado. `constraints.time_window` para la ruta AWR (opcional para la ruta estándar, que es un snapshot acumulado).

# Required evidence

- `Q-PERF-DBTIME-001` (con licencia) o `Q-PERF-DBTIME-CURRENT-001` (sin licencia)

# Optional evidence

- `Q-PERF-WAIT-AWR-001`/`Q-PERF-IO-001` (para calcular non-idle waits = DB Time − DB CPU y desglosarlo)

# Data collection

Lectura de `DBA_HIST_SYS_TIME_MODEL`/`DBA_HIST_SNAPSHOT` (AWR) o `V$SYS_TIME_MODEL`/`V$INSTANCE` (ruta estándar).

# Diagnostic logic / Decision tree

```text
1. Leer db_time_sec, db_cpu_sec, elapsed_sec (o uptime_sec en ruta estándar).
2. non_idle_wait_sec = db_time_sec - db_cpu_sec.
3. db_time_pct_elapsed = db_time_sec / elapsed_sec  (>1 si hay paralelismo/múltiples sesiones concurrentes — normal, no un error).
4. IF db_time_pct_elapsed muy por encima de lo esperado para el workload conocido AND sin explicación de concurrencia
        → HYPOTHESIS: actividad de usuario elevada, correlacionar con performance/top-sql y performance/wait-events
5. Nunca reportar "DB Time alto" sin comparar contra un baseline/expectativa de workload — ver performance/trending si hay snapshots previos.
```

# Normal behavior

DB Time proporcional al número de sesiones activas concurrentes y al workload esperado de la ventana/período.

# Abnormal patterns

DB Time creciendo de forma sostenida entre snapshots comparables (mismo horario, distinto día) sin cambio de workload conocido — candidato a `performance/trending`.

# Root cause patterns

Ninguno exclusivo — DB Time es la métrica de entrada al resto de la correlación (`performance/db-cpu`, `performance/wait-events`), no una conclusión en sí misma.

# Correlation rules

DB Time sin contexto de `elapsed_sec`/número de sesiones concurrentes no es interpretable — siempre se reporta junto con esa relación.

# False positives

DB Time > elapsed_sec no es un error — es evidencia de paralelismo/concurrencia (múltiples sesiones activas simultáneamente); no se reporta como anomalía por sí solo.

# Confidence model

`FACT` para los valores leídos directamente. `HYPOTHESIS` sólo con comparación contra baseline/expectativa de workload.

# Output schema

```yaml
findings:
  - db_time_sec: number
    db_cpu_sec: number
    non_idle_wait_sec: number
    db_time_pct_elapsed: number
    confidence: FACT|HYPOTHESIS
    evidence_refs: [EVD-...]
```

# Related skills

`performance/db-cpu`, `performance/wait-events`, `performance/top-sql`, `performance/awr-analysis`, `performance/trending`.

# Escalation

DB Time sostenidamente alto sin explicación → `performance/wait-events` + `performance/top-sql` para desglose; multi-síntoma → `incident-root-cause-analyst`.

# Examples

Ver `tests/fixtures/19c-high-cpu.yaml`.

# Data sensitivity / Context budget

Sensibilidad BAJA (métricas agregadas). Presupuesto bajo.

# Tests

`tests/test_awr_db_time.sh`, `tests/test_standard_path_db_cpu.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — ruta AWR licenciada + ruta estándar sin licencia, nunca interpreta DB Time aislado. |

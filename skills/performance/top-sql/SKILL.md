---
name: top-sql
display_name: "Top SQL"
id: performance/top-sql
version: 1.0.0
domain: performance
status: active
---

# Purpose

Identificar el SQL de mayor impacto en una ventana por elapsed time, CPU, I/O (reads/gets) y executions, con métricas por-ejecución cuando aplica — nunca exponiendo SQL text ni bind values por defecto.

# Scope

**En alcance:** `SQL_ID` + `PLAN_HASH_VALUE` + métricas agregadas (executions, elapsed, CPU, buffer gets, disk reads, rows processed), ordenadas por la dimensión solicitada.
**Fuera de alcance:** SQL text (política separada, ver `# SQL text policy`), tuning automático, ejecución de SQL Tuning Advisor.

# Supported Oracle versions

10g–23ai. `DBA_HIST_SQLSTAT` (AWR) y `V$SQLSTATS` (dinámico) estables en todo el rango.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (por instancia — `DBA_HIST_SQLSTAT` tiene `INSTANCE_NUMBER`; no se agrega ingenuamente entre instancias). NON-CDB y CDB. Primary.

# Licensing

`Q-PERF-TOPSQL-001` (AWR, ventana histórica) requiere Diagnostics Pack. `Q-PERF-TOPSQL-CURRENT-001` (`V$SQLSTATS`, acumulado desde parse) no requiere licencia — usado automáticamente cuando Diagnostics Pack no está confirmado.

# Prerequisites

Target Profile publicado. `constraints.time_window` para la ruta AWR (la ruta estándar no tiene ventana, es acumulado desde parse).

# Required evidence

- `Q-PERF-TOPSQL-001` (con licencia) o `Q-PERF-TOPSQL-CURRENT-001` (sin licencia)

# Optional evidence

- `Q-PERF-PLAN-001`/`Q-PERF-PLAN-HIST-001` (plan del `sql_id` identificado como top)

# Data collection

Lectura de `DBA_HIST_SQLSTAT`/`DBA_HIST_SNAPSHOT` (AWR) o `V$SQLSTATS` (dinámico). Nunca `SQL_TEXT`/`SQL_FULLTEXT`.

# Diagnostic logic / Decision tree

```text
1. Ordenar por la dimensión solicitada (elapsed/cpu/reads-gets/executions — ver skills performance/sql-*).
2. Calcular métricas por-ejecución (elapsed_per_exec, cpu_per_exec, gets_per_exec, reads_per_exec, rows_per_exec) con manejo seguro de división por cero.
3. NO asumir que un SQL con mucho elapsed total es ineficiente si su volumen de ejecuciones es enorme — comparar elapsed_per_exec, no sólo el total (ver # 19. METRICS PER EXECUTION del prompt de Fase 3).
4. Si un sql_id del top tiene múltiples plan_hash_value en la ventana → señalar performance/plan-regression.
```

# Normal behavior

Distribución de elapsed/CPU sin un único `sql_id` concentrando una proporción desproporcionada del DB Time total, o — si la concentra — con `elapsed_per_exec` bajo (alto volumen de ejecuciones legítimas, no ineficiencia).

# Abnormal patterns

Un `sql_id` con `elapsed_per_exec` alto Y ejecuciones frecuentes (candidato real de tuning); un `sql_id` con múltiples `plan_hash_value` y `elapsed_per_exec` divergente entre planes (→ `performance/plan-regression`).

# Root cause patterns

Ninguno confirmado por este skill solo — es evidencia de entrada para `performance/execution-plan`/`performance/plan-regression` y para la correlación de `agents/oracle-performance-analyst/AGENT.md#correlation-model`.

# Correlation rules

Siempre calcular métricas por-ejecución antes de juzgar eficiencia. Cruzar con `performance/execution-plan` cuando el `sql_id` top amerite investigación de plan.

# False positives

Un `sql_id` con `elapsed_time` total alto pero `executions` proporcionalmente alto (`elapsed_per_exec` bajo) no es ineficiente — es simplemente frecuente.

# Confidence model

`FACT` para las métricas leídas directamente. `HYPOTHESIS` para una interpretación de eficiencia basada en `elapsed_per_exec`/`cpu_per_exec` sin contexto adicional de negocio.

# Output schema

```yaml
findings:
  - sql_id: string
    plan_hash_value: number
    executions: number
    elapsed_sec: number
    elapsed_per_exec_sec: number
    cpu_sec: number
    cpu_per_exec_sec: number
    buffer_gets: number
    gets_per_exec: number
    disk_reads: number
    reads_per_exec: number
    rows_processed: number
    rows_per_exec: number
    evidence_refs: [EVD-...]
```

# Related skills

`performance/sql-cpu`, `performance/sql-elapsed`, `performance/sql-io`, `performance/sql-executions`, `performance/execution-plan`, `performance/plan-regression`, `performance/awr-analysis`.

# Escalation

`sql_id` con plan regression sospechada → `performance/plan-regression`. Tuning requerido → recomendación manual únicamente, nunca SQL Tuning Advisor ejecutado.

# Examples

Ver `tests/fixtures/19c-standalone-performance.yaml`.

# Data sensitivity / Context budget

Sensibilidad MEDIA (`sql_id`, nunca SQL text/bind values). Presupuesto medio, acotado por top-N (`top_sql_default: 10`).

# Tests

`tests/test_awr_top_sql.sh`, `tests/test_awr_no_sql_text_by_default.sh`, `tests/test_sql_elapsed_per_exec.sh`, `tests/test_sql_cpu_per_exec.sh`, `tests/test_sql_gets_per_exec.sh`, `tests/test_sql_reads_per_exec.sh`, `tests/test_standard_path_top_sql_metrics.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — ruta AWR licenciada + ruta estándar sin licencia, métricas por-ejecución con manejo seguro de división por cero, nunca SQL text por defecto. |

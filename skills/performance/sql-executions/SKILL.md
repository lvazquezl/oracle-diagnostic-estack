---
name: sql-executions
display_name: "SQL by Executions"
id: performance/sql-executions
version: 1.0.0
domain: performance
status: active
---

# Purpose

Top SQL ordenado por número de ejecuciones, usando la misma evidencia que `performance/top-sql` — no es una query ni evidencia distinta, sólo un `ORDER BY executions` sobre el mismo resultado.

# Scope

**En alcance:** ranking por `executions`.
**Fuera de alcance:** todo lo demás — delegado a `performance/top-sql`.

# Supported Oracle versions

10g–23ai — idéntico a `performance/top-sql`.

# Supported OS/platforms

Todas.

# Supported architectures

Idéntico a `performance/top-sql`.

# Licensing

Idéntico a `performance/top-sql`.

# Prerequisites

`performance/top-sql` ejecutado con `constraints.sort_dimension: executions`.

# Required evidence

- `Q-PERF-TOPSQL-001`/`Q-PERF-TOPSQL-CURRENT-001` (misma que `performance/top-sql`)

# Optional evidence

- `Q-PERF-HARDPARSE-001` (correlación con parse count)

# Data collection

Ninguna propia — reutiliza `performance/top-sql`.

# Diagnostic logic / Decision tree

```text
1. Tomar el resultado de performance/top-sql.
2. Reordenar por executions descendente.
3. Un sql_id con executions muy alto y elapsed_per_exec bajo es esperado (query frecuente y eficiente) — no es un finding por sí solo.
4. Correlacionar con parse count (hard) — muchas ejecuciones con hard parse desproporcionado sugiere ausencia de bind variables/cursor sharing subóptimo.
```

# Normal behavior / Abnormal patterns / Root cause patterns / Correlation rules / False positives

Idénticos a `performance/top-sql` — un `sql_id` de alta frecuencia no es anómalo por definición; la anomalía es alta frecuencia + `elapsed_per_exec` alto, o alta frecuencia + hard parse desproporcionado.

# Confidence model

Idéntico a `performance/top-sql`.

# Output schema

Idéntico a `performance/top-sql`, ordenado por `executions`.

# Related skills

`performance/top-sql`, `performance/hard-parse`.

# Escalation

Idéntica a `performance/top-sql`.

# Examples

Ver `tests/fixtures/19c-standalone-performance.yaml`.

# Data sensitivity / Context budget

Idéntico a `performance/top-sql`.

# Tests

Cubierto por `tests/test_awr_top_sql.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — reordenamiento por executions sobre la evidencia de performance/top-sql, sin query propia. |

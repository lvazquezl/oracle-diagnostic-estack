---
name: sql-cpu
display_name: "SQL by CPU"
id: performance/sql-cpu
version: 1.0.0
domain: performance
status: active
---

# Purpose

Top SQL ordenado por CPU consumido, usando la misma evidencia que `performance/top-sql` — no es una query ni evidencia distinta, sólo un `ORDER BY cpu_sec` sobre el mismo resultado.

# Scope

**En alcance:** ranking por `cpu_sec`/`cpu_per_exec_sec`.
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

`performance/top-sql` ejecutado con `constraints.sort_dimension: cpu`.

# Required evidence

- `Q-PERF-TOPSQL-001`/`Q-PERF-TOPSQL-CURRENT-001` (misma que `performance/top-sql`)

# Optional evidence

Ninguna adicional.

# Data collection

Ninguna propia — reutiliza `performance/top-sql`.

# Diagnostic logic / Decision tree

```text
1. Tomar el resultado de performance/top-sql.
2. Reordenar por cpu_sec descendente.
3. Aplicar la misma regla de # 19 METRICS PER EXECUTION: no juzgar por total, comparar cpu_per_exec_sec.
```

# Normal behavior / Abnormal patterns / Root cause patterns / Correlation rules / False positives

Idénticos a `performance/top-sql`, aplicados a la dimensión CPU específicamente — correlacionar con `performance/db-cpu` cuando el CPU agregado de la instancia también esté elevado.

# Confidence model

Idéntico a `performance/top-sql`.

# Output schema

Idéntico a `performance/top-sql`, ordenado por `cpu_sec`.

# Related skills

`performance/top-sql`, `performance/db-cpu`, `performance/hard-parse`.

# Escalation

Idéntica a `performance/top-sql`.

# Examples

Ver `tests/fixtures/19c-high-cpu.yaml`.

# Data sensitivity / Context budget

Idéntico a `performance/top-sql`.

# Tests

`tests/test_sql_cpu_per_exec.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — reordenamiento por CPU sobre la evidencia de performance/top-sql, sin query propia. |

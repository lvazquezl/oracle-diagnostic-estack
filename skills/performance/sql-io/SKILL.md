---
name: sql-io
display_name: "SQL by I/O"
id: performance/sql-io
version: 1.0.0
domain: performance
status: active
---

# Purpose

Top SQL ordenado por I/O (`buffer_gets`/`disk_reads`), usando la misma evidencia que `performance/top-sql` — no es una query ni evidencia distinta, sólo un `ORDER BY disk_reads`/`ORDER BY buffer_gets` sobre el mismo resultado.

# Scope

**En alcance:** ranking por `disk_reads`/`buffer_gets`/`reads_per_exec`/`gets_per_exec`.
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

`performance/top-sql` ejecutado con `constraints.sort_dimension: io`.

# Required evidence

- `Q-PERF-TOPSQL-001`/`Q-PERF-TOPSQL-CURRENT-001` (misma que `performance/top-sql`)

# Optional evidence

- `Q-PERF-IO-FILESTAT-001` (correlación con latencia por archivo)

# Data collection

Ninguna propia — reutiliza `performance/top-sql`.

# Diagnostic logic / Decision tree

```text
1. Tomar el resultado de performance/top-sql.
2. Reordenar por disk_reads y buffer_gets descendente (dos rankings distintos, no combinados).
3. gets_per_exec alto con reads_per_exec bajo → dominado por buffer cache (lógico, no físico).
4. reads_per_exec alto → correlacionar con performance/io para latencia física.
```

# Normal behavior / Abnormal patterns / Root cause patterns / Correlation rules / False positives

Idénticos a `performance/top-sql`, aplicados a I/O — correlacionar con `performance/io`/`performance/execution-plan` (un Full Table Scan no es malo por definición, ver `# 20. EXECUTION PLAN` del prompt de Fase 3).

# Confidence model

Idéntico a `performance/top-sql`.

# Output schema

Idéntico a `performance/top-sql`, ordenado por `disk_reads`/`buffer_gets`.

# Related skills

`performance/top-sql`, `performance/io`, `performance/execution-plan`.

# Escalation

Idéntica a `performance/top-sql`.

# Examples

Ver `tests/fixtures/19c-high-io.yaml`.

# Data sensitivity / Context budget

Idéntico a `performance/top-sql`.

# Tests

`tests/test_sql_gets_per_exec.sh`, `tests/test_sql_reads_per_exec.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — reordenamiento por I/O sobre la evidencia de performance/top-sql, sin query propia. |

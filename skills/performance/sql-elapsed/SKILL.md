---
name: sql-elapsed
display_name: "SQL by Elapsed Time"
id: performance/sql-elapsed
version: 1.0.0
domain: performance
status: active
---

# Purpose

Top SQL ordenado por elapsed time total, usando la misma evidencia que `performance/top-sql` — no es una query ni evidencia distinta, sólo un `ORDER BY elapsed_sec` sobre el mismo resultado.

# Scope

**En alcance:** ranking por `elapsed_sec`/`elapsed_per_exec_sec`.
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

`performance/top-sql` ejecutado con `constraints.sort_dimension: elapsed`.

# Required evidence

- `Q-PERF-TOPSQL-001`/`Q-PERF-TOPSQL-CURRENT-001` (misma que `performance/top-sql`)

# Optional evidence

Ninguna adicional.

# Data collection

Ninguna propia — reutiliza `performance/top-sql`.

# Diagnostic logic / Decision tree

```text
1. Tomar el resultado de performance/top-sql.
2. Reordenar por elapsed_sec descendente.
3. Aplicar # 19 METRICS PER EXECUTION: no juzgar por total, comparar elapsed_per_exec_sec.
4. elapsed_time incluye tiempo de espera (no sólo CPU) — cruzar con performance/wait-events para entender qué compone el elapsed de ese SQL_ID específico.
```

# Normal behavior / Abnormal patterns / Root cause patterns / Correlation rules / False positives

Idénticos a `performance/top-sql`, aplicados a la dimensión elapsed — correlacionar con `performance/wait-events` para descomponer elapsed en CPU + waits.

# Confidence model

Idéntico a `performance/top-sql`.

# Output schema

Idéntico a `performance/top-sql`, ordenado por `elapsed_sec`.

# Related skills

`performance/top-sql`, `performance/wait-events`, `performance/db-time`.

# Escalation

Idéntica a `performance/top-sql`.

# Examples

Ver `tests/fixtures/19c-standalone-performance.yaml`.

# Data sensitivity / Context budget

Idéntico a `performance/top-sql`.

# Tests

`tests/test_sql_elapsed_per_exec.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — reordenamiento por elapsed time sobre la evidencia de performance/top-sql, sin query propia. |

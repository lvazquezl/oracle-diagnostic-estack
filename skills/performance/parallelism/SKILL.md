---
name: parallelism
display_name: "Parallelism"
id: performance/parallelism
version: 1.0.0
domain: performance
status: active
---

# Purpose

Analizar sesiones/procesos de Parallel Execution activos y su impacto en CPU/I/O — sin recomendar aumentar `parallel_max_servers`/DOP sin correlación completa.

# Scope

**En alcance:** sesiones PX activas (`V$PX_SESSION`), grado solicitado vs. otorgado.
**Fuera de alcance:** cambio de `parallel_max_servers`/DOP (siempre recomendación manual con evidencia completa).

# Supported Oracle versions

10g–23ai. `V$PX_SESSION` estable en todo el rango.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC (Parallel Execution puede distribuirse entre instancias en RAC — este skill reporta por instancia, agregación cross-instance vía `oracle-rac-analyst` si se requiere). NON-CDB y CDB. Primary.

# Licensing

Ninguna (Parallel Execution en sí no requiere Diagnostics/Tuning Pack).

# Prerequisites

Target Profile publicado.

# Required evidence

- `Q-PERF-PARALLEL-001`

# Optional evidence

- `Q-PERF-TOPSQL-CURRENT-001`/`Q-PERF-TOPSQL-001` (identificar el `sql_id` que originó las sesiones PX)

# Data collection

Lectura de `V$PX_SESSION`.

# Diagnostic logic / Decision tree

```text
1. Leer sesiones PX activas: qcsid (query coordinator), sid, server_name, degree, req_degree, sql_id.
2. IF degree < req_degree de forma sostenida → HYPOTHESIS: contención de PX servers (parallel_max_servers insuficiente o parallel_servers_target alcanzado).
3. Correlacionar con performance/db-cpu — DOP alto explica legítimamente CPU alto, no es automáticamente un problema.
4. Nunca recomendar cambiar parallel_max_servers/DOP sin ver el impacto CPU/IO completo y el patrón de uso (# 31. PARALLELISM del prompt de Fase 3).
```

# Normal behavior

`degree` otorgado igual al `req_degree` solicitado, sin degradación sostenida de DOP.

# Abnormal patterns

`degree` consistentemente menor a `req_degree` (degradación de paralelismo por falta de servers disponibles).

# Root cause patterns

Ninguno confirmado sin correlacionar con `performance/db-cpu`/`performance/io` para el impacto real, y sin ver el patrón de concurrencia de múltiples queries paralelas simultáneas.

# Correlation rules

Cruzar siempre con `performance/db-cpu`/`performance/io` — Parallel Execution consume ambos recursos de forma legítima cuando está bien dimensionado.

# False positives

DOP alto durante una ventana de carga batch conocida (ETL, index rebuild) no es un problema — es el uso esperado de paralelismo.

# Confidence model

`FACT` para las sesiones PX leídas directamente. `HYPOTHESIS` para "contención de PX servers" con degradación de DOP sostenida.

# Output schema

```yaml
findings:
  - qcsid: number
    sql_id: string|null
    degree_requested: number
    degree_granted: number
    degraded: bool
    evidence_refs: [EVD-...]
```

# Related skills

`performance/db-cpu`, `performance/io`, `performance/top-sql`, `performance/concurrency`.

# Escalation

Recomendación de `parallel_max_servers`/DOP → siempre manual con evidencia CPU/I/O completa, nunca ejecutado.

# Examples

Ver `tests/fixtures/19c-standalone-performance.yaml`.

# Data sensitivity / Context budget

Sensibilidad BAJA (`sql_id`). Presupuesto bajo.

# Tests

`tests/test_parallelism_detection.sh`, `tests/test_no_parallel_parameter_change_without_context.sh`.

# Change history

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0.0 | Fase 3 (Oracle Performance) | Materializado — nunca recomienda DOP/parallel_max_servers sin correlación CPU/I/O completa. |

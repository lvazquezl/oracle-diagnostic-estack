---
query_id: Q-PERF-WORKAREA-001
version: 1.0.0

domain: performance
purpose: Ejecuciones de work areas (sort, hash join) óptimas, one-pass y multi-pass desde el arranque, PGA cache hit, bytes extra leídos y escritos y pico de PGA asignada

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [V$SQL_WORKAREA_HISTOGRAM, V$PGASTAT]
privileges_required: [SELECT on V$SQL_WORKAREA_HISTOGRAM, SELECT on V$PGASTAT]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 1
max_output_bytes: 4096

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-PERF-WORKAREA-001-V1
    label: all_versions
    oracle_versions: {min: "10.2", max: "23.0"}
    container_scope: NOT_APPLICABLE
    sql_block: "Variant V1 (all_versions, 10.2–23.0: una fila de la instancia)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_collector_factory.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (all_versions, 10.2–23.0: una fila de la instancia)

```sql
SELECT SUM(h.optimal_executions) AS optimal_executions,
       SUM(h.onepass_executions) AS onepass_executions,
       SUM(h.multipasses_executions) AS multipass_executions,
       (SELECT MAX(s.value) FROM v$pgastat s WHERE s.name = 'cache hit percentage') AS pga_cache_hit_pct,
       (SELECT MAX(s.value) FROM v$pgastat s WHERE s.name = 'extra bytes read/written') AS extra_bytes_read_written,
       (SELECT MAX(s.value) FROM v$pgastat s WHERE s.name = 'maximum PGA allocated') AS max_pga_allocated_bytes
FROM   v$sql_workarea_histogram h;
```

# Notes by version

`V$SQL_WORKAREA_HISTOGRAM` y las estadísticas de `V$PGASTAT` usadas existen desde 10.1.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

Valores de la instancia desde el arranque. En RAC, de la instancia consultada. Complementa a `Q-PERF-PGA-001` (target, uso y over allocation).

# Cost classification rationale

`LOW` — histograma de unas 30 filas y tres filas de `V$PGASTAT`.

# License notes

Ninguna.

# Sanitization notes

Solo conteos, bytes y porcentaje de la instancia.

# Evolution via `/change query`

1.0.0 CHG-ESTACK-C-NEW-QUERIES-001: creación (lote C, cobertura del assessment).

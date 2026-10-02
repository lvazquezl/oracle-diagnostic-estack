---
query_id: Q-PERF-WAIT-CLASS-001
version: 1.0.0

domain: performance
purpose: Tiempo de espera acumulado por clase de espera no idle desde el arranque (sin licencia)

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$SYSTEM_EVENT]
privileges_required: [SELECT on V$SYSTEM_EVENT]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 20
max_output_bytes: 16384

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-PERF-WAIT-CLASS-001-V1
    label: legacy_rownum
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_rownum, 10.2–11.2)"
  - variant_id: Q-PERF-WAIT-CLASS-001-V2
    label: modern_fetch_first
    oracle_versions: {min: "12.1", max: latest}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_fetch_first, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_every_logical_query_has_variant.sh, tests/test_no_variant_references_unknown_column.sh, tests/test_collector_factory.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_rownum, 10.2–11.2)

```sql
SELECT *
FROM  (SELECT e.wait_class, SUM(e.total_waits) AS total_waits,
              ROUND(SUM(e.time_waited_micro) / 1e6, 2) AS time_waited_sec
       FROM   v$system_event e
       WHERE  e.wait_class <> 'Idle'
       GROUP  BY e.wait_class
       ORDER  BY SUM(e.time_waited_micro) DESC)
WHERE  ROWNUM <= 20;
```

# Statement / procedure (read-only) — Variant V2 (modern_fetch_first, 12.1+)

```sql
SELECT e.wait_class, SUM(e.total_waits) AS total_waits,
       ROUND(SUM(e.time_waited_micro) / 1e6, 2) AS time_waited_sec
FROM   v$system_event e
WHERE  e.wait_class <> 'Idle'
GROUP  BY e.wait_class
ORDER  BY SUM(e.time_waited_micro) DESC
FETCH  FIRST 20 ROWS ONLY;
```

Distribución del tiempo de espera por clase (User I/O, Commit, Concurrency, Configuration…): primer corte para decidir qué especialista mirar. Se agrega `V$SYSTEM_EVENT` por clase (en microsegundos), la misma vista ya registrada en el diccionario que usa `Q-PERF-WAIT-SYSTEM-001`.

# Notes by version

`V$SYSTEM_EVENT` con `WAIT_CLASS` existe desde 10g. `FETCH FIRST` sólo desde 12.1 (V2).

# Notes by platform

Ninguna diferencia.

# Container / role scope notes

`ANY_CONTAINER`: vista de instancia; en un CDB conectado a `CDB$ROOT` refleja toda la instancia. `ANY` rol: las esperas existen también en standby (apply, transporte).

# Cost classification rationale

`LOW`: una fila por clase (~13).

# License notes

Ninguna: `V$SYSTEM_EVENT` no forma parte de Diagnostics Pack (a diferencia de ASH/AWR).

# Sanitization notes

`wait_class` → enum cerrado KEEP; conteos y tiempos → KEEP.

# Evolution via `/change query`

CHG-ESTACK-COLLECTOR-FACTORY-B2 — creada para el lote de rendimiento de la fábrica de collectors.

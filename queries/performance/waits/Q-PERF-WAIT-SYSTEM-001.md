---
query_id: Q-PERF-WAIT-SYSTEM-001
version: 1.0.0

domain: performance
purpose: Top 25 eventos de espera no idle por tiempo acumulado desde el arranque (sin licencia)

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
max_rows: 25
max_output_bytes: 16384

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-PERF-WAIT-SYSTEM-001-V1
    label: legacy_rownum
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_rownum, 10.2–11.2)"
  - variant_id: Q-PERF-WAIT-SYSTEM-001-V2
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
FROM  (SELECT e.event, e.wait_class, e.total_waits, e.total_timeouts,
              ROUND(e.time_waited_micro / 1e6, 2)                               AS time_waited_sec,
              ROUND(e.time_waited_micro / NULLIF(e.total_waits, 0) / 1000, 3)   AS avg_wait_ms
       FROM   v$system_event e
       WHERE  e.wait_class <> 'Idle'
       ORDER  BY e.time_waited_micro DESC)
WHERE  ROWNUM <= 25;
```

# Statement / procedure (read-only) — Variant V2 (modern_fetch_first, 12.1+)

```sql
SELECT e.event, e.wait_class, e.total_waits, e.total_timeouts,
       ROUND(e.time_waited_micro / 1e6, 2)                               AS time_waited_sec,
       ROUND(e.time_waited_micro / NULLIF(e.total_waits, 0) / 1000, 3)   AS avg_wait_ms
FROM   v$system_event e
WHERE  e.wait_class <> 'Idle'
ORDER  BY e.time_waited_micro DESC
FETCH  FIRST 25 ROWS ONLY;
```

Snapshot acumulado desde el arranque de la instancia: indica **dónde** se ha ido el tiempo de espera, no cuándo. Para una ventana, dos ejecuciones separadas y su diferencia. Complementa `Q-PERF-DBTIME-CURRENT-001` (DB time − DB CPU ≈ esperas no idle) sin requerir Diagnostics Pack.

# Notes by version

`WAIT_CLASS` y `TIME_WAITED_MICRO` existen desde 10g. `FETCH FIRST` sólo desde 12.1 (V2); V1 usa `ROWNUM`.

# Notes by platform

Ninguna diferencia.

# Container / role scope notes

`ANY_CONTAINER`: vista de instancia; en un CDB conectado a `CDB$ROOT` refleja toda la instancia. `ANY` rol: las esperas existen también en standby (apply, transporte).

# Cost classification rationale

`LOW`: `V$SYSTEM_EVENT` es una vista en memoria de ~2000 filas; tope 25.

# License notes

Ninguna: `V$SYSTEM_EVENT` no forma parte de Diagnostics Pack (a diferencia de ASH/AWR).

# Sanitization notes

`event` y `wait_class` son vocabulario de Oracle (no datos de aplicación) → KEEP; el collector usa el tipo `oracle_term` sólo en el campo `event` y un enum cerrado para `wait_class`. Conteos y tiempos → KEEP.

# Evolution via `/change query`

CHG-ESTACK-COLLECTOR-FACTORY-B2 — creada para el lote de rendimiento de la fábrica de collectors.

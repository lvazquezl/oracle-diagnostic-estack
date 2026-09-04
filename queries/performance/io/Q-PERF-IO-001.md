---
query_id: Q-PERF-IO-001
version: 1.0.0

domain: performance
purpose: Waits de I/O dominantes, snapshot actual acumulado desde el arranque de la instancia

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$SYSTEM_EVENT]
privileges_required: [SELECT on V$SYSTEM_EVENT]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 20
max_output_bytes: 8192

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_low.sh, tests/test_io_wait_analysis.sh, tests/test_log_file_sync_vs_parallel_write_correlation.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT e.event,
       e.total_waits,
       e.time_waited_micro / 1e6 AS total_wait_time_sec
FROM   v$system_event e
WHERE  e.event IN ('db file sequential read', 'db file scattered read', 'direct path read',
                    'direct path write', 'log file parallel write', 'log file sync')
ORDER  BY total_wait_time_sec DESC;
```

Snapshot puntual (acumulado desde `STARTUP_TIME`), no ventana AWR — sirve como ruta estándar sin licencia y como complemento de `Q-PERF-WAIT-AWR-001`. Correlacionar `log file sync` (commit) contra `log file parallel write` (LGWR) es la base de `performance/commit-redo#correlation-rules` para distinguir comportamiento de aplicación vs. latencia de storage de redo.

# Notes by version

`V$SYSTEM_EVENT` estable 10g–23ai en las columnas usadas.

# Notes by platform

Latencia de I/O depende del driver del SO subyacente — sin evidencia OS/storage adicional, un valor de latencia alto es `OBSERVATION`, no confirmación de problema de storage (ver `# 27. I/O` del prompt de Fase 3).

# Container / role scope notes

`ANY_CONTAINER` — vista de instancia. `database_role_scope: PRIMARY` — I/O de escritura de aplicación es mínimo en standby en mount; I/O de apply en standby tiene un patrón distinto, fuera de alcance de esta query.

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP (nombres de wait event, no datos de aplicación).

# Evolution via `/change query`

Ninguno previsto.

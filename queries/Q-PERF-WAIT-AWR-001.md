---
query_id: Q-PERF-WAIT-AWR-001
version: 2.0.0

domain: performance
purpose: Top wait events por tiempo total de espera en una ventana AWR

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: CDB_ROOT
database_role_scope: PRIMARY

objects_accessed: [DBA_HIST_SYSTEM_EVENT, DBA_HIST_SNAPSHOT]
privileges_required: [SELECT on DBA_HIST_SYSTEM_EVENT, SELECT on DBA_HIST_SNAPSHOT]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 60
max_rows: 200
max_output_bytes: 262144

sensitivity: MEDIUM
sanitization_required: true

license_requirements: [Diagnostics Pack]

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_medium.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT e.instance_number,
       e.event_name,
       e.wait_class,
       SUM(e.time_waited_micro_fg) / 1e6 AS total_wait_time_sec
FROM   dba_hist_system_event e
JOIN   dba_hist_snapshot s
       ON  s.snap_id = e.snap_id
       AND s.instance_number = e.instance_number
WHERE  s.end_interval_time BETWEEN :window_start AND :window_end
  AND  e.wait_class <> 'Idle'
GROUP  BY e.instance_number, e.event_name, e.wait_class
ORDER  BY total_wait_time_sec DESC
FETCH FIRST 20 ROWS ONLY;                 -- 12c+; usar ROWNUM <= 20 en 10g/11g
```

Requiere Diagnostics Pack licenciado (marcar `LICENSE_CHECK_REQUIRED` en el finding que consuma esta evidencia). Fallback: `Q-PERF-WAIT-STATSPACK-001` sobre `STATS$SYSTEM_EVENT`.

# Notes by version

- `FETCH FIRST ... ROWS ONLY` no existe antes de 12c; en 10g/11g envolver en subquery con `ROWNUM`.
- `TIME_WAITED_MICRO_FG` (foreground) preferido sobre `TIME_WAITED_MICRO` desde 11g para aislar espera de sesiones de usuario.

# Notes by platform

Ninguna — query SQL pura.

# Sanitization notes

`event_name`/`wait_class` → KEEP (no sensibles); `instance_number` → KEEP. No se lee SQL text en esta query (eso es `Q-PERF-TOPSQL-*`, con su propia política de sanitización de SQL text).

# Evolution via `/change query`

Cambios de ventana/columnas por versión vía `/change compatibility`; cambio de top-N vía `/change policy`.

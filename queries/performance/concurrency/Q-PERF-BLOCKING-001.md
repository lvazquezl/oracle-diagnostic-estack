---
query_id: Q-PERF-BLOCKING-001
version: 1.0.0

domain: performance
purpose: Cadenas de bloqueo (blocker/waiter) activas, snapshot actual

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$SESSION]
privileges_required: [SELECT on V$SESSION]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 15
max_rows: 200
max_output_bytes: 65536

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_medium.sh, tests/test_blocking_detection.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT waiter.sid                AS waiter_sid,
       waiter.serial#            AS waiter_serial,
       waiter.blocking_session   AS blocker_sid,
       blocker.serial#           AS blocker_serial,
       waiter.event,
       waiter.wait_class,
       waiter.seconds_in_wait,
       waiter.sql_id             AS waiter_sql_id
FROM   v$session waiter
LEFT   JOIN v$session blocker
       ON  blocker.sid = waiter.blocking_session
WHERE  waiter.blocking_session IS NOT NULL
ORDER  BY waiter.seconds_in_wait DESC
FETCH FIRST 100 ROWS ONLY;                -- 12c+; usar ROWNUM <= 100 en 10g/11g
```

Usa `V$SESSION.BLOCKING_SESSION` (mantenido activamente por Oracle desde 10g) en vez de `DBA_BLOCKERS`/`DBA_WAITERS` (vistas legacy, con limitaciones conocidas en RAC y desusadas en la práctica DBA moderna) — ver `# Notes by version`.

# Notes by version

`V$SESSION.BLOCKING_SESSION` disponible desde 10g, con semántica consistente 10g–23ai. `DBA_BLOCKERS`/`DBA_WAITERS` existen en todo el rango pero no se usan aquí por su comportamiento menos confiable en RAC multi-instancia — documentado como decisión de diseño, no como limitación de compatibilidad.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`ANY_CONTAINER` — vista de instancia. `database_role_scope: PRIMARY` — bloqueo de sesiones de usuario/aplicación es un fenómeno de actividad de escritura, no aplica en standby en mount.

# License notes

Ninguna.

# Sanitization notes

`sql_id` → KEEP (no es SQL text); `waiter_sid`/`blocker_sid`/`serial#` → KEEP (no identifican usuario final).

# Evolution via `/change query`

Ninguno previsto.

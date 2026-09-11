---
query_id: Q-PERF-BLOCKING-001
version: 1.1.0

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

variants:
  - variant_id: Q-PERF-BLOCKING-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10g-11g)"
  - variant_id: Q-PERF-BLOCKING-001-V2
    label: modern_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_12plus, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_medium.sh, tests/test_blocking_detection.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10g-11g)

```sql
SELECT *
FROM (
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
)
WHERE  ROWNUM <= 100;
```

# Statement / procedure (read-only) — Variant V2 (modern_12plus, 12.1+)

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
FETCH  FIRST 100 ROWS ONLY;
```

Usa `V$SESSION.BLOCKING_SESSION` (mantenido activamente por Oracle desde 10g) en vez de `DBA_BLOCKERS`/`DBA_WAITERS` (vistas legacy, con limitaciones conocidas en RAC y desusadas en la práctica DBA moderna) — ver `# Notes by version`.

# Notes by version

`V$SESSION.BLOCKING_SESSION` disponible desde 10g, con semántica consistente 10g–23ai. `DBA_BLOCKERS`/`DBA_WAITERS` existen en todo el rango pero no se usan aquí por su comportamiento menos confiable en RAC multi-instancia — documentado como decisión de diseño, no como limitación de compatibilidad.

**PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING**: v1.0.0 declaraba una única sentencia `FETCH FIRST ... ROWS ONLY` con `supported_oracle_versions` incluyendo 10g/11g — el propio comentario inline (`-- 12c+; usar ROWNUM <= 100 en 10g/11g`) ya señalaba el gap sin cerrarlo. Detectado por el nuevo test de regresión global `tests/test_no_fetch_first_in_pre12c_queries.sh` (recorre todo `queries/**`, no sólo RMAN) y corregido con el mismo patrón: V1 (10g-11g) `ROWNUM` sobre inline view ya ordenado; V2 (12.1+) `FETCH FIRST` sin cambios.

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

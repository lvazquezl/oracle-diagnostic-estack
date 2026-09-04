---
query_id: Q-PERF-WAIT-ASH-001
version: 2.1.0

domain: performance
purpose: Wait events granulares (por sesión activa) sobre una ventana ASH para diagnóstico de contención puntual

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$ACTIVE_SESSION_HISTORY, DBA_HIST_ACTIVE_SESS_HISTORY]
privileges_required: [SELECT on V$ACTIVE_SESSION_HISTORY, SELECT on DBA_HIST_ACTIVE_SESS_HISTORY]

risk_class: R0
cost_class: HIGH

timeout_seconds: 60
max_rows: 1000
max_output_bytes: 524288

sensitivity: MEDIUM
sanitization_required: true

license_requirements: [Diagnostics Pack]

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_high.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT h.sample_time,
       h.session_id,
       h.session_serial#,
       h.event,
       h.wait_class,
       h.sql_id
FROM   v$active_session_history h        -- ventana reciente en memoria (últimas horas)
WHERE  h.sample_time BETWEEN :window_start AND :window_end
  AND  h.wait_class IS NOT NULL
ORDER  BY h.sample_time;

-- Para ventanas fuera de V$ACTIVE_SESSION_HISTORY (retención en memoria limitada),
-- usar DBA_HIST_ACTIVE_SESS_HISTORY (requiere snapshot AWR en la ventana) con la misma forma.
```

**cost_class: HIGH** — ver `policies/query-cost-policy.md#ejemplos-conceptuales` ("ASH sobre ventana amplia → HIGH"). Requiere `constraints.time_window` explícito y acotado en el Task Package (nunca "todo lo disponible"); `max_rows`/`timeout_seconds` son más estrictos que el default genérico. Requiere Diagnostics Pack licenciado (`license_requirements: [Diagnostics Pack]`) — marcar `LICENSE_CHECK_REQUIRED` en el finding que consuma esta evidencia.

# Notes by version

`V$ACTIVE_SESSION_HISTORY` disponible desde 10g (con Diagnostics Pack). `DBA_HIST_ACTIVE_SESS_HISTORY` (ASH histórico, muestra sub-conjunto de `V$ACTIVE_SESSION_HISTORY` persistido en cada snapshot AWR) también desde 10g.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`container_scope: ANY_CONTAINER` (corregido en Compatibility Hardening — era `CDB_ROOT`, valor inválido para 10g/11g donde Multitenant no existe; ver misma corrección y razonamiento en `Q-PERF-WAIT-AWR-001`). `database_role_scope: PRIMARY` por la misma razón en ambas queries: ASH refleja actividad de sesiones de usuario, mínima o nula en un Standby en mount — ver `skills/performance/wait-events/SKILL.md`.

# Cost classification rationale

El volumen de filas escala con: duración de la ventana × número de sesiones activas × frecuencia de muestreo (1 seg en ASH). Sin `time_window` acotado y `max_rows` estricto, el costo es impredecible — de ahí `cost_class: HIGH` y la exigencia de ventana obligatoria en `workflows/awr.md#gates`.

# License notes

Diagnostics Pack. Sin confirmación de licencia, el hallazgo que consuma esta evidencia queda `capability_status: LICENSE_RESTRICTED` con alternativa (`Q-PERF-WAIT-STATSPACK-001`, de menor granularidad) — ver `policies/licensing-awareness-policy.md`.

# Sanitization notes

`sql_id` → KEEP (no es SQL text); `session_id`/`session_serial#` → KEEP (no identifican usuario final); ningún dato de aplicación ni bind value se lee en esta query.

# Evolution via `/change query`

Cambios de ventana máxima/columnas por versión vía `/change compatibility`; cambio de `cost_class` vía `/change query` con justificación.

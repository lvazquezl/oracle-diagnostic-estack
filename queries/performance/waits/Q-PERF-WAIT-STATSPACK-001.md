---
query_id: Q-PERF-WAIT-STATSPACK-001
version: 1.0.0

domain: performance
purpose: Top wait events por tiempo total de espera en una ventana Statspack (fallback sin Diagnostics Pack)

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [STATS$SYSTEM_EVENT, STATS$SNAPSHOT]
privileges_required: [SELECT on STATS$SYSTEM_EVENT, SELECT on STATS$SNAPSHOT]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 60
max_rows: 200
max_output_bytes: 262144

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_medium.sh, tests/test_statspack_10g.sh, tests/test_statspack_11g.sh, tests/test_statspack_without_diagnostic_pack.sh, tests/test_statspack_waits.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT e.instance_number,
       e.event AS event_name,
       CASE
         WHEN e.event LIKE 'db file%read%' OR e.event LIKE 'direct path read%'                THEN 'User I/O'
         WHEN e.event LIKE 'log file%'                                                          THEN 'Commit'
         WHEN e.event IN ('latch free','buffer busy waits','enqueue')                           THEN 'Concurrency'
         WHEN e.event LIKE 'SQL*Net%'                                                           THEN 'Network'
         WHEN e.event LIKE 'gc %'                                                               THEN 'Cluster'
         ELSE 'Other'
       END AS wait_class_derived,
       SUM(e.time_waited_micro) / 1e6 AS total_wait_time_sec
FROM   stats$system_event e
JOIN   stats$snapshot s
       ON  s.snap_id = e.snap_id
       AND s.instance_number = e.instance_number
WHERE  s.snap_time BETWEEN :window_start AND :window_end
  AND  e.event NOT IN ('rdbms ipc message','SQL*Net message from client','pipe get',
                        'PX Idle Wait','Streams AQ: waiting for messages in the queue')
GROUP  BY e.instance_number, e.event
ORDER  BY total_wait_time_sec DESC
FETCH FIRST 20 ROWS ONLY;                 -- 12c+; usar ROWNUM <= 20 en 10g/11g
```

Statspack no expone `wait_class` como columna nativa (esa taxonomía es de AWR/`V$SYSTEM_EVENT` 10g+) — `wait_class_derived` es una aproximación conservadora por patrón de nombre, documentada como tal, nunca presentada como el `wait_class` oficial de AWR. No intentar equivalencia 1:1 con `Q-PERF-WAIT-AWR-001`; ver `skills/performance/statspack-analysis/SKILL.md#normal-behavior` para el criterio de `PARTIALLY_SUPPORTED` cuando la comparación cruzada AWR↔Statspack se solicite explícitamente.

# Notes by version

`STATS$SYSTEM_EVENT`/`STATS$SNAPSHOT` requieren el paquete Statspack instalado manualmente por el DBA (`spcreate.sql`, no viene precargado) — disponible desde muy anterior a 10g y sin cambios estructurales relevantes 10g–23ai para estas dos tablas específicas. `TIME_WAITED_MICRO` (sin distinción foreground/background, a diferencia de `TIME_WAITED_MICRO_FG` de AWR 11g+) es la única columna de tiempo disponible en toda la ventana declarada — no hay equivalente `_FG` en Statspack en ninguna versión, por lo que no hay riesgo de columna version-gated aquí.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`ANY_CONTAINER` — Statspack es un esquema de tablas propio (`PERFSTAT`), no `CON_ID`-scoped; en un target CDB, Statspack se instala típicamente en `CDB$ROOT` o en una PDB específica según decisión del DBA, y esta query opera sobre el esquema donde esté instalado. `database_role_scope: PRIMARY` — igual razón que `Q-PERF-WAIT-AWR-001`/`Q-PERF-WAIT-ASH-001`: refleja actividad de sesión de usuario, mínima o nula en standby en mount.

# License notes

Ninguna — Statspack no requiere Diagnostics Pack ni ningún otro licenciamiento adicional; es la ruta explícitamente diseñada para targets sin esa licencia (ver `policies/licensing-awareness-policy.md#alternativa-cuando-la-licencia-no-se-puede-confirmar`). Requiere que el DBA haya instalado el paquete Statspack manualmente — si `STATS$SYSTEM_EVENT`/`STATS$SNAPSHOT` no existen, el hallazgo se reporta `UNDETERMINED` (paquete no instalado), nunca `LICENSE_RESTRICTED` (no es un problema de licencia).

# Sanitization notes

`event_name`/`wait_class_derived` → KEEP (no sensibles); `instance_number` → KEEP. No se lee SQL text en esta query.

# Evolution via `/change query`

Ampliar a Load Profile/SQL statistics/Instance Activity de Statspack (`STATS$SQL_SUMMARY`, `STATS$SYSSTAT`) vía `/change query` cuando se justifique — fuera de alcance de esta query, acotada a wait events (ver `docs/PHASE_3_ORACLE_PERFORMANCE.md#limitations`).

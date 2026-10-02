---
query_id: Q-PERF-PARALLEL-001
version: 1.1.0

domain: performance
purpose: Sesiones/procesos paralelos activos y estadísticas acumuladas de Parallel Execution

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$PX_SESSION, V$PQ_SYSSTAT]
privileges_required: [SELECT on V$PX_SESSION, SELECT on V$PQ_SYSSTAT]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 200
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_low.sh, tests/test_parallelism_detection.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT px.qcsid,
       px.sid,
       px.server_group,
       px.server_set,
       px.server#                AS server_no,
       px.degree,
       px.req_degree
FROM   v$px_session px
ORDER  BY px.qcsid, px.server_group, px.server_set, px.server#;
```

`V$PQ_SYSSTAT` (estadísticas acumuladas: `Servers Busy`, `Servers Started`, `Servers Shutdown`, `Queries Parallelized`) se lee como segunda evidencia por el skill vía `Q-PERF-PARALLEL-STAT-001` cuando se requiere tendencia agregada en vez de sesiones activas puntuales — fuera de esta query base (mantenida acotada a una sola sentencia).

# Notes by version

`V$PX_SESSION` estable 10g–23ai en las columnas usadas.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`ANY_CONTAINER` — vista de instancia. `database_role_scope: PRIMARY` — Parallel Execution de queries de aplicación es actividad de foreground, mínima en standby en mount fuera de apply.

# License notes

Ninguna (Parallel Execution en sí no requiere Diagnostics/Tuning Pack; la restricción de edición aplica en Standard Edition, fuera de alcance de este e-stack determinar).

# Sanitization notes

`sql_id` → KEEP (no es SQL text).

CHG-ESTACK-COLLECTOR-FACTORY-B2 — 1.1.0: `V$PX_SESSION` no tiene `SERVER_NAME` ni `SQL_ID` (columnas de `V$PX_PROCESS`/`V$SESSION`); se usan `SERVER_GROUP`, `SERVER_SET` y `SERVER#`, que sí existen. Validar en el lab.

# Evolution via `/change query`

`Q-PERF-PARALLEL-STAT-001` (V$PQ_SYSSTAT agregado) vía `/change query` si `performance/parallelism` lo requiere de forma sistemática.

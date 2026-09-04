---
query_id: Q-PERF-DBTIME-CURRENT-001
version: 1.0.0

domain: performance
purpose: DB Time y DB CPU acumulados desde el arranque de la instancia — ruta estándar sin Diagnostics Pack

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$SYS_TIME_MODEL, V$INSTANCE]
privileges_required: [SELECT on V$SYS_TIME_MODEL, SELECT on V$INSTANCE]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 5
max_output_bytes: 4096

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_low.sh, tests/test_performance_without_diagnostic_pack.sh, tests/test_standard_path_db_cpu.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT MAX(CASE WHEN stat_name = 'DB time' THEN value END) / 1e6 AS db_time_sec_since_startup,
       MAX(CASE WHEN stat_name = 'DB CPU'  THEN value END) / 1e6 AS db_cpu_sec_since_startup,
       (SELECT (SYSDATE - startup_time) * 86400 FROM v$instance)  AS uptime_sec
FROM   v$sys_time_model
WHERE  stat_name IN ('DB time', 'DB CPU');
```

Sin ventana histórica — refleja el acumulado desde `STARTUP_TIME` de la instancia. Útil como snapshot puntual o para comparación before/after tomando dos lecturas manuales; no reemplaza AWR/Statspack para una ventana pasada específica. Es la base de la ruta `performance-standard-path` (sección 40 del prompt de Fase 3) cuando ni Diagnostics Pack ni Statspack están disponibles.

# Notes by version

`V$SYS_TIME_MODEL` disponible desde 10g, sin licenciamiento adicional (a diferencia de su contraparte histórica `DBA_HIST_SYS_TIME_MODEL`, que sí requiere Diagnostics Pack). Sin diferencias estructurales relevantes 10g–23ai.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`ANY_CONTAINER` — vista dinámica de instancia, no `CON_ID`-scoped de forma restrictiva para esta lectura agregada. `database_role_scope: PRIMARY` — igual razón que el resto de queries DB Time/DB CPU.

# License notes

Ninguna — esta es explícitamente la alternativa no licenciada a `Q-PERF-DBTIME-001`.

# Sanitization notes

Todos los campos → KEEP.

# Evolution via `/change query`

Ninguno previsto — query estable de baja complejidad.

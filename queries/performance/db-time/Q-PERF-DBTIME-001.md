---
query_id: Q-PERF-DBTIME-001
version: 1.0.0

domain: performance
purpose: DB Time y DB CPU agregados por instancia sobre una ventana AWR (Load Profile base)

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [DBA_HIST_SYS_TIME_MODEL, DBA_HIST_SNAPSHOT]
privileges_required: [SELECT on DBA_HIST_SYS_TIME_MODEL, SELECT on DBA_HIST_SNAPSHOT]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 30
max_rows: 100
max_output_bytes: 131072

sensitivity: LOW
sanitization_required: true

license_requirements: [Diagnostics Pack]

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_medium.sh, tests/test_awr_db_time.sh, tests/test_awr_db_cpu.sh, tests/test_awr_requires_license_gate.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT t.instance_number,
       MAX(CASE WHEN t.stat_name = 'DB time' THEN t.value END) / 1e6      AS db_time_sec,
       MAX(CASE WHEN t.stat_name = 'DB CPU'  THEN t.value END) / 1e6      AS db_cpu_sec,
       (s.end_interval_time - s.begin_interval_time) * 86400              AS elapsed_sec
FROM   dba_hist_sys_time_model t
JOIN   dba_hist_snapshot s
       ON  s.snap_id = t.snap_id
       AND s.instance_number = t.instance_number
WHERE  s.end_interval_time BETWEEN :window_start AND :window_end
  AND  t.stat_name IN ('DB time', 'DB CPU')
GROUP  BY t.instance_number, s.snap_id, s.begin_interval_time, s.end_interval_time
ORDER  BY t.instance_number, s.end_interval_time;
```

`DB time` y `DB CPU` son acumulativos desde el inicio de la instancia dentro de `DBA_HIST_SYS_TIME_MODEL` — el valor útil para una ventana es la diferencia entre el snapshot de cierre y el de apertura de la ventana, no un único snapshot aislado; el agente que consume esta evidencia calcula el delta entre snapshots consecutivos, esta query devuelve los valores acumulados por snapshot para que ese delta se calcule con `time_window` explícito.

# Notes by version

`DBA_HIST_SYS_TIME_MODEL` disponible desde 10g junto con el resto del modelo AWR. Sin diferencias estructurales relevantes 10g–23ai en las columnas usadas aquí.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`ANY_CONTAINER` — ver razonamiento de `Q-PERF-WAIT-AWR-001`. `database_role_scope: PRIMARY` — DB Time refleja trabajo de sesión de usuario/foreground, mínimo o nulo en standby en mount.

# License notes

Diagnostics Pack. Sin confirmación, cae a `Q-PERF-DBTIME-CURRENT-001` (`V$SYS_TIME_MODEL`, sin ventana histórica, sin licencia) — ver `policies/licensing-awareness-policy.md`.

# Sanitization notes

Todos los campos → KEEP (métricas agregadas, no identifican usuario ni contienen datos de aplicación).

# Evolution via `/change query`

Ampliar a desglose por `stat_name` adicional (`sql execute elapsed time`, `parse time elapsed`, etc.) vía `/change query` cuando un skill lo requiera explícitamente.

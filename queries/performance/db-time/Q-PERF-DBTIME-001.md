---
query_id: Q-PERF-DBTIME-001
version: 2.0.0

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

variants:
  - variant_id: Q-PERF-DBTIME-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2)"
  - variant_id: Q-PERF-DBTIME-001-V2
    label: multitenant_aware
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (multitenant_aware, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_medium.sh, tests/test_awr_db_time.sh, tests/test_awr_db_cpu.sh, tests/test_awr_requires_license_gate.sh, tests/test_awr_cumulative_counters_use_deltas.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2)

```sql
SELECT instance_number, snap_id, elapsed_sec,
       ROUND((db_time - LAG(db_time) OVER (PARTITION BY dbid, instance_number, startup_time ORDER BY snap_id)) / 1e6, 2) AS db_time_sec,
       ROUND((db_cpu  - LAG(db_cpu)  OVER (PARTITION BY dbid, instance_number, startup_time ORDER BY snap_id)) / 1e6, 2) AS db_cpu_sec
FROM  (SELECT s.dbid, s.instance_number, s.snap_id, s.startup_time,
              ROUND((CAST(s.end_interval_time AS DATE) - CAST(s.begin_interval_time AS DATE)) * 86400) AS elapsed_sec,
              MAX(CASE WHEN t.stat_name = 'DB time' THEN t.value END)                                  AS db_time,
              MAX(CASE WHEN t.stat_name = 'DB CPU'  THEN t.value END)                                  AS db_cpu
       FROM   dba_hist_sys_time_model t
       JOIN   dba_hist_snapshot s
              ON  s.dbid = t.dbid AND s.snap_id = t.snap_id AND s.instance_number = t.instance_number
       WHERE  s.end_interval_time BETWEEN :window_start AND :window_end
         AND  t.stat_name IN ('DB time', 'DB CPU')
       GROUP  BY s.dbid, s.instance_number, s.snap_id, s.startup_time, s.begin_interval_time, s.end_interval_time)
ORDER  BY instance_number, snap_id;
```

# Statement / procedure (read-only) — Variant V2 (multitenant_aware, 12.1+)

```sql
SELECT instance_number, snap_id, elapsed_sec,
       ROUND((db_time - LAG(db_time) OVER (PARTITION BY dbid, instance_number, startup_time ORDER BY snap_id)) / 1e6, 2) AS db_time_sec,
       ROUND((db_cpu  - LAG(db_cpu)  OVER (PARTITION BY dbid, instance_number, startup_time ORDER BY snap_id)) / 1e6, 2) AS db_cpu_sec
FROM  (SELECT s.dbid, s.instance_number, s.snap_id, s.startup_time,
              ROUND((CAST(s.end_interval_time AS DATE) - CAST(s.begin_interval_time AS DATE)) * 86400) AS elapsed_sec,
              MAX(CASE WHEN t.stat_name = 'DB time' THEN t.value END)                                  AS db_time,
              MAX(CASE WHEN t.stat_name = 'DB CPU'  THEN t.value END)                                  AS db_cpu
       FROM   dba_hist_sys_time_model t
       JOIN   dba_hist_snapshot s
              ON  s.dbid = t.dbid AND s.snap_id = t.snap_id AND s.instance_number = t.instance_number
       WHERE  s.end_interval_time BETWEEN :window_start AND :window_end
         AND  t.stat_name IN ('DB time', 'DB CPU')
         AND  t.con_dbid = t.dbid
       GROUP  BY s.dbid, s.instance_number, s.snap_id, s.startup_time, s.begin_interval_time, s.end_interval_time)
ORDER  BY instance_number, snap_id;
```

`DB time` y `DB CPU` de `DBA_HIST_SYS_TIME_MODEL` son **acumulados** desde el arranque. Cada fila es un snapshot de la ventana (`end_interval_time` en `[window_start, window_end]`) con la carga del intervalo que termina en él: la diferencia con el snapshot anterior de la misma instancia y el mismo arranque (`LAG … PARTITION BY dbid, instance_number, startup_time`). El primer snapshot de la ventana o de un arranque queda con delta nulo; para tener ese intervalo, abre la ventana un snapshot antes. `db_time_sec / elapsed_sec` = sesiones activas promedio (AAS) del intervalo. V2 (12.1+) filtra `con_dbid = dbid` para conservar sólo las filas de nivel CDB/instancia.

Con carga casi nula (menos de ~1 s de DB time por hora) AWR puede registrar deltas de DB CPU mayores que los de DB time (verificado en el lab con valores crudos, ver `docs/AWR_LICENSED.md`): en ese rango la proporción CPU/DB time no es significativa.

# Notes by version

`DBA_HIST_SYS_TIME_MODEL` disponible desde 10g junto con el resto del modelo AWR. `CON_DBID` existe desde 12.1, por eso V2.

**2.0.0 — CHG-ESTACK-AWR-BIND-QUERIES-001:** la 1.0.0 tenía tres defectos:
- devolvía los valores **acumulados** de cada snapshot, cuando la nota (y los fixtures de los skills) los trataban como carga del intervalo;
- calculaba `elapsed_sec` multiplicando un `INTERVAL DAY TO SECOND` por 86400, lo que da otro `INTERVAL` y no segundos;
- el join con `DBA_HIST_SNAPSHOT` no incluía `dbid`.

Ahora devuelve deltas por arranque, `elapsed_sec` numérico (vía `CAST … AS DATE`) y `snap_id` para la trazabilidad.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`ANY_CONTAINER` — ver razonamiento de `Q-PERF-WAIT-AWR-001`. `database_role_scope: PRIMARY` — DB Time refleja trabajo de sesión de usuario/foreground, mínimo o nulo en standby en mount.

# License notes

Diagnostics Pack. Sin confirmación, cae a `Q-PERF-DBTIME-CURRENT-001` (`V$SYS_TIME_MODEL`, sin ventana histórica, sin licencia) — ver `policies/licensing-awareness-policy.md`.

# Sanitization notes

Todos los campos → KEEP (métricas agregadas, no identifican usuario ni contienen datos de aplicación).

# Evolution via `/change query`

2.0.0: CHG-ESTACK-AWR-BIND-QUERIES-001 (deltas por arranque, `elapsed_sec` numérico, `dbid` en el join, variantes). Ampliar a desglose por `stat_name` adicional (`sql execute elapsed time`, `parse time elapsed`, etc.) vía `/change query` cuando un skill lo requiera explícitamente.

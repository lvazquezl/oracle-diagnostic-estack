---
query_id: Q-PERF-AWR-DBTIME-24H-001
version: 1.0.0

domain: performance
purpose: DB time y DB CPU por snapshot AWR de las últimas 24 h (deltas entre snapshots) — carga por intervalo

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [DBA_HIST_SYS_TIME_MODEL, DBA_HIST_SNAPSHOT]
privileges_required: [SELECT on DBA_HIST_SYS_TIME_MODEL, SELECT on DBA_HIST_SNAPSHOT]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 20
max_rows: 200
max_output_bytes: 32768

sensitivity: LOW
sanitization_required: true

license_requirements: [Diagnostics Pack]

execution_mode: READ_ONLY

variants:
  - variant_id: Q-PERF-AWR-DBTIME-24H-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2)"
  - variant_id: Q-PERF-AWR-DBTIME-24H-001-V2
    label: multitenant_aware
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (multitenant_aware, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_every_logical_query_has_variant.sh, tests/test_collector_factory.sh, tests/test_awr_cumulative_counters_use_deltas.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2)

```sql
SELECT instance_number, snap_hours_ago, elapsed_sec,
       ROUND((db_time - LAG(db_time) OVER (PARTITION BY dbid, instance_number, startup_time ORDER BY snap_id)) / 1e6, 2) AS db_time_sec,
       ROUND((db_cpu  - LAG(db_cpu)  OVER (PARTITION BY dbid, instance_number, startup_time ORDER BY snap_id)) / 1e6, 2) AS db_cpu_sec
FROM  (SELECT s.dbid, s.instance_number, s.snap_id, s.startup_time,
              ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(s.end_interval_time AS DATE)) * 24, 2)                AS snap_hours_ago,
              ROUND((CAST(s.end_interval_time AS DATE) - CAST(s.begin_interval_time AS DATE)) * 86400)        AS elapsed_sec,
              MAX(CASE WHEN t.stat_name = 'DB time' THEN t.value END)                                         AS db_time,
              MAX(CASE WHEN t.stat_name = 'DB CPU'  THEN t.value END)                                         AS db_cpu
       FROM   dba_hist_sys_time_model t
       JOIN   dba_hist_snapshot s
              ON  s.dbid = t.dbid AND s.snap_id = t.snap_id AND s.instance_number = t.instance_number
       WHERE  s.end_interval_time >= SYSTIMESTAMP - INTERVAL '1' DAY
         AND  t.stat_name IN ('DB time', 'DB CPU')
       GROUP  BY s.dbid, s.instance_number, s.snap_id, s.startup_time, s.end_interval_time, s.begin_interval_time)
ORDER  BY instance_number, snap_id;
```

# Statement / procedure (read-only) — Variant V2 (multitenant_aware, 12.1+)

```sql
SELECT instance_number, snap_hours_ago, elapsed_sec,
       ROUND((db_time - LAG(db_time) OVER (PARTITION BY dbid, instance_number, startup_time ORDER BY snap_id)) / 1e6, 2) AS db_time_sec,
       ROUND((db_cpu  - LAG(db_cpu)  OVER (PARTITION BY dbid, instance_number, startup_time ORDER BY snap_id)) / 1e6, 2) AS db_cpu_sec
FROM  (SELECT s.dbid, s.instance_number, s.snap_id, s.startup_time,
              ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(s.end_interval_time AS DATE)) * 24, 2)                AS snap_hours_ago,
              ROUND((CAST(s.end_interval_time AS DATE) - CAST(s.begin_interval_time AS DATE)) * 86400)        AS elapsed_sec,
              MAX(CASE WHEN t.stat_name = 'DB time' THEN t.value END)                                         AS db_time,
              MAX(CASE WHEN t.stat_name = 'DB CPU'  THEN t.value END)                                         AS db_cpu
       FROM   dba_hist_sys_time_model t
       JOIN   dba_hist_snapshot s
              ON  s.dbid = t.dbid AND s.snap_id = t.snap_id AND s.instance_number = t.instance_number
       WHERE  s.end_interval_time >= SYSTIMESTAMP - INTERVAL '1' DAY
         AND  t.stat_name IN ('DB time', 'DB CPU')
         AND  t.con_dbid = t.dbid
       GROUP  BY s.dbid, s.instance_number, s.snap_id, s.startup_time, s.end_interval_time, s.begin_interval_time)
ORDER  BY instance_number, snap_id;
```

Los valores de `DBA_HIST_SYS_TIME_MODEL` son **acumulados** desde el arranque: la carga de cada intervalo es la diferencia con el snapshot anterior de la misma instancia y el mismo arranque (`LAG ... PARTITION BY dbid, instance_number, startup_time`). El primer snapshot de la ventana o de un arranque queda con delta nulo: el intervalo arranque → primer snapshot no se reporta (como en el reporte AWR, que no cruza reinicios), y ahí suele concentrarse el DB time del arranque. `db_time_sec / elapsed_sec` = sesiones activas promedio (AAS) del intervalo. **V2 (12.1+) filtra `con_dbid = dbid`**: en un CDB, AWR puede guardar también filas por contenedor; el filtro conserva las de nivel CDB/instancia (en non-CDB no cambia nada).

**Interpretación con carga baja:** en un intervalo casi ocioso, el delta de DB CPU puede **superar** al de DB time. Lo muestran los propios valores de `DBA_HIST_SYS_TIME_MODEL`, no el cálculo: en el lab, snaps 94→98, ΔDB CPU 1.25/0.83/1.12/1.06 s contra ΔDB time 0.92/0.53/0.67/0.69 s, verificado contra los valores crudos. Con menos de ~1 s de DB time por hora, la proporción CPU/DB time no es significativa; no la reportes como hallazgo.

# Notes by version

AWR y `DBA_HIST_SYS_TIME_MODEL` desde 10g; funciones analíticas desde 8i.

# Notes by platform

Ninguna diferencia.

# Container / role scope notes

`ANY_CONTAINER`: desde `CDB$ROOT` AWR describe la instancia completa. `PRIMARY`: en un standby no se generan snapshots AWR locales (salvo configuración remota de AWR).

# Cost classification rationale

`MEDIUM`: lee snapshots AWR de una ventana fija (24 h) o ASH en memoria (60 min), agrega en la base y acota filas.

# License notes

**Requiere Oracle Diagnostics Pack.** El gateway sólo la ejecuta si el target declara `license_status.diagnostics_pack = CONFIRMED` (confirmación humana del contrato; `CONTROL_MANAGEMENT_PACK_ACCESS` no prueba la licencia). En la ruta humana exige `--license-confirmed diagnostics_pack --confirmed-by <revisor>`.

# Sanitization notes

Sólo números (instancia, horas hacia atrás, segundos) → KEEP. Sin fechas absolutas.

# Evolution via `/change query`

CHG-ESTACK-AWR-LICENSED-001 — creada para el lote B4 (AWR/ASH con ventana fija, sin binds).

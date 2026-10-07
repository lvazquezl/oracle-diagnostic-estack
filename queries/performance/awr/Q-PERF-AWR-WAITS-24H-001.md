---
query_id: Q-PERF-AWR-WAITS-24H-001
version: 1.0.0

domain: performance
purpose: Top 20 eventos de espera no idle de las últimas 24 h según AWR (deltas entre snapshots)

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [DBA_HIST_SYSTEM_EVENT, DBA_HIST_SNAPSHOT]
privileges_required: [SELECT on DBA_HIST_SYSTEM_EVENT, SELECT on DBA_HIST_SNAPSHOT]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 20
max_rows: 20
max_output_bytes: 32768

sensitivity: LOW
sanitization_required: true

license_requirements: [Diagnostics Pack]

execution_mode: READ_ONLY

variants:
  - variant_id: Q-PERF-AWR-WAITS-24H-001-V1
    label: legacy_rownum
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_rownum, 10.2–11.2)"
  - variant_id: Q-PERF-AWR-WAITS-24H-001-V2
    label: modern_fetch_first
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_fetch_first, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_every_logical_query_has_variant.sh, tests/test_collector_factory.sh, tests/test_awr_cumulative_counters_use_deltas.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_rownum, 10.2–11.2)

```sql
SELECT *
FROM  (SELECT event_name, wait_class, SUM(waits) AS total_waits, ROUND(SUM(waited) / 1e6, 2) AS time_waited_sec
       FROM  (SELECT e.event_name, e.wait_class,
                     MAX(e.total_waits) - MIN(e.total_waits)             AS waits,
                     MAX(e.time_waited_micro) - MIN(e.time_waited_micro) AS waited
              FROM   dba_hist_system_event e
              JOIN   dba_hist_snapshot s
                     ON  s.dbid = e.dbid AND s.snap_id = e.snap_id AND s.instance_number = e.instance_number
              WHERE  s.end_interval_time >= SYSTIMESTAMP - INTERVAL '1' DAY
                AND  e.wait_class <> 'Idle'
              GROUP  BY e.dbid, e.instance_number, s.startup_time, e.event_name, e.wait_class)
       GROUP  BY event_name, wait_class
       ORDER  BY SUM(waited) DESC)
WHERE  ROWNUM <= 20;
```

# Statement / procedure (read-only) — Variant V2 (modern_fetch_first, 12.1+)

```sql
SELECT event_name, wait_class, SUM(waits) AS total_waits, ROUND(SUM(waited) / 1e6, 2) AS time_waited_sec
FROM  (SELECT e.event_name, e.wait_class,
              MAX(e.total_waits) - MIN(e.total_waits)             AS waits,
              MAX(e.time_waited_micro) - MIN(e.time_waited_micro) AS waited
       FROM   dba_hist_system_event e
       JOIN   dba_hist_snapshot s
              ON  s.dbid = e.dbid AND s.snap_id = e.snap_id AND s.instance_number = e.instance_number
       WHERE  s.end_interval_time >= SYSTIMESTAMP - INTERVAL '1' DAY
         AND  e.wait_class <> 'Idle'
         AND  e.con_dbid = e.dbid
       GROUP  BY e.dbid, e.instance_number, s.startup_time, e.event_name, e.wait_class)
GROUP  BY event_name, wait_class
ORDER  BY SUM(waited) DESC
FETCH  FIRST 20 ROWS ONLY;
```

`TOTAL_WAITS` y `TIME_WAITED_MICRO` de `DBA_HIST_SYSTEM_EVENT` son **acumulados** desde el arranque: la espera de la ventana es `MAX - MIN` por instancia y por arranque (`startup_time`), sumada después. Sumar los valores tal cual (como hace `Q-PERF-WAIT-AWR-001`) cuenta varias veces la misma espera. V2 (12.1+) filtra `con_dbid = dbid` para no mezclar filas por contenedor en un CDB.

# Notes by version

AWR desde 10g; `FETCH FIRST` desde 12.1 (V2).

# Notes by platform

Ninguna diferencia.

# Container / role scope notes

`ANY_CONTAINER`: desde `CDB$ROOT` AWR describe la instancia completa. `PRIMARY`: en un standby no se generan snapshots AWR locales (salvo configuración remota de AWR).

# Cost classification rationale

`MEDIUM`: lee snapshots AWR de una ventana fija (24 h) o ASH en memoria (60 min), agrega en la base y acota filas.

# License notes

**Requiere Oracle Diagnostics Pack.** El gateway sólo la ejecuta si el target declara `license_status.diagnostics_pack = CONFIRMED` (confirmación humana del contrato; `CONTROL_MANAGEMENT_PACK_ACCESS` no prueba la licencia). En la ruta humana exige `--license-confirmed diagnostics_pack --confirmed-by <revisor>`.

# Sanitization notes

`event_name` → nombre de evento Oracle; `wait_class` → enum; números → KEEP.

# Evolution via `/change query`

CHG-ESTACK-AWR-LICENSED-001 — creada para el lote B4 (AWR/ASH con ventana fija, sin binds).

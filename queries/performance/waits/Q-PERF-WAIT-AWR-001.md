---
query_id: Q-PERF-WAIT-AWR-001
version: 3.0.0

domain: performance
purpose: Top wait events por tiempo total de espera en una ventana AWR

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [DBA_HIST_SYSTEM_EVENT, DBA_HIST_SNAPSHOT]
privileges_required: [SELECT on DBA_HIST_SYSTEM_EVENT, SELECT on DBA_HIST_SNAPSHOT]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 60
max_rows: 200
max_output_bytes: 262144

sensitivity: MEDIUM
sanitization_required: true

license_requirements: [Diagnostics Pack]

execution_mode: READ_ONLY

variants:
  - variant_id: Q-PERF-WAIT-AWR-001-V1
    label: legacy_10g
    oracle_versions: {min: "10.2", max: "10.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g, 10.2)"
  - variant_id: Q-PERF-WAIT-AWR-001-V2
    label: legacy_11g_foreground
    oracle_versions: {min: "11.1", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (legacy_11g_foreground, 11.1–11.2)"
  - variant_id: Q-PERF-WAIT-AWR-001-V3
    label: modern_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V3 (modern_12plus, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_medium.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh, tests/test_awr_cumulative_counters_use_deltas.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g, 10.2)

```sql
SELECT *
FROM  (SELECT instance_number, event_name, wait_class, ROUND(SUM(waited) / 1e6, 2) AS total_wait_time_sec
       FROM  (SELECT e.instance_number, e.event_name, e.wait_class,
                     MAX(e.time_waited_micro) - MIN(e.time_waited_micro) AS waited
              FROM   dba_hist_system_event e
              JOIN   dba_hist_snapshot s
                     ON  s.dbid = e.dbid AND s.snap_id = e.snap_id AND s.instance_number = e.instance_number
              WHERE  s.end_interval_time BETWEEN :window_start AND :window_end
                AND  e.wait_class <> 'Idle'
              GROUP  BY e.dbid, e.instance_number, s.startup_time, e.event_name, e.wait_class)
       GROUP  BY instance_number, event_name, wait_class
       ORDER  BY SUM(waited) DESC)
WHERE  ROWNUM <= 20;
```

# Statement / procedure (read-only) — Variant V2 (legacy_11g_foreground, 11.1–11.2)

```sql
SELECT *
FROM  (SELECT instance_number, event_name, wait_class, ROUND(SUM(waited) / 1e6, 2) AS total_wait_time_sec
       FROM  (SELECT e.instance_number, e.event_name, e.wait_class,
                     MAX(e.time_waited_micro_fg) - MIN(e.time_waited_micro_fg) AS waited
              FROM   dba_hist_system_event e
              JOIN   dba_hist_snapshot s
                     ON  s.dbid = e.dbid AND s.snap_id = e.snap_id AND s.instance_number = e.instance_number
              WHERE  s.end_interval_time BETWEEN :window_start AND :window_end
                AND  e.wait_class <> 'Idle'
              GROUP  BY e.dbid, e.instance_number, s.startup_time, e.event_name, e.wait_class)
       GROUP  BY instance_number, event_name, wait_class
       ORDER  BY SUM(waited) DESC)
WHERE  ROWNUM <= 20;
```

# Statement / procedure (read-only) — Variant V3 (modern_12plus, 12.1+)

```sql
SELECT instance_number, event_name, wait_class, ROUND(SUM(waited) / 1e6, 2) AS total_wait_time_sec
FROM  (SELECT e.instance_number, e.event_name, e.wait_class,
              MAX(e.time_waited_micro_fg) - MIN(e.time_waited_micro_fg) AS waited
       FROM   dba_hist_system_event e
       JOIN   dba_hist_snapshot s
              ON  s.dbid = e.dbid AND s.snap_id = e.snap_id AND s.instance_number = e.instance_number
       WHERE  s.end_interval_time BETWEEN :window_start AND :window_end
         AND  e.wait_class <> 'Idle'
         AND  e.con_dbid = e.dbid
       GROUP  BY e.dbid, e.instance_number, s.startup_time, e.event_name, e.wait_class)
GROUP  BY instance_number, event_name, wait_class
ORDER  BY SUM(waited) DESC
FETCH  FIRST 20 ROWS ONLY;
```

`TIME_WAITED_MICRO` y `TIME_WAITED_MICRO_FG` de `DBA_HIST_SYSTEM_EVENT` son **acumulados** desde el arranque de la instancia. La espera de la ventana es `MAX − MIN` por `dbid`, instancia, arranque (`startup_time`) y evento, sumada después por instancia y evento. Es lo mismo que un reporte AWR entre el primer y el último snapshot cuyo `end_interval_time` cae en `[window_start, window_end]`. Si hubo un reinicio en la ventana, cada arranque aporta su propio tramo. El intervalo que termina en el primer snapshot de la ventana no se cuenta (no hay snapshot base dentro de la ventana); para incluirlo, abre la ventana un snapshot antes. Una ventana con un solo snapshot por arranque da 0.

Requiere Diagnostics Pack confirmado para el target (gate de licencias del gateway y `--license-confirmed diagnostics_pack --confirmed-by <revisor>` en la ruta humana). Fallback sin licencia: `Q-PERF-WAIT-STATSPACK-001` sobre `STATS$SYSTEM_EVENT`.

# Notes by version

- **PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING** (resuelto): esta nota ya advertía "`FETCH FIRST ... ROWS ONLY` no existe antes de 12c; en 10g/11g envolver en subquery con `ROWNUM`" desde v2.1.0, pero la propia query certificaba una única sentencia `FETCH FIRST` con `min_version` 10.2 — la advertencia nunca se implementó como variante real. Detectado por `tests/test_no_fetch_first_in_pre12c_queries.sh`, corregido con V1 (10g-11g, `ROWNUM`)/V2 (12.1+, `FETCH FIRST`).
- `TIME_WAITED_MICRO_FG` (foreground) preferido sobre `TIME_WAITED_MICRO` desde 11g para aislar espera de sesiones de usuario. **No existe en 10g** (`compatibility/oracle-dictionary/views.yaml`): hasta 2.2.0 la V1 lo usaba también en 10.2. Desde 3.0.0 la V1 (10.2) usa `TIME_WAITED_MICRO` (foreground + background) y lo dice en su etiqueta.
- **3.0.0 — CHG-ESTACK-AWR-BIND-QUERIES-001:** hasta 2.2.0 la query sumaba los valores acumulados de todos los snapshots de la ventana, con lo que contaba la misma espera varias veces (con N snapshots, hasta N veces). Además, el join con `DBA_HIST_SNAPSHOT` no incluía `dbid`: si había AWR importado de otra base, una fila podía emparejarse con un snapshot ajeno que tuviera el mismo `snap_id`. Ahora calcula deltas por arranque, une por `dbid` y, en 12.1+, filtra `con_dbid = dbid`.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`ANY_CONTAINER` (corregido en Compatibility Hardening — era `CDB_ROOT`, valor inválido para 10g/11g donde Multitenant no existe). En 12c+, la disponibilidad de `DBA_HIST_*` consultado desde dentro de una PDB específica varía por release/edición; `oracle-performance-analyst` debe validar que la query devuelva filas y, si no, degradar el `capability_status` a `UNDETERMINED` (ver `docs/CONTRACTS.md#capability-status-model`) en lugar de asumir soporte — nunca reportar ausencia de wait events como "sin contención".

# Sanitization notes

`event_name`/`wait_class` → KEEP (no sensibles); `instance_number` → KEEP. No se lee SQL text en esta query (eso es `Q-PERF-TOPSQL-*`, con su propia política de sanitización de SQL text).

# Evolution via `/change query`

Cambios de ventana/columnas por versión vía `/change compatibility`; cambio de top-N vía `/change policy`. 3.0.0: CHG-ESTACK-AWR-BIND-QUERIES-001 (deltas por arranque, `dbid` en el join, V1 propia para 10g).

---
query_id: Q-PERF-WAIT-AWR-001
version: 2.2.0

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
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10g-11g)"
  - variant_id: Q-PERF-WAIT-AWR-001-V2
    label: modern_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_12plus, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_medium.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10g-11g)

```sql
SELECT *
FROM (
  SELECT e.instance_number,
         e.event_name,
         e.wait_class,
         SUM(e.time_waited_micro_fg) / 1e6 AS total_wait_time_sec
  FROM   dba_hist_system_event e
  JOIN   dba_hist_snapshot s
         ON  s.snap_id = e.snap_id
         AND s.instance_number = e.instance_number
  WHERE  s.end_interval_time BETWEEN :window_start AND :window_end
    AND  e.wait_class <> 'Idle'
  GROUP  BY e.instance_number, e.event_name, e.wait_class
  ORDER  BY total_wait_time_sec DESC
)
WHERE  ROWNUM <= 20;
```

# Statement / procedure (read-only) — Variant V2 (modern_12plus, 12.1+)

```sql
SELECT e.instance_number,
       e.event_name,
       e.wait_class,
       SUM(e.time_waited_micro_fg) / 1e6 AS total_wait_time_sec
FROM   dba_hist_system_event e
JOIN   dba_hist_snapshot s
       ON  s.snap_id = e.snap_id
       AND s.instance_number = e.instance_number
WHERE  s.end_interval_time BETWEEN :window_start AND :window_end
  AND  e.wait_class <> 'Idle'
GROUP  BY e.instance_number, e.event_name, e.wait_class
ORDER  BY total_wait_time_sec DESC
FETCH  FIRST 20 ROWS ONLY;
```

Requiere Diagnostics Pack licenciado (marcar `LICENSE_CHECK_REQUIRED` en el finding que consuma esta evidencia). Fallback: `Q-PERF-WAIT-STATSPACK-001` sobre `STATS$SYSTEM_EVENT`.

# Notes by version

- **PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING** (resuelto): esta nota ya advertía "`FETCH FIRST ... ROWS ONLY` no existe antes de 12c; en 10g/11g envolver en subquery con `ROWNUM`" desde v2.1.0, pero la propia query certificaba una única sentencia `FETCH FIRST` con `min_version` 10.2 — la advertencia nunca se implementó como variante real. Detectado por `tests/test_no_fetch_first_in_pre12c_queries.sh`, corregido con V1 (10g-11g, `ROWNUM`)/V2 (12.1+, `FETCH FIRST`).
- `TIME_WAITED_MICRO_FG` (foreground) preferido sobre `TIME_WAITED_MICRO` desde 11g para aislar espera de sesiones de usuario.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`ANY_CONTAINER` (corregido en Compatibility Hardening — era `CDB_ROOT`, valor inválido para 10g/11g donde Multitenant no existe). En 12c+, la disponibilidad de `DBA_HIST_*` consultado desde dentro de una PDB específica varía por release/edición; `oracle-performance-analyst` debe validar que la query devuelva filas y, si no, degradar el `capability_status` a `UNDETERMINED` (ver `docs/CONTRACTS.md#capability-status-model`) en lugar de asumir soporte — nunca reportar ausencia de wait events como "sin contención".

# Sanitization notes

`event_name`/`wait_class` → KEEP (no sensibles); `instance_number` → KEEP. No se lee SQL text en esta query (eso es `Q-PERF-TOPSQL-*`, con su propia política de sanitización de SQL text).

# Evolution via `/change query`

Cambios de ventana/columnas por versión vía `/change compatibility`; cambio de top-N vía `/change policy`.

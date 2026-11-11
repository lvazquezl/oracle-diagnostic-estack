---
query_id: Q-PERF-AWR-STARTUP-HISTORY-001
version: 1.0.0

domain: performance
purpose: Historial de arranques por instancia desde AWR: arranques en 7 y 30 días, horas desde el último, versiones distintas registradas y horas de historia AWR disponible

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_HIST_DATABASE_INSTANCE, DBA_HIST_SNAPSHOT, V$DATABASE]
privileges_required: [SELECT on DBA_HIST_DATABASE_INSTANCE, SELECT on DBA_HIST_SNAPSHOT, SELECT on V$DATABASE]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 64
max_output_bytes: 8192

sensitivity: LOW
sanitization_required: true

license_requirements: [Diagnostics Pack]

execution_mode: READ_ONLY

variants:
  - variant_id: Q-PERF-AWR-STARTUP-HISTORY-001-V1
    label: all_versions
    oracle_versions: {min: "10.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (all_versions, 10.2–23.0: agregado por instancia)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_collector_factory.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (all_versions, 10.2–23.0: agregado por instancia)

```sql
SELECT i.instance_number,
       COUNT(DISTINCT i.startup_time) AS startups_in_awr,
       COUNT(DISTINCT CASE WHEN CAST(i.startup_time AS DATE) > SYSDATE - 7 THEN i.startup_time END) AS startups_last_7d,
       COUNT(DISTINCT CASE WHEN CAST(i.startup_time AS DATE) > SYSDATE - 30 THEN i.startup_time END) AS startups_last_30d,
       ROUND((SYSDATE - CAST(MAX(i.startup_time) AS DATE)) * 24, 1) AS hours_since_last_startup,
       COUNT(DISTINCT i.version) AS versions_in_awr,
       ROUND((SYSDATE - (SELECT CAST(MIN(s.begin_interval_time) AS DATE)
                         FROM   dba_hist_snapshot s
                         WHERE  s.dbid = i.dbid AND s.instance_number = i.instance_number)) * 24, 1) AS hours_of_awr_history
FROM   dba_hist_database_instance i
WHERE  i.dbid = (SELECT d.dbid FROM v$database d)
GROUP  BY i.dbid, i.instance_number
ORDER  BY i.instance_number;
```

# Notes by version

`DBA_HIST_DATABASE_INSTANCE` existe desde 10.1 con las mismas columnas usadas. Una sola variante.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

Desde `CDB$ROOT` se leen los arranques de la CDB (el `DBID` de `V$DATABASE`). Un arranque por instancia genera una fila; `COUNT(DISTINCT startup_time)` evita contar dos veces el mismo arranque. Solo cubre la ventana de retención de AWR (`hours_of_awr_history`); un arranque más viejo no se ve y nunca se infiere su ausencia.

# Cost classification rationale

`LOW` — una fila por arranque registrado en AWR.

# License notes

**Requiere Oracle Diagnostics Pack** (vistas `DBA_HIST_*`). El gateway solo la ejecuta si el target declara `license_status.diagnostics_pack = CONFIRMED`. Sin licencia confirmada el collector es `LICENSE_RESTRICTED` y la estabilidad de la instancia se evalúa solo con `uptime_hours` de `Q-ORA-INSTANCE-STATE-001`.

# Sanitization notes

Solo conteos y horas por instancia. Nombres de host, de instancia, fechas absolutas y el texto de versión nunca salen: `versions_in_awr` > 1 indica un cambio de versión (upgrade o parche que cambia la versión) dentro de la ventana.

# Evolution via `/change query`

1.0.0 CHG-ESTACK-C-NEW-QUERIES-001: creación (lote CL, cobertura del assessment). Vive en la familia AWR (`queries/performance/awr/`): Oracle Core no depende de packs opcionales (`tests/test_oracle_core_respects_license_gate.sh`).

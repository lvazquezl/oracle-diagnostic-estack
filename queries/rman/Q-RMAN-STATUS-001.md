---
query_id: Q-RMAN-STATUS-001
version: 1.0.0

domain: rman
purpose: Estado/progreso de jobs RMAN (sesión, comando, operación recursiva) — normaliza COMPLETED/COMPLETED WITH WARNINGS/FAILED/RUNNING/UNKNOWN

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$RMAN_STATUS]
privileges_required: [SELECT on V$RMAN_STATUS]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 20
max_rows: 500
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

# Verificado vía WebFetch (docs.oracle.com .../19/refrn/V-RMAN_STATUS.html): columnas SID, RECID,
# STAMP, PARENT_RECID, PARENT_STAMP, SESSION_RECID, SESSION_STAMP, ROW_LEVEL, ROW_TYPE, COMMAND_ID,
# OPERATION, STATUS, MBYTES_PROCESSED, START_TIME, END_TIME, INPUT_BYTES, OUTPUT_BYTES, OPTIMIZED,
# OBJECT_TYPE, OUTPUT_DEVICE_TYPE, OSB_ALLOCATED, CON_ID. Introducida en Oracle Database 10g
# (verificado vía oracle-base.com "RMAN Enhancements in Oracle Database 10g") — sin variante por
# versión necesaria dentro de 10g-23ai. STATUS real reportado por RMAN incluye COMPLETED, COMPLETED
# WITH WARNINGS, FAILED, RUNNING — no se inventa ningún mapping adicional (# 12 del prompt).
variants:
  - variant_id: Q-RMAN-STATUS-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10g-11g)"
  - variant_id: Q-RMAN-STATUS-001-V2
    label: modern_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_12plus, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_rman_status_query.sh, tests/test_rman_query_version_compatibility.sh, tests/test_rman_query_cost.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh, tests/test_rman_modern_variant_12c.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10g-11g)

```sql
SELECT *
FROM (
  SELECT session_recid, row_type, operation, status, start_time, end_time,
         input_bytes, output_bytes, output_device_type, object_type
  FROM   v$rman_status
  WHERE  row_type IN ('SESSION', 'COMMAND')
  ORDER  BY start_time DESC
)
WHERE  ROWNUM <= 500;
```

`ORDER BY` vive dentro del inline view, antes de aplicar `ROWNUM` — preserva el mismo Top-N por `start_time DESC` que la variante moderna (`# 30` del prompt de este hardening: nunca `ROWNUM` fuera de un inline view ya ordenado).

# Statement / procedure (read-only) — Variant V2 (modern_12plus, 12.1+)

```sql
SELECT session_recid, row_type, operation, status, start_time, end_time,
       input_bytes, output_bytes, output_device_type, object_type
FROM   v$rman_status
WHERE  row_type IN ('SESSION', 'COMMAND')
ORDER  BY start_time DESC
FETCH  FIRST 500 ROWS ONLY;
```

`ROW_TYPE = 'SESSION'` acota a las sesiones RMAN de nivel superior (evita explotar cada operación recursiva). Ordenado por más reciente primero — el consumidor pide `time_window`/`status_filter` explícito para inventarios grandes (`# 35` del prompt).

# Notes by version

`V$RMAN_STATUS` combina información en memoria (jobs en curso) y del controlfile (jobs completos) — un job `RUNNING` puede desaparecer si la sesión RMAN ya no está activa en memoria y no llegó a completarse (comportamiento documentado, no un bug). `STATUS` se normaliza tal cual la reporta la vista — `COMPLETED`, `COMPLETED WITH WARNINGS`, `FAILED`, `RUNNING`; cualquier otro valor se reporta como `UNKNOWN`, nunca se fuerza a uno de los anteriores.

**PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING**: v1.0.0 declaraba una única variante `min: "10.2"` usando `FETCH FIRST ... ROWS ONLY` — sintaxis ANSI SQL:2008 (row limiting clause) introducida en Oracle Database 12.1, no disponible en 10g/11g (ver `compatibility/oracle-sql-syntax/features.yaml`). Corregido: V1 (10g-11g) usa `ROWNUM` sobre inline view ya ordenado; V2 (12.1+) mantiene `FETCH FIRST`. Vistas/columnas certificadas sin cambios (`# 28` del prompt de este hardening).

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`. `database_role_scope: ANY`.

# Cost classification rationale

`MEDIUM` — el historial de jobs puede crecer con el tiempo; `FETCH FIRST 500 ROWS ONLY` y `time_window`/`status_filter` opcionales acotan el volumen (`# 35` del prompt).

# License notes

Ninguna.

# Sanitization notes

Ninguna columna sensible por defecto — `OUTPUT_DEVICE_TYPE`/`OBJECT_TYPE` son metadata operacional, no identifican el ambiente.

# Evolution via `/change query`

N/A — vista estable desde 10g.

---
query_id: Q-PERF-TEMP-001
version: 1.1.0

domain: performance
purpose: Uso activo de TEMP por sesión/SQL_ID (sorts/hashes con spill a disco), snapshot actual

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$SORT_USAGE, V$SESSION]
privileges_required: [SELECT on V$SORT_USAGE, SELECT on V$SESSION]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 15
max_rows: 200
max_output_bytes: 65536

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-PERF-TEMP-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10g-11g)"
  - variant_id: Q-PERF-TEMP-001-V2
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
  SELECT su.session_addr,
         s.sid,
         s.serial#,
         s.sql_id,
         su.tablespace,
         su.contents,
         su.blocks * (SELECT value FROM v$parameter WHERE name = 'db_block_size') AS bytes_used
  FROM   v$sort_usage su
  JOIN   v$session s
         ON  s.saddr = su.session_addr
  ORDER  BY bytes_used DESC
)
WHERE  ROWNUM <= 50;
```

# Statement / procedure (read-only) — Variant V2 (modern_12plus, 12.1+)

```sql
SELECT su.session_addr,
       s.sid,
       s.serial#,
       s.sql_id,
       su.tablespace,
       su.contents,
       su.blocks * (SELECT value FROM v$parameter WHERE name = 'db_block_size') AS bytes_used
FROM   v$sort_usage su
JOIN   v$session s
       ON  s.saddr = su.session_addr
ORDER  BY bytes_used DESC
FETCH  FIRST 50 ROWS ONLY;
```

A diferencia de `Q-ORA-TEMP-001` (Oracle Core — capacidad/configuración de tempfiles vía `DBA_TEMP_FILES`/`DBA_TEMP_FREE_SPACE`), esta query mide **uso activo en este momento**: qué sesión/SQL_ID está consumiendo TEMP ahora mismo por spill de sort/hash a disco — la dimensión de rendimiento, no de capacidad. `performance/temp` usa ambas: `Q-ORA-TEMP-001` para el contexto de capacidad, `Q-PERF-TEMP-001` para atribuir el consumo actual a una sesión/SQL_ID concreto.

# Notes by version

`V$SORT_USAGE` disponible desde 10g (requiere `SELECT_CATALOG_ROLE` o el grant equivalente en `ESTACK_DIAGNOSTIC_ROLE`). Sin diferencias estructurales relevantes 10g–23ai.

**PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING**: mismo defecto/corrección que `Q-PERF-BLOCKING-001` — `FETCH FIRST` con `min_version` 10.2 sin variante legacy real, detectado por `tests/test_no_fetch_first_in_pre12c_queries.sh`.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`ANY_CONTAINER` — vista de instancia. `database_role_scope: PRIMARY` — uso activo de TEMP refleja sorts/hashes de sesiones de usuario, mínimo en standby en mount.

# License notes

Ninguna.

# Sanitization notes

`sql_id` → KEEP (no es SQL text); `sid`/`serial#` → KEEP (no identifican usuario final); `tablespace` → KEEP.

# Evolution via `/change query`

Ninguno previsto.

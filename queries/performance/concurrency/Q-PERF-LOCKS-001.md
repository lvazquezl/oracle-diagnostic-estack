---
query_id: Q-PERF-LOCKS-001
version: 2.0.0

domain: performance
purpose: Enqueue locks por tipo y lock_mode (por contenedor desde 12.1): cantidad, en espera, bloqueando y segundos máximos en el modo — snapshot actual, sin sesiones ni objetos

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$LOCK]
privileges_required: [SELECT on V$LOCK]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 15
max_rows: 200
max_output_bytes: 32768

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-PERF-LOCKS-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2: sin con_id)"
  - variant_id: Q-PERF-LOCKS-001-V2
    label: cdb_aware_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_12plus, 12.1–23.0: por contenedor)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_medium.sh, tests/test_locking_analysis.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2: sin con_id)

```sql
SELECT lock_type, lock_mode, COUNT(*) AS locks,
       SUM(CASE WHEN request > 0 THEN 1 ELSE 0 END) AS waiting,
       SUM(CASE WHEN block > 0 THEN 1 ELSE 0 END) AS blocking,
       MAX(ctime) AS max_seconds_in_mode
FROM  (SELECT CASE WHEN type IN ('AE', 'CF', 'CI', 'CU', 'DL', 'DX', 'HW', 'JQ', 'KO', 'MR', 'PS', 'RT', 'SQ', 'ST', 'TM', 'TO', 'TS', 'TT', 'TX', 'UL', 'US', 'XR') THEN type ELSE 'OTHER' END AS lock_type,
              DECODE(lmode, 0, 'None', 1, 'Null', 2, 'Row-S', 3, 'Row-X', 4, 'Share', 5, 'S/Row-X', 6, 'Exclusive', 'Unknown') AS lock_mode,
              request, block, ctime
       FROM   v$lock)
GROUP  BY lock_type, lock_mode
ORDER  BY lock_type, lock_mode;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_12plus, 12.1–23.0: por contenedor)

```sql
SELECT con_id, lock_type, lock_mode, COUNT(*) AS locks,
       SUM(CASE WHEN request > 0 THEN 1 ELSE 0 END) AS waiting,
       SUM(CASE WHEN block > 0 THEN 1 ELSE 0 END) AS blocking,
       MAX(ctime) AS max_seconds_in_mode
FROM  (SELECT con_id, CASE WHEN type IN ('AE', 'CF', 'CI', 'CU', 'DL', 'DX', 'HW', 'JQ', 'KO', 'MR', 'PS', 'RT', 'SQ', 'ST', 'TM', 'TO', 'TS', 'TT', 'TX', 'UL', 'US', 'XR') THEN type ELSE 'OTHER' END AS lock_type,
              DECODE(lmode, 0, 'None', 1, 'Null', 2, 'Row-S', 3, 'Row-X', 4, 'Share', 5, 'S/Row-X', 6, 'Exclusive', 'Unknown') AS lock_mode,
              request, block, ctime
       FROM   v$lock)
GROUP  BY con_id, lock_type, lock_mode
ORDER  BY con_id, lock_type, lock_mode;
```

# Notes by version

`V$LOCK.CON_ID` desde 12.1.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`; en RAC solo la instancia consultada (`V$LOCK`, no `GV$LOCK`). La cadena de bloqueo por sesión la entrega `Q-PERF-BLOCKING-001`.

# Cost classification rationale

`MEDIUM` — `V$LOCK` puede ser costosa en instancias con muchas sesiones; agrega en la base.

# License notes

Ninguna.

# Sanitization notes

Sin `SID`, `SERIAL#`, `SQL_ID`, `ID1` ni `ID2` (identifican objetos y transacciones): solo el tipo de enqueue (lista cerrada; el resto como `OTHER`), el `lock_mode` traducido, conteos y segundos. `lock_mode` `None` con `waiting` > 0 son sesiones esperando el lock.

# Evolution via `/change query`

2.0.0 CHG-ESTACK-B8-OPS-COVERAGE-001: agregado por contenedor, tipo y `lock_mode`; sesiones, `SQL_ID` e identificadores de objeto fuera; sin join con `V$SESSION`.

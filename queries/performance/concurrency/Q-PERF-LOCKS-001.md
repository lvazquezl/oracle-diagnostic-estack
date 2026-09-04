---
query_id: Q-PERF-LOCKS-001
version: 1.0.0

domain: performance
purpose: Enqueue locks activos por modo/tipo, snapshot actual

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$LOCK, V$SESSION]
privileges_required: [SELECT on V$LOCK, SELECT on V$SESSION]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 15
max_rows: 500
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_medium.sh, tests/test_locking_analysis.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT l.sid,
       s.serial#,
       l.type,
       DECODE(l.lmode, 0,'None',1,'Null',2,'Row-S',3,'Row-X',4,'Share',5,'S/Row-X',6,'Exclusive', 'Unknown') AS lock_mode,
       l.id1,
       l.id2,
       l.block,
       s.sql_id
FROM   v$lock l
JOIN   v$session s ON s.sid = l.sid
WHERE  l.lmode > 0
ORDER  BY l.block DESC, l.sid
FETCH FIRST 200 ROWS ONLY;                -- 12c+; usar ROWNUM <= 200 en 10g/11g
```

Complementa `Q-PERF-BLOCKING-001` (cadena blocker/waiter) con el detalle de tipo/modo de lock (`TX`, `TM`, `UL`, etc.) para `performance/locking`, distinto de `performance/blocking` que se centra en la relación sesión-a-sesión.

# Notes by version

`V$LOCK` estable 10g–23ai en las columnas usadas.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`ANY_CONTAINER` — vista de instancia. `database_role_scope: PRIMARY` — locking de aplicación no aplica en standby en mount.

# License notes

Ninguna.

# Sanitization notes

`sql_id` → KEEP (no es SQL text); `sid`/`serial#` → KEEP.

# Evolution via `/change query`

Ninguno previsto.

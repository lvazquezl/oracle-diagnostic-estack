---
query_id: Q-PERF-LOCKS-001
version: 1.1.0

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

variants:
  - variant_id: Q-PERF-LOCKS-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10g-11g)"
  - variant_id: Q-PERF-LOCKS-001-V2
    label: modern_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_12plus, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_medium.sh, tests/test_locking_analysis.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10g-11g)

```sql
SELECT *
FROM (
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
)
WHERE  ROWNUM <= 200;
```

# Statement / procedure (read-only) — Variant V2 (modern_12plus, 12.1+)

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
FETCH  FIRST 200 ROWS ONLY;
```

Complementa `Q-PERF-BLOCKING-001` (cadena blocker/waiter) con el detalle de tipo/modo de lock (`TX`, `TM`, `UL`, etc.) para `performance/locking`, distinto de `performance/blocking` que se centra en la relación sesión-a-sesión.

# Notes by version

`V$LOCK` estable 10g–23ai en las columnas usadas.

**PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING**: mismo defecto y corrección que `Q-PERF-BLOCKING-001` — `FETCH FIRST` certificado con `min_version` 10.2 sin variante legacy real. Detectado por `tests/test_no_fetch_first_in_pre12c_queries.sh`.

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

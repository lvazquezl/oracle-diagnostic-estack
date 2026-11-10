---
query_id: Q-ORA-UNDO-STATS-001
version: 1.0.0

domain: oracle
purpose: Estadísticas de UNDO de las últimas 24 h por contenedor: undo generado, consulta más larga, retención ajustada, ORA-01555, falta de espacio, robos de extents y reparto activo/no expirado/expirado del último intervalo

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$UNDOSTAT, V$PARAMETER]
privileges_required: [SELECT on V$UNDOSTAT, SELECT on V$PARAMETER]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 64
max_output_bytes: 16384

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-ORA-UNDO-STATS-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2: una fila)"
  - variant_id: Q-ORA-UNDO-STATS-001-V2
    label: per_container_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (per_container_12plus, 12.1–23.0: por con_id)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_collector_factory.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2: una fila)

```sql
SELECT COUNT(*) AS undo_intervals,
       ROUND(SUM(u.undoblks) * p.block_size / 1048576, 1) AS undo_generated_mb,
       MAX(u.maxquerylen) AS max_query_seconds,
       MAX(u.maxconcurrency) AS max_concurrency,
       MIN(u.tuned_undoretention) AS min_tuned_retention_seconds,
       MAX(u.tuned_undoretention) AS max_tuned_retention_seconds,
       SUM(u.ssolderrcnt) AS snapshot_too_old_errors,
       SUM(u.nospaceerrcnt) AS undo_space_errors,
       SUM(u.unxpstealcnt) AS unexpired_steals,
       SUM(u.expstealcnt) AS expired_steals,
       ROUND(MAX(u.activeblks) KEEP (DENSE_RANK LAST ORDER BY u.begin_time) * p.block_size / 1048576, 1) AS active_undo_mb,
       ROUND(MAX(u.unexpiredblks) KEEP (DENSE_RANK LAST ORDER BY u.begin_time) * p.block_size / 1048576, 1) AS unexpired_undo_mb,
       ROUND(MAX(u.expiredblks) KEEP (DENSE_RANK LAST ORDER BY u.begin_time) * p.block_size / 1048576, 1) AS expired_undo_mb
FROM   v$undostat u,
       (SELECT TO_NUMBER(MAX(value)) AS block_size FROM v$parameter WHERE name = 'db_block_size') p
WHERE  u.begin_time >= SYSDATE - 1
GROUP  BY p.block_size;
```

# Statement / procedure (read-only) — Variant V2 (per_container_12plus, 12.1–23.0: por con_id)

```sql
SELECT u.con_id,
       COUNT(*) AS undo_intervals,
       ROUND(SUM(u.undoblks) * p.block_size / 1048576, 1) AS undo_generated_mb,
       MAX(u.maxquerylen) AS max_query_seconds,
       MAX(u.maxconcurrency) AS max_concurrency,
       MIN(u.tuned_undoretention) AS min_tuned_retention_seconds,
       MAX(u.tuned_undoretention) AS max_tuned_retention_seconds,
       SUM(u.ssolderrcnt) AS snapshot_too_old_errors,
       SUM(u.nospaceerrcnt) AS undo_space_errors,
       SUM(u.unxpstealcnt) AS unexpired_steals,
       SUM(u.expstealcnt) AS expired_steals,
       ROUND(MAX(u.activeblks) KEEP (DENSE_RANK LAST ORDER BY u.begin_time) * p.block_size / 1048576, 1) AS active_undo_mb,
       ROUND(MAX(u.unexpiredblks) KEEP (DENSE_RANK LAST ORDER BY u.begin_time) * p.block_size / 1048576, 1) AS unexpired_undo_mb,
       ROUND(MAX(u.expiredblks) KEEP (DENSE_RANK LAST ORDER BY u.begin_time) * p.block_size / 1048576, 1) AS expired_undo_mb
FROM   v$undostat u,
       (SELECT TO_NUMBER(MAX(value)) AS block_size FROM v$parameter WHERE name = 'db_block_size') p
WHERE  u.begin_time >= SYSDATE - 1
GROUP  BY u.con_id, p.block_size
ORDER  BY u.con_id;
```

# Notes by version

`ACTIVEBLKS`, `UNEXPIREDBLKS`, `EXPIREDBLKS` y `TUNED_UNDORETENTION` desde 10.2. `V$UNDOSTAT` guarda intervalos de 10 minutos de los últimos 4 días; se leen las últimas 24 h. `CON_ID` desde 12.1.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

Con undo local (12.2+), cada PDB tiene sus filas; con undo compartido, todo está en el contenedor del undo. Los MB usan `db_block_size`: el tablespace de UNDO siempre usa el tamaño de bloque estándar. Complementa a `Q-ORA-UNDO-001` (configuración). `PRIMARY`: en un standby no hay actividad propia.

# Cost classification rationale

`LOW` — 144 filas por contenedor en 24 h.

# License notes

Ninguna.

# Sanitization notes

Solo conteos, segundos y MB por contenedor. `MAXQUERYID` (sql_id de la consulta más larga) y las fechas absolutas nunca se seleccionan.

# Evolution via `/change query`

1.0.0 CHG-ESTACK-C-NEW-QUERIES-001: creación (lote C, cobertura del assessment).

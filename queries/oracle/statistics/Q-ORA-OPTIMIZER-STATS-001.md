---
query_id: Q-ORA-OPTIMIZER-STATS-001
version: 1.0.0

domain: oracle
purpose: Estado de las estadísticas del optimizer por contenedor y tipo de dueño (fixed objects, Oracle, propios): tablas sin estadísticas, obsoletas, bloqueadas y antigüedad del último análisis

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [DBA_TAB_STATISTICS, CDB_TAB_STATISTICS, CDB_USERS]
privileges_required: [SELECT on DBA_TAB_STATISTICS, SELECT on CDB_TAB_STATISTICS, SELECT on CDB_USERS]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 60
max_rows: 64
max_output_bytes: 16384

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-ORA-OPTIMIZER-STATS-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2: SYS/SYSTEM como Oracle)"
  - variant_id: Q-ORA-OPTIMIZER-STATS-001-V2
    label: cdb_12_1_0_1
    oracle_versions: {min: "12.1", max: "12.1.0.1"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_12_1_0_1, 12.1.0.1: por contenedor, SYS/SYSTEM como Oracle)"
  - variant_id: Q-ORA-OPTIMIZER-STATS-001-V3
    label: cdb_oracle_maintained
    oracle_versions: {min: "12.1.0.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V3 (cdb_oracle_maintained, 12.1.0.2+: por contenedor con ORACLE_MAINTAINED)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_collector_factory.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2: SYS/SYSTEM como Oracle)

```sql
SELECT owner_kind,
       COUNT(*) AS tables,
       SUM(CASE WHEN last_analyzed IS NULL THEN 1 ELSE 0 END) AS tables_without_stats,
       SUM(CASE WHEN stale_stats = 'YES' THEN 1 ELSE 0 END) AS tables_stale,
       SUM(CASE WHEN stattype_locked IS NOT NULL THEN 1 ELSE 0 END) AS tables_stats_locked,
       ROUND((SYSDATE - MIN(last_analyzed)) * 24, 1) AS max_hours_since_analyzed,
       ROUND((SYSDATE - MAX(last_analyzed)) * 24, 1) AS min_hours_since_analyzed
FROM  (SELECT CASE WHEN s.object_type = 'FIXED TABLE' THEN 'FIXED'
                    WHEN s.owner IN ('SYS', 'SYSTEM') THEN 'ORACLE' ELSE 'OTHER' END AS owner_kind,
               s.last_analyzed, s.stale_stats, s.stattype_locked
        FROM   dba_tab_statistics s
        WHERE  s.object_type IN ('TABLE', 'FIXED TABLE')
         AND  s.table_name NOT LIKE 'BIN$%')
GROUP  BY owner_kind
ORDER  BY owner_kind;
```

# Statement / procedure (read-only) — Variant V2 (cdb_12_1_0_1, 12.1.0.1: por contenedor, SYS/SYSTEM como Oracle)

```sql
SELECT con_id, owner_kind,
       COUNT(*) AS tables,
       SUM(CASE WHEN last_analyzed IS NULL THEN 1 ELSE 0 END) AS tables_without_stats,
       SUM(CASE WHEN stale_stats = 'YES' THEN 1 ELSE 0 END) AS tables_stale,
       SUM(CASE WHEN stattype_locked IS NOT NULL THEN 1 ELSE 0 END) AS tables_stats_locked,
       ROUND((SYSDATE - MIN(last_analyzed)) * 24, 1) AS max_hours_since_analyzed,
       ROUND((SYSDATE - MAX(last_analyzed)) * 24, 1) AS min_hours_since_analyzed
FROM  (SELECT s.con_id,
               CASE WHEN s.object_type = 'FIXED TABLE' THEN 'FIXED'
                    WHEN s.owner IN ('SYS', 'SYSTEM') THEN 'ORACLE' ELSE 'OTHER' END AS owner_kind,
               s.last_analyzed, s.stale_stats, s.stattype_locked
        FROM   cdb_tab_statistics s
        WHERE  s.object_type IN ('TABLE', 'FIXED TABLE')
         AND  s.table_name NOT LIKE 'BIN$%')
GROUP  BY con_id, owner_kind
ORDER  BY con_id, owner_kind;
```

# Statement / procedure (read-only) — Variant V3 (cdb_oracle_maintained, 12.1.0.2+: por contenedor con ORACLE_MAINTAINED)

```sql
SELECT con_id, owner_kind,
       COUNT(*) AS tables,
       SUM(CASE WHEN last_analyzed IS NULL THEN 1 ELSE 0 END) AS tables_without_stats,
       SUM(CASE WHEN stale_stats = 'YES' THEN 1 ELSE 0 END) AS tables_stale,
       SUM(CASE WHEN stattype_locked IS NOT NULL THEN 1 ELSE 0 END) AS tables_stats_locked,
       ROUND((SYSDATE - MIN(last_analyzed)) * 24, 1) AS max_hours_since_analyzed,
       ROUND((SYSDATE - MAX(last_analyzed)) * 24, 1) AS min_hours_since_analyzed
FROM  (SELECT s.con_id,
               CASE WHEN s.object_type = 'FIXED TABLE' THEN 'FIXED'
                    WHEN u.oracle_maintained = 'Y' THEN 'ORACLE' ELSE 'CUSTOM' END AS owner_kind,
               s.last_analyzed, s.stale_stats, s.stattype_locked
        FROM   cdb_tab_statistics s
        LEFT   JOIN cdb_users u ON u.con_id = s.con_id AND u.username = s.owner
        WHERE  s.object_type IN ('TABLE', 'FIXED TABLE')
         AND  s.table_name NOT LIKE 'BIN$%')
GROUP  BY con_id, owner_kind
ORDER  BY con_id, owner_kind;
```

# Notes by version

`STALE_STATS` y `STATTYPE_LOCKED` existen desde 10.2. `CDB_USERS.ORACLE_MAINTAINED` desde 12.1.0.2: antes solo `SYS` y `SYSTEM` se clasifican como Oracle y el resto sale `OTHER` (mezcla esquemas de Oracle y propios).

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

12.1+: `CDB_TAB_STATISTICS` desde `CDB$ROOT` cubre cada contenedor abierto. Cuenta solo tablas (`TABLE`) y fixed objects (`FIXED TABLE`), sin particiones ni la papelera (`BIN$`). Las tablas temporales globales y externas cuentan como tablas: sin estadísticas puede ser lo esperado en ellas. `STALE_STATS` refleja el último flush de monitoreo DML; puede ir atrasado algunas horas. `PRIMARY`: en un standby las estadísticas son las del primario.

# Cost classification rationale

`MEDIUM` — recorre el diccionario de estadísticas de tablas de todos los contenedores (decenas de miles de filas en bases grandes); devuelve a lo más una fila por contenedor y tipo de dueño. Timeout 60 s.

# License notes

Ninguna.

# Sanitization notes

Solo conteos y horas por contenedor y tipo de dueño. Nombres de tablas y de esquemas nunca salen de la base: `owner_kind` dice si son fixed objects, de Oracle o propios.

# Evolution via `/change query`

1.0.0 CHG-ESTACK-C-NEW-QUERIES-001: creación (lote C, cobertura del assessment).

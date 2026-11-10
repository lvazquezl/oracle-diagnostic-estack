---
query_id: Q-ORA-DATABASE-MODE-001
version: 1.0.0

domain: oracle
purpose: Modo de la base: ARCHIVELOG, force logging, supplemental logging mínimo, open mode, edición, CDB y block change tracking — identidad y protección del redo

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$DATABASE, V$VERSION, V$BLOCK_CHANGE_TRACKING]
privileges_required: [SELECT on V$DATABASE, SELECT on V$VERSION, SELECT on V$BLOCK_CHANGE_TRACKING]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 1
max_output_bytes: 4096

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-ORA-DATABASE-MODE-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2: sin CDB)"
  - variant_id: Q-ORA-DATABASE-MODE-001-V2
    label: cdb_aware_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_12plus, 12.1–23.0: agrega CDB)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_collector_factory.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2: sin CDB)

```sql
SELECT d.log_mode, d.force_logging, d.supplemental_log_data_min, d.open_mode, d.db_unique_name,
       (SELECT CASE WHEN v.banner LIKE '%Enterprise Edition%' THEN 'ENTERPRISE'
                    WHEN v.banner LIKE '%Standard Edition 2%' THEN 'STANDARD_EDITION_2'
                    WHEN v.banner LIKE '%Standard Edition%' THEN 'STANDARD_EDITION'
                    WHEN v.banner LIKE '%Express Edition%' THEN 'EXPRESS'
                    WHEN v.banner LIKE '%Personal%' THEN 'PERSONAL'
                    WHEN v.banner LIKE '%Free%' THEN 'FREE'
                    ELSE 'UNKNOWN' END
        FROM   v$version v
        WHERE  v.banner LIKE 'Oracle Database%' AND ROWNUM = 1) AS edition,
       (SELECT b.status FROM v$block_change_tracking b) AS block_change_tracking
FROM   v$database d;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_12plus, 12.1–23.0: agrega CDB)

```sql
SELECT d.log_mode, d.force_logging, d.supplemental_log_data_min, d.open_mode, d.db_unique_name, d.cdb,
       (SELECT CASE WHEN v.banner LIKE '%Enterprise Edition%' THEN 'ENTERPRISE'
                    WHEN v.banner LIKE '%Standard Edition 2%' THEN 'STANDARD_EDITION_2'
                    WHEN v.banner LIKE '%Standard Edition%' THEN 'STANDARD_EDITION'
                    WHEN v.banner LIKE '%Express Edition%' THEN 'EXPRESS'
                    WHEN v.banner LIKE '%Personal%' THEN 'PERSONAL'
                    WHEN v.banner LIKE '%Free%' THEN 'FREE'
                    ELSE 'UNKNOWN' END
        FROM   v$version v
        WHERE  v.banner LIKE 'Oracle Database%' AND ROWNUM = 1) AS edition,
       (SELECT b.status FROM v$block_change_tracking b) AS block_change_tracking
FROM   v$database d;
```

# Notes by version

`V$DATABASE.CDB` desde 12.1. Desde 18c `FORCE_LOGGING` puede valer `STANDBY NOLOGGING FOR DATA AVAILABILITY` o `STANDBY NOLOGGING FOR LOAD PERFORMANCE`. El banner de `V$VERSION` nombra la edición desde 12.1 en todas las ediciones; en 10g/11g Standard Edition el banner no la nombra y la edición sale `UNKNOWN`, nunca se infiere.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`V$DATABASE` y `V$BLOCK_CHANGE_TRACKING` son de la base completa: en una CDB, el modo ARCHIVELOG, force logging y block change tracking son de la CDB y aplican a todas las PDB. `open_mode` es el del contenedor de la sesión. En un standby `open_mode` distingue `MOUNTED` de `READ ONLY WITH APPLY` (Active Data Guard).

# Cost classification rationale

`LOW` — vistas de una fila.

# License notes

Ninguna. Leer la edición no la licencia; la edición sirve para filtrar qué features aplican (por ejemplo, Standard Edition no incluye Partitioning).

# Sanitization notes

`db_unique_name` se enmascara. Del banner de `V$VERSION` solo sale la edición como palabra cerrada, nunca el texto. `block_change_tracking` es el estado; el nombre del archivo de tracking nunca se selecciona.

# Evolution via `/change query`

1.0.0 CHG-ESTACK-C-NEW-QUERIES-001: creación (lote C, cobertura del assessment).

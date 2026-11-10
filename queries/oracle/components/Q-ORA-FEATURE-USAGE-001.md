---
query_id: Q-ORA-FEATURE-USAGE-001
version: 1.0.0

domain: oracle
purpose: Features de Oracle con uso detectado (DBA_FEATURE_USAGE_STATISTICS) por contenedor: usos detectados, uso actual y antigüedad del primer y último uso — insumo de revisión de licencias, nunca prueba de licencia

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_FEATURE_USAGE_STATISTICS, CDB_FEATURE_USAGE_STATISTICS, V$DATABASE]
privileges_required: [SELECT on DBA_FEATURE_USAGE_STATISTICS, SELECT on CDB_FEATURE_USAGE_STATISTICS, SELECT on V$DATABASE]

risk_class: R0
cost_class: LOW

timeout_seconds: 20
max_rows: 500
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-ORA-FEATURE-USAGE-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2: DBID actual)"
  - variant_id: Q-ORA-FEATURE-USAGE-001-V2
    label: cdb_aware_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_12plus, 12.1–23.0: por contenedor)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_collector_factory.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2: DBID actual)

```sql
SELECT f.name AS feature_name,
       MAX(f.detected_usages) AS detected_usages,
       MAX(f.currently_used) AS currently_used,
       ROUND((SYSDATE - MAX(f.last_usage_date)) * 24, 1) AS hours_since_last_usage,
       ROUND((SYSDATE - MIN(f.first_usage_date)) * 24, 1) AS hours_since_first_usage,
       ROUND((SYSDATE - MAX(f.last_sample_date)) * 24, 1) AS hours_since_last_sample
FROM   dba_feature_usage_statistics f
WHERE  f.dbid = (SELECT d.dbid FROM v$database d)
  AND  f.detected_usages > 0
GROUP  BY f.name
ORDER  BY f.name;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_12plus, 12.1–23.0: por contenedor)

```sql
SELECT f.con_id,
       f.name AS feature_name,
       MAX(f.detected_usages) AS detected_usages,
       MAX(f.currently_used) AS currently_used,
       ROUND((SYSDATE - MAX(f.last_usage_date)) * 24, 1) AS hours_since_last_usage,
       ROUND((SYSDATE - MIN(f.first_usage_date)) * 24, 1) AS hours_since_first_usage,
       ROUND((SYSDATE - MAX(f.last_sample_date)) * 24, 1) AS hours_since_last_sample
FROM   cdb_feature_usage_statistics f
WHERE  f.detected_usages > 0
GROUP  BY f.con_id, f.name
ORDER  BY f.con_id, f.name;
```

# Notes by version

La vista existe desde 10.1. Oracle muestrea el uso aproximadamente una vez por semana (`hours_since_last_sample`); un uso reciente puede no aparecer todavía. Los nombres de feature cambian entre versiones.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

12.1+: `CDB_FEATURE_USAGE_STATISTICS` desde `CDB$ROOT` cubre cada contenedor (una PDB con Partitioning queda visible). No filtra por `DBID`: las filas heredadas de una base clonada o de una PDB conectada desde otra CDB se agregan con las propias, como las ve también una revisión de licencias. 10g/11g: solo el `DBID` actual.

# Cost classification rationale

`LOW` — unos cientos de filas por contenedor como máximo.

# License notes

Leer el uso no usa ninguna opción. **El uso detectado no prueba que la feature requiera licencia ni que esté licenciada**: algunas se activan por componentes de Oracle o por defecto. Cada feature con uso que corresponda a una opción o pack se reporta como `LICENSE_CHECK_REQUIRED`, nunca como incumplimiento (ver `policies/licensing-awareness-policy.md`).

# Sanitization notes

`feature_name` es el nombre que define Oracle (término de Oracle, no dato de la aplicación). `FEATURE_INFO` (CLOB que puede incluir nombres de objetos o de esquemas), `DESCRIPTION`, `DBID` y fechas absolutas nunca salen. Solo features con `DETECTED_USAGES > 0`.

# Evolution via `/change query`

1.0.0 CHG-ESTACK-C-NEW-QUERIES-001: creación (lote C, cobertura del assessment).

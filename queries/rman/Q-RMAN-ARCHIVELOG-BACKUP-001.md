---
query_id: Q-RMAN-ARCHIVELOG-BACKUP-001
version: 1.0.0

domain: rman
purpose: Cobertura de backup de archivelogs (qué secuencias tienen backup, por thread) — nunca mezcla threads

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$BACKUP_REDOLOG]
privileges_required: [SELECT on V$BACKUP_REDOLOG]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 20
max_rows: 1000
max_output_bytes: 262144

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-RMAN-ARCHIVELOG-BACKUP-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10g-11g)"
  - variant_id: Q-RMAN-ARCHIVELOG-BACKUP-001-V2
    label: modern_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_12plus, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_backup_archivelog_query.sh, tests/test_rman_query_version_compatibility.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh, tests/test_rman_modern_variant_12c.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10g-11g)

```sql
SELECT *
FROM (
  SELECT thread#, sequence#, first_time, next_time, completion_time
  FROM   v$backup_redolog
  ORDER  BY thread#, sequence# DESC
)
WHERE  ROWNUM <= 1000;
```

# Statement / procedure (read-only) — Variant V2 (modern_12plus, 12.1+)

```sql
SELECT thread#, sequence#, first_time, next_time, completion_time
FROM   v$backup_redolog
ORDER  BY thread#, sequence# DESC
FETCH  FIRST 1000 ROWS ONLY;
```

Siempre agrupada por `THREAD#` antes que por `SEQUENCE#` — nunca se compara `SEQUENCE#` entre threads distintos como si fuera una secuencia global única (`# 17` del prompt). Se correlaciona contra `Q-RMAN-ARCHIVED-LOG-COVERAGE-001` (`V$ARCHIVED_LOG`) para distinguir `not backed up` de `not archived`.

# Notes by version

Vista pre-10g, certificada 10g-23ai sin variante adicional. En RAC, cada thread corresponde a una instancia — `rman/rac-awareness` usa esta distinción para nunca mezclar cobertura entre instancias.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`. `database_role_scope: ANY` — backup de archivelog puede ejecutarse en standby con offload (ver `rman/dataguard-awareness`).

# Cost classification rationale

`MEDIUM` — el histórico de archivelogs con backup crece rápidamente en targets de alta generación de redo; acotado a `FETCH FIRST 1000 ROWS ONLY` y `thread_filter`/`time_window` opcionales.

# License notes

Ninguna.

# Sanitization notes

Ninguna — sólo números de secuencia y timestamps.

# Evolution via `/change query`

N/A — vista estable.

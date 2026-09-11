---
query_id: Q-RMAN-BACKUP-DATAFILE-001
version: 1.0.0

domain: rman
purpose: Cobertura de backup por datafile (qué datafiles tienen backup y cuándo) — evidencia de completeness/restore readiness

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$BACKUP_DATAFILE]
privileges_required: [SELECT on V$BACKUP_DATAFILE]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 20
max_rows: 500
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-RMAN-BACKUP-DATAFILE-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10g-11g)"
  - variant_id: Q-RMAN-BACKUP-DATAFILE-001-V2
    label: modern_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_12plus, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_rman_query_version_compatibility.sh, tests/test_restore_readiness_missing_controlfile.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh, tests/test_rman_modern_variant_12c.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10g-11g)

```sql
SELECT *
FROM (
  SELECT file#, checkpoint_time, completion_time, incremental_level,
         blocks, block_size, used_change_tracking
  FROM   v$backup_datafile
  WHERE  file# > 0
  ORDER  BY file#, completion_time DESC
)
WHERE  ROWNUM <= 500;
```

# Statement / procedure (read-only) — Variant V2 (modern_12plus, 12.1+)

```sql
SELECT file#, checkpoint_time, completion_time, incremental_level,
       blocks, block_size, used_change_tracking
FROM   v$backup_datafile
WHERE  file# > 0
ORDER  BY file#, completion_time DESC
FETCH  FIRST 500 ROWS ONLY;
```

`file# > 0` excluye la fila sintética `FILE# = 0` (representa el controlfile dentro de esta vista en algunas versiones) — el controlfile se evalúa por separado vía `Q-RMAN-CONTROLFILE-BACKUP-001`.

# Notes by version

`USED_CHANGE_TRACKING` (block change tracking, disponible desde 10g Enterprise Edition) puede ser `NULL` si la feature no está habilitada — nunca se asume habilitada sin evidencia.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`. `database_role_scope: ANY`.

# Cost classification rationale

`MEDIUM` — una fila por backup de datafile por punto en el tiempo; acotado a `FETCH FIRST 500 ROWS ONLY` y agrupable por `file#` más reciente.

# License notes

Ninguna — block change tracking no requiere licencia adicional (es Enterprise Edition base).

# Sanitization notes

Ninguna columna directamente identificable — `FILE#` es un número interno, no un path.

# Evolution via `/change query`

N/A — vista estable.

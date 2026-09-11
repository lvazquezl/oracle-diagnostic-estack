---
query_id: Q-RMAN-ARCHIVED-LOG-COVERAGE-001
version: 1.0.0

domain: rman
purpose: Generación/aplicación/eliminación de archivelogs por thread+sequence — distingue not backed up / not applied / not archived

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$ARCHIVED_LOG]
privileges_required: [SELECT on V$ARCHIVED_LOG]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 20
max_rows: 1000
max_output_bytes: 262144

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-RMAN-ARCHIVED-LOG-COVERAGE-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10g-11g)"
  - variant_id: Q-RMAN-ARCHIVED-LOG-COVERAGE-001-V2
    label: modern_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_12plus, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_rman_query_version_compatibility.sh, tests/test_dataguard_backup_offload_awareness.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh, tests/test_rman_modern_variant_12c.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10g-11g)

```sql
SELECT *
FROM (
  SELECT thread#, sequence#, applied, deleted, backup_count, archived,
         first_time, next_time, name
  FROM   v$archived_log
  ORDER  BY thread#, sequence# DESC
)
WHERE  ROWNUM <= 1000;
```

# Statement / procedure (read-only) — Variant V2 (modern_12plus, 12.1+)

```sql
SELECT thread#, sequence#, applied, deleted, backup_count, archived,
       first_time, next_time, name
FROM   v$archived_log
ORDER  BY thread#, sequence# DESC
FETCH  FIRST 1000 ROWS ONLY;
```

`BACKUP_COUNT = 0` → `not backed up`. `APPLIED = 'NO'` (o `'YES'`/`'IN-MEMORY'` según versión/rol Data Guard) → `not applied`. `ARCHIVED = 'NO'` → `not archived` (log aún online, no archivado). Las tres condiciones se distinguen siempre por separado — nunca colapsadas en un solo booleano (`# 17` del prompt).

# Notes by version

`APPLIED` reporta `IN-MEMORY` en versiones con Real-Time Apply — reportado tal cual, no forzado a `YES`/`NO`. `NAME` (path del archivelog) se sanitiza siempre.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`. `database_role_scope: ANY` — en standby, `APPLIED` es la señal relevante para apply lag; en primary, para archivelog deletion policy.

# Cost classification rationale

`MEDIUM` — mismo perfil que `Q-RMAN-ARCHIVELOG-BACKUP-001`; acotado a `FETCH FIRST 1000 ROWS ONLY`.

# License notes

Ninguna.

# Sanitization notes

`NAME` (path completo del archivelog) → TOKENIZE siempre — puede revelar convención de filesystem/ASM/`DB_UNIQUE_NAME` embebido en el path.

# Evolution via `/change query`

N/A — vista estable.

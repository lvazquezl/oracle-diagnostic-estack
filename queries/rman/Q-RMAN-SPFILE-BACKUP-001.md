---
query_id: Q-RMAN-SPFILE-BACKUP-001
version: 1.0.0

domain: rman
purpose: Backups de SPFILE (evidencia de protección de SPFILE) — nunca restaura

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$BACKUP_SPFILE]
privileges_required: [SELECT on V$BACKUP_SPFILE]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 200
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-RMAN-SPFILE-BACKUP-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10g-11g)"
  - variant_id: Q-RMAN-SPFILE-BACKUP-001-V2
    label: modern_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_12plus, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_spfile_backup_query.sh, tests/test_rman_query_version_compatibility.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh, tests/test_rman_modern_variant_12c.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10g-11g)

```sql
SELECT *
FROM (
  SELECT recid, set_stamp, modification_time, completion_time
  FROM   v$backup_spfile
  ORDER  BY completion_time DESC
)
WHERE  ROWNUM <= 200;
```

# Statement / procedure (read-only) — Variant V2 (modern_12plus, 12.1+)

```sql
SELECT recid, set_stamp, modification_time, completion_time
FROM   v$backup_spfile
ORDER  BY completion_time DESC
FETCH  FIRST 200 ROWS ONLY;
```

Ausencia de filas implica que el target nunca tuvo un backup de SPFILE vía RMAN — puede seguir protegido si `CONTROLFILE AUTOBACKUP` está `ON` (el autobackup de controlfile incluye el SPFILE cuando existe uno) — correlacionar siempre con `Q-RMAN-CONFIGURATION-001` antes de reportar SPFILE como desprotegido.

# Notes by version

Vista pre-10g, certificada 10g-23ai sin variante adicional.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`. `database_role_scope: ANY`.

# Cost classification rationale

`LOW` — típicamente decenas de filas.

# License notes

Ninguna.

# Sanitization notes

Ninguna — sólo IDs y timestamps.

# Evolution via `/change query`

N/A — vista estable.

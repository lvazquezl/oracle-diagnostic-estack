---
query_id: Q-RMAN-CONTROLFILE-BACKUP-001
version: 1.0.0

domain: rman
purpose: Backups que incluyen controlfile (evidencia de protección de controlfile) — nunca restaura

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$BACKUP_SET]
privileges_required: [SELECT on V$BACKUP_SET]

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
  - variant_id: Q-RMAN-CONTROLFILE-BACKUP-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10g-11g)"
  - variant_id: Q-RMAN-CONTROLFILE-BACKUP-001-V2
    label: modern_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_12plus, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_controlfile_backup_query.sh, tests/test_rman_query_version_compatibility.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh, tests/test_rman_modern_variant_12c.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10g-11g)

```sql
SELECT *
FROM (
  SELECT recid, set_stamp, completion_time
  FROM   v$backup_set
  WHERE  controlfile_included != 'NO'
  ORDER  BY completion_time DESC
)
WHERE  ROWNUM <= 200;
```

# Statement / procedure (read-only) — Variant V2 (modern_12plus, 12.1+)

```sql
SELECT recid, set_stamp, completion_time
FROM   v$backup_set
WHERE  controlfile_included != 'NO'
ORDER  BY completion_time DESC
FETCH  FIRST 200 ROWS ONLY;
```

Filtra el mismo `V$BACKUP_SET` ya certificado en `Q-RMAN-BACKUP-SET-001` a los sets que incluyen controlfile — reutiliza la vista, no duplica certificación de columnas fuera de este subconjunto.

# Notes by version

`CONTROLFILE_INCLUDED` reporta `NO`, `YES`, o `STANDBY` según versión/rol — cualquier valor distinto de `NO` cuenta como controlfile protegido en este backup set. Controlfile autobackup (config, no backup set) se evalúa por separado vía `Q-RMAN-CONFIGURATION-001` (`CONTROLFILE AUTOBACKUP`).

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`. `database_role_scope: ANY`.

# Cost classification rationale

`LOW` — subconjunto pequeño de `V$BACKUP_SET` (sólo los sets con controlfile incluido).

# License notes

Ninguna.

# Sanitization notes

Ninguna — sólo IDs y timestamps.

# Evolution via `/change query`

N/A — vista estable.

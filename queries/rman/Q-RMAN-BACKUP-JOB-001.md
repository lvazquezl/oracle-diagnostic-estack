---
query_id: Q-RMAN-BACKUP-JOB-001
version: 1.0.0

domain: rman
purpose: Resumen de jobs de backup RMAN (tipo, estado, duración, throughput, ratio de compresión) — vista derivada, más conveniente que V$RMAN_STATUS crudo para duración/throughput

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$RMAN_BACKUP_JOB_DETAILS]
privileges_required: [SELECT on V$RMAN_BACKUP_JOB_DETAILS]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 30
max_rows: 500
max_output_bytes: 131072

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

# Query ya estaba REGISTERED en queries/REGISTRY.md desde Foundation (Q-RMAN-BACKUP-JOB-001,
# V$RMAN_BACKUP_JOB_DETAILS) sin archivo real materializado — gap del mismo tipo que
# Q-CDB-PDB-STATE-001/Q-CDB-CONTAINERS-001 corregido en Fase 6. Verificado vía WebFetch
# (docs.oracle.com/en/database/oracle/oracle-database/19/refrn/V-RMAN_BACKUP_JOB_DETAILS.html):
# vista real, derivada de V$RMAN_STATUS/V$RMAN_OUTPUT, con columnas pre-calculadas
# (INPUT_BYTES_PER_SEC/OUTPUT_BYTES_PER_SEC/COMPRESSION_RATIO/ELAPSED_SECONDS/*_DISPLAY) — fuente
# preferida de rman/backup-duration y rman/backup-throughput frente a derivar manualmente de
# V$RMAN_STATUS. CON_ID presente (multitenant, 12.1+), igual patrón que el resto del catálogo.
variants:
  - variant_id: Q-RMAN-BACKUP-JOB-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10g-11g)"
  - variant_id: Q-RMAN-BACKUP-JOB-001-V2
    label: modern_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_12plus, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_rman_query_version_compatibility.sh, tests/test_rman_query_cost.sh, tests/test_rman_legacy_variant_10g.sh, tests/test_rman_legacy_variant_11g.sh, tests/test_rman_modern_variant_12c.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10g-11g)

```sql
SELECT *
FROM (
  SELECT session_key, input_type, status, start_time, end_time, elapsed_seconds,
         input_bytes, output_bytes, input_bytes_per_sec, output_bytes_per_sec,
         compression_ratio
  FROM   v$rman_backup_job_details
  ORDER  BY start_time DESC
)
WHERE  ROWNUM <= 500;
```

# Statement / procedure (read-only) — Variant V2 (modern_12plus, 12.1+)

```sql
SELECT session_key, input_type, status, start_time, end_time, elapsed_seconds,
       input_bytes, output_bytes, input_bytes_per_sec, output_bytes_per_sec,
       compression_ratio
FROM   v$rman_backup_job_details
ORDER  BY start_time DESC
FETCH  FIRST 500 ROWS ONLY;
```

`INPUT_TYPE` reporta el tipo de job a nivel texto (`DB FULL`, `DB INCR`, `ARCHIVELOG`, `CONTROL FILE`, etc.) — usado por `rman/backup-status` para clasificación, siempre cruzado con `BACKUP_TYPE`/`INCREMENTAL_LEVEL` de `Q-RMAN-BACKUP-SET-001` para el inventario final (`# 9` del prompt — nunca se clasifica sólo por texto libre).

# Notes by version

Derivada de `V$RMAN_STATUS`/`V$RMAN_OUTPUT`, por lo que hereda su certificación 10g-23ai (verificado vía WebFetch, columnas confirmadas reales contra Oracle Database Reference 19c). `CON_ID` sólo 12.1+ — no seleccionada por esta variante única para mantener validez en 10g/11g.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`. `database_role_scope: ANY`.

# Cost classification rationale

`MEDIUM` — mismo perfil que `Q-RMAN-STATUS-001` (histórico de jobs); acotado a `FETCH FIRST 500 ROWS ONLY`.

# License notes

Ninguna.

# Sanitization notes

Ninguna columna directamente identificable.

# Evolution via `/change query`

N/A — vista estable, derivada de vistas ya estables.

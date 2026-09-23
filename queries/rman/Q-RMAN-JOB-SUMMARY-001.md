---
query_id: Q-RMAN-JOB-SUMMARY-001
version: 1.0.0

domain: rman
purpose: Resumen de jobs RMAN por tipo de entrada (estado del último job, horas desde el último inicio y el último éxito, fallos en 7 días, duración del último) — antigüedad calculada en la base, nunca fechas absolutas

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
max_rows: 20
max_output_bytes: 8192

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

# CHG-ESTACK-ORA19C-LAB-004 (lote 2 RMAN, opción C): complementa Q-RMAN-BACKUP-JOB-001 (inventario
# fila a fila con START_TIME/END_TIME absolutos) con un agregado por INPUT_TYPE cuya antigüedad se
# calcula contra SYSDATE en la base. Sin Top-N ni CON_ID: una sola variante 10g-23ai.
variants:
  - variant_id: Q-RMAN-JOB-SUMMARY-001-V1
    label: all_versions
    oracle_versions: {min: "10.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (all_versions, 10g-23ai)"

tests: [tests/test_no_write_operations.sh, tests/test_rman_query_version_compatibility.sh, tests/test_rman_query_cost.sh, tests/test_sql_static_validator.sh, tests/test_p15_oracle_lab_adapter.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (all_versions, 10g-23ai)

```sql
SELECT input_type,
       COUNT(*) AS jobs_total,
       MAX(status) KEEP (DENSE_RANK LAST ORDER BY start_time) AS last_status,
       ROUND((SYSDATE - MAX(start_time)) * 24, 2) AS hours_since_last_start,
       ROUND((SYSDATE - MAX(CASE WHEN status IN ('COMPLETED', 'COMPLETED WITH WARNINGS') THEN end_time END)) * 24, 2) AS hours_since_last_success,
       SUM(CASE WHEN status IN ('FAILED', 'COMPLETED WITH ERRORS', 'RUNNING WITH ERRORS') AND start_time > SYSDATE - 7 THEN 1 ELSE 0 END) AS failed_last_7d,
       MAX(elapsed_seconds) KEEP (DENSE_RANK LAST ORDER BY start_time) AS last_elapsed_seconds
FROM   v$rman_backup_job_details
GROUP  BY input_type
ORDER  BY input_type;
```

Una fila por `INPUT_TYPE` presente (`DB FULL`, `DB INCR`, `DATAFILE FULL`, `DATAFILE INCR`, `ARCHIVELOG`, `CONTROLFILE`, `SPFILE`, `RECVR AREA`, `BACKUPSET`). Sin jobs registrados, la query devuelve 0 filas: el consumidor lo trata como `INSUFFICIENT_EVIDENCE`, nunca como "sin fallos".

- `last_status` / `last_elapsed_seconds`: del job con `START_TIME` más reciente de ese tipo (`KEEP (DENSE_RANK LAST …)`, Oracle 9i+).
- `hours_since_last_success`: último `COMPLETED` o `COMPLETED WITH WARNINGS`; `NULL` si nunca terminó bien.
- `failed_last_7d`: `FAILED`, `COMPLETED WITH ERRORS` y `RUNNING WITH ERRORS` iniciados en los últimos 7 días (`SYSDATE - 7`, mismo reloj).

# Notes by version

`V$RMAN_BACKUP_JOB_DETAILS` existe desde 10g (`compatibility/oracle-dictionary/views.yaml`, derivada de `V$RMAN_STATUS`). `KEEP (DENSE_RANK LAST …)`, `CASE`, `ROUND` y `SYSDATE` están disponibles en todo el rango. No usa `FETCH FIRST`/`OFFSET` ni `CON_ID`.

# Notes by platform

Ninguna. La antigüedad sale del mismo reloj del servidor, con la misma imprecisión de ±1 h por cambio de horario que `Q-RMAN-BACKUP-FRESHNESS-001`.

# Container / role scope notes

`ANY_CONTAINER`, como `Q-RMAN-BACKUP-JOB-001`. Desde `CDB$ROOT` o una non-CDB se ven los jobs de toda la base; desde una PDB la vista se filtra a ese contenedor. El gateway lab lo ejecuta desde `CDB$ROOT`.

# Cost classification rationale

`MEDIUM`, igual que `Q-RMAN-BACKUP-JOB-001`: `V$RMAN_BACKUP_JOB_DETAILS` es una vista derivada que agrega `V$RMAN_STATUS`; su costo crece con la historia de jobs retenida en el controlfile. La salida agregada es pequeña (≤ 1 fila por tipo).

# License notes

Ninguna: vista `V$` estándar de RMAN, sin Diagnostics/Tuning Pack ni Recovery Catalog.

# Sanitization notes

Todos los campos → KEEP: `input_type` y `last_status` son enums de Oracle; el resto son números. No se leen `SESSION_KEY`, `OUTPUT` ni mensajes de RMAN.

# Limitations

La historia está limitada por `CONTROL_FILE_RECORD_KEEP_TIME` (y por lo que `V$RMAN_STATUS` conserve); jobs de backup lanzados fuera de RMAN (copias de OS, snapshots de storage) no aparecen.

# Evolution via `/change query`

Ver `Q-RMAN-BACKUP-FRESHNESS-001`.

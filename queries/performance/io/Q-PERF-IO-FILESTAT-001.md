---
query_id: Q-PERF-IO-FILESTAT-001
version: 1.0.0

domain: performance
purpose: Latencia de lectura/escritura por datafile, snapshot actual acumulado desde el arranque de la instancia

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$FILESTAT, V$DATAFILE]
privileges_required: [SELECT on V$FILESTAT, SELECT on V$DATAFILE]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 20
max_rows: 500
max_output_bytes: 65536

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_medium.sh, tests/test_no_storage_root_cause_without_external_evidence.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT d.name                                              AS file_name,
       f.phyrds,
       f.phywrts,
       ROUND(f.readtim  / NULLIF(f.phyrds, 0), 2)           AS avg_read_latency_ms,
       ROUND(f.writetim / NULLIF(f.phywrts, 0), 2)          AS avg_write_latency_ms
FROM   v$filestat f
JOIN   v$datafile d ON d.file# = f.file#
ORDER  BY avg_read_latency_ms DESC NULLS LAST
FETCH FIRST 50 ROWS ONLY;                 -- 12c+; usar ROWNUM <= 50 en 10g/11g
```

Complementa `Q-PERF-IO-001` con el desglose por archivo que AWR/`DBA_HIST_SYSTEM_EVENT` no provee a este nivel de detalle. `max_rows: 500` acota el costo en bases de datos con muchos datafiles (`cost_class: MEDIUM`, escala con `DBA_DATA_FILES`).

# Notes by version

`V$FILESTAT`/`V$DATAFILE` estables 10g–23ai en las columnas usadas. `READTIM`/`WRITETIM` están en centésimas de segundo — la conversión a ms ya está aplicada en el `SELECT`.

# Notes by platform

Ninguna diferencia lógica — la exactitud de `READTIM`/`WRITETIM` depende de la resolución del reloj del SO/driver de I/O subyacente; una latencia alta reportada por Oracle es `OBSERVATION`, nunca confirmación directa de un problema de storage sin evidencia externa (ver `test_no_storage_root_cause_without_external_evidence.sh`).

# Container / role scope notes

`ANY_CONTAINER` — vistas de instancia. `database_role_scope: PRIMARY` — mismo razonamiento que `Q-PERF-IO-001`.

# License notes

Ninguna.

# Sanitization notes

`file_name` → MASK por defecto (puede revelar ruta/hostname de storage); métricas numéricas → KEEP.

# Evolution via `/change query`

Ninguno previsto.

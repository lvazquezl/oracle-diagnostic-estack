---
query_id: Q-RMAN-CONTROLFILE-RECORD-SECTION-001
version: 1.0.0

domain: rman
purpose: Utilización de secciones de registro del controlfile (RMAN-relevantes) — awareness de capacidad, nunca resize

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [V$CONTROLFILE_RECORD_SECTION]
privileges_required: [SELECT on V$CONTROLFILE_RECORD_SECTION]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 50
max_output_bytes: 32768

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-RMAN-CONTROLFILE-RECORD-SECTION-001-V1
    label: all_versions
    oracle_versions: {min: "10.2", max: "23.0"}
    container_scope: NOT_APPLICABLE
    sql_block: "Variant V1 (all_versions, 10g-23ai)"

tests: [tests/test_no_write_operations.sh, tests/test_rman_query_version_compatibility.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (all_versions, 10g-23ai)

```sql
SELECT type, record_size, records_total, records_used
FROM   v$controlfile_record_section
WHERE  type IN ('BACKUP CORRUPTION', 'BACKUP DATAFILE', 'BACKUP REDOLOG',
                 'BACKUP SET', 'BACKUP PIECE', 'BACKUP SPFILE', 'RMAN CONFIGURATION',
                 'RMAN STATUS')
ORDER  BY type;
```

Acotado a las secciones RMAN-relevantes (evita traer secciones no relacionadas del controlfile). `RECORDS_USED` cerca de `RECORDS_TOTAL` es señal de que RMAN podría empezar a sobrescribir registros antiguos antes de que expiren según retención — correlacionar con `CONTROLFILE_RECORD_KEEP_TIME` (parámetro, no esta vista) cuando se reporte.

# Notes by version

Vista pre-10g, certificada 10g-23ai sin variante adicional. Las secciones se auto-extienden dinámicamente en versiones modernas — un valor alto de `RECORDS_USED`/`RECORDS_TOTAL` no siempre implica riesgo real; se reporta como `OBSERVATION`, nunca como hallazgo automático sin contexto adicional.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`NOT_APPLICABLE`.

# Cost classification rationale

`LOW` — a lo sumo 8 filas (secciones filtradas).

# License notes

Ninguna.

# Sanitization notes

Ninguna — sólo conteos.

# Evolution via `/change query`

N/A — vista estable.

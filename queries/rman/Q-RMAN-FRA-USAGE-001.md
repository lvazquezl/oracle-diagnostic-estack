---
query_id: Q-RMAN-FRA-USAGE-001
version: 1.0.0

domain: rman
purpose: Uso/límite/espacio reclamable de la Fast Recovery Area y destino configurado — presión de FRA correlacionada, nunca borra archivos

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [V$FLASH_RECOVERY_AREA_USAGE, V$RECOVERY_FILE_DEST]
privileges_required: [SELECT on V$FLASH_RECOVERY_AREA_USAGE, SELECT on V$RECOVERY_FILE_DEST]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 50
max_output_bytes: 32768

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

# FRA (Flash/Fast Recovery Area) es una feature introducida en Oracle Database 10g — ambas vistas
# certificadas 10g-23ai. Nota de nomenclatura: renombrada de "Flash Recovery Area" a "Fast Recovery
# Area" en 11g, la vista V$FLASH_RECOVERY_AREA_USAGE conserva su nombre original por compatibilidad
# en todas las versiones — no hay una V$FAST_RECOVERY_AREA_USAGE separada.
variants:
  - variant_id: Q-RMAN-FRA-USAGE-001-V1
    label: all_versions
    oracle_versions: {min: "10.2", max: "23.0"}
    container_scope: NOT_APPLICABLE
    sql_block: "Variant V1 (all_versions, 10g-23ai)"

tests: [tests/test_no_write_operations.sh, tests/test_fra_query.sh, tests/test_rman_query_version_compatibility.sh, tests/test_fra_healthy.sh, tests/test_fra_warning.sh, tests/test_fra_critical.sh, tests/test_fra_no_auto_delete.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (all_versions, 10g-23ai)

```sql
SELECT u.file_type, u.percent_space_used, u.percent_space_reclaimable, u.number_of_files,
       d.name AS dest_name, d.space_limit, d.space_used, d.space_reclaimable, d.number_of_files AS dest_files
FROM   v$flash_recovery_area_usage u,
       v$recovery_file_dest d;
```

Sólo lectura de uso/límite — nunca ejecuta ninguna operación de limpieza (`DELETE OBSOLETE`, purga de flashback logs, etc.). La correlación de presión (archivelog generation, cadencia de backup, retención, deletion policy, flashback logs, restore points, Data Guard) la realiza `rman/fra-pressure`, no esta query.

# Notes by version

Ambas vistas certificadas desde 10g (feature FRA introducida en 10g). `V$RECOVERY_FILE_DEST` es una fila por `DB_RECOVERY_FILE_DEST` configurado — normalmente una sola fila salvo migración de FRA en curso.

# Notes by platform

FRA puede residir en filesystem o ASM (`+RECO`/`+FRA` u otro diskgroup) — `dest_name` se sanitiza igual en ambos casos.

# Container / role scope notes

`NOT_APPLICABLE` — FRA es a nivel de instancia/base completa, no por contenedor.

# Cost classification rationale

`LOW` — `V$FLASH_RECOVERY_AREA_USAGE` tiene una fila por tipo de archivo (típicamente menos de 10); `V$RECOVERY_FILE_DEST` normalmente 1 fila.

# License notes

Ninguna.

# Sanitization notes

`dest_name` (path de FRA) → MASK por defecto.

# Evolution via `/change query`

N/A — vistas estables desde 10g.

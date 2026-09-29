---
query_id: Q-DISC-ARCHITECTURE-001
version: 1.0.0

domain: oracle
purpose: Hechos agregados de arquitectura (RAC, ASM, rol/Data Guard, plataforma) para comparar lo observado contra lo declarado en el target — sin nombres de instancias, archivos, disk groups ni destinos

supported_oracle_versions: [11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [GV$INSTANCE, V$PARAMETER, V$DATAFILE, V$ASM_DISKGROUP_STAT, V$DATABASE, V$ARCHIVE_DEST]
privileges_required: [SELECT on GV$INSTANCE, SELECT on V$PARAMETER, SELECT on V$DATAFILE, SELECT on V$ASM_DISKGROUP_STAT, SELECT on V$DATABASE, SELECT on V$ARCHIVE_DEST]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 1
max_output_bytes: 2048

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

# CHG-ESTACK-DISC-ARCHITECTURE-001 (CHG-REQ-LAB-DISC-STORAGE). Una fila, sólo conteos, un flag de parámetro, el rol y
# el nombre de plataforma de Oracle: nada identifica instancias, rutas ni destinos. Piso 11.2 como Q-DISC-RAC-001.
variants:
  - variant_id: Q-DISC-ARCHITECTURE-001-V1
    label: all_11gr2_plus
    oracle_versions: {min: "11.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (all_11gr2_plus)"

tests: [tests/test_no_write_operations.sh, tests/test_sql_static_validator.sh, tests/test_field_validation.sh, tests/test_p15_oracle_lab_adapter.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (all_11gr2_plus)

```sql
SELECT (SELECT COUNT(*) FROM gv$instance) AS instance_count,
       (SELECT UPPER(value) FROM v$parameter WHERE name = 'cluster_database') AS cluster_database,
       (SELECT COUNT(*) FROM v$datafile) AS datafiles_total,
       (SELECT COUNT(*) FROM v$datafile WHERE name LIKE '+%') AS datafiles_in_asm,
       (SELECT COUNT(*) FROM v$asm_diskgroup_stat) AS asm_diskgroups,
       (SELECT database_role FROM v$database) AS database_role,
       (SELECT COUNT(*) FROM v$archive_dest WHERE target = 'STANDBY' AND status = 'VALID') AS standby_destinations,
       (SELECT platform_name FROM v$database) AS platform_name
FROM   dual;
```

Siempre una fila. Deducción que hace el gateway (`mcp_gateway/architecture.py`):
- `rac` = `instance_count > 1` o `cluster_database = 'TRUE'`
- `asm` = `datafiles_in_asm > 0`
- `dataguard` = rol distinto de `PRIMARY` o `standby_destinations > 0`
- `role` = `PRIMARY` o `STANDBY`
- familia de SO a partir de `platform_name`

`V$DATAFILE.NAME` sólo se usa dentro de la base para contar los que empiezan con `+`: ninguna ruta sale.

# Notes by version

Todas las vistas y columnas existen desde 10g/11g; piso 11.2 por coherencia con `Q-DISC-RAC-001`. Verificado en el catálogo real sólo en 19c (`Q-DICT-VERIFY`).

# Notes by platform

`platform_name` usa los nombres de plataforma de Oracle (`V$TRANSPORTABLE_PLATFORM`), p. ej. `Linux x86 64-bit`; la distribución (OL/RHEL/SLES) no es observable desde SQL.

# Container / role scope notes

`ANY_CONTAINER`. Desde `CDB$ROOT`, `V$DATAFILE` cuenta los datafiles de todos los contenedores. En un standby montado, `V$DATABASE`/`V$DATAFILE`/`V$ARCHIVE_DEST` responden.

# Cost classification rationale

`LOW`: subconsultas escalares sobre vistas de instancia y del controlfile; `V$ASM_DISKGROUP_STAT` no dispara discovery de discos.

# License notes

Ninguna.

# Sanitization notes

Conteos → KEEP. `cluster_database`, `database_role` y `platform_name` → enums con los valores de Oracle, KEEP; cualquier otro valor se descarta.

# Limitations

Un Data Guard sin destino `STANDBY` válido visto desde el primary (p. ej. destino caído) se reporta como `dataguard: false`; el standby lo reporta por rol. No detecta RAC One Node como tal.

# Evolution via `/change query`

Grid Infrastructure/Exadata como dimensiones adicionales, si el modelo de contexto las incorpora.

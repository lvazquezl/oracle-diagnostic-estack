---
query_id: Q-RMAN-CONFIGURATION-001
version: 1.0.0

domain: rman
purpose: Visibilidad de configuración RMAN persistente (retention policy, backup optimization, device type, channels, snapshot controlfile, archivelog deletion policy) — nunca ejecuta CONFIGURE

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$RMAN_CONFIGURATION]
privileges_required: [SELECT on V$RMAN_CONFIGURATION]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 100
max_output_bytes: 32768

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

# Verificado vía WebFetch (docs.oracle.com/en/database/oracle/oracle-database/19/refrn/V-RMAN_CONFIGURATION.html):
# CONF#, NAME, VALUE, CON_ID. V$RMAN_CONFIGURATION disponible desde Oracle9i (confirmado vía
# oracle-base.com/stanford.edu mirror del 10gR2 Database Reference) — certificada 10g-23ai sin
# necesidad de variante por versión. CON_ID (0=whole CDB/non-CDB, 1=root, n=PDB) presente en todas
# las versiones donde existe la columna en el catálogo (12.1+); en 10g/11g la columna no existe —
# no se selecciona (SELECT * evita el riesgo, no se listan columnas fijas por nombre).
variants:
  - variant_id: Q-RMAN-CONFIGURATION-001-V1
    label: all_versions
    oracle_versions: {min: "10.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (all_versions, 10g-23ai)"

tests: [tests/test_no_write_operations.sh, tests/test_no_configure_execution.sh, tests/test_rman_configuration_query.sh, tests/test_rman_query_version_compatibility.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (all_versions, 10g-23ai)

```sql
SELECT conf#, name, value
FROM   v$rman_configuration
ORDER  BY conf#;
```

Sólo visibilidad de configuración persistente ya establecida — nunca ejecuta `CONFIGURE`. Ausencia de filas para un `NAME` dado implica el valor por defecto de RMAN para esa opción (comportamiento documentado de Oracle, no un gap de la query).

# Notes by version

`V$RMAN_CONFIGURATION` (`CONF#`, `NAME`, `VALUE`, `CON_ID`) disponible desde 9i, certificada 10g-23ai sin variante. `CON_ID` existe sólo 12.1+ — esta variante no la selecciona por nombre para permanecer válida en todas las versiones; `rman/multitenant-awareness` usa una consulta separada cuando necesita discriminar por contenedor.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`. `database_role_scope: ANY` — la configuración RMAN es visible en primary y standby.

# Cost classification rationale

`LOW` — decenas de filas típicamente (una por opción de CONFIGURE no default).

# License notes

Ninguna.

# Sanitization notes

`value` → MASK cuando corresponde a `CONTROLFILE AUTOBACKUP FORMAT`/`SNAPSHOT CONTROLFILE NAME`/`CHANNEL ... PARMS` (puede contener paths o credenciales de conexión del media manager — nunca se expone crudo).

# Evolution via `/change query`

N/A — vista estable desde 9i.

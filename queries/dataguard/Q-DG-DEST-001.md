---
query_id: Q-DG-DEST-001
version: 1.0.0

domain: dataguard
purpose: Estado y configuración de LOG_ARCHIVE_DEST_n — destino, modo de transporte, validez, error

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$ARCHIVE_DEST, V$ARCHIVE_DEST_STATUS]
privileges_required: [SELECT on V$ARCHIVE_DEST, SELECT on V$ARCHIVE_DEST_STATUS]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 32
max_output_bytes: 16384

sensitivity: HIGH
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_dataguard_dest_query.sh, tests/test_transport_healthy.sh, tests/test_transport_error.sh, tests/test_transport_deferred.sh, tests/test_destination_configuration.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT d.dest_id, d.dest_name, d.target, d.status AS config_status,
       d.archiver, d.transmit_mode, d.affirm, d.valid_now AS valid_for,
       s.status AS runtime_status, s.error, s.recovery_mode
FROM   v$archive_dest d
JOIN   v$archive_dest_status s ON s.dest_id = d.dest_id
WHERE  d.target IN ('STANDBY', 'PRIMARY')
   AND d.status != 'INACTIVE'
ORDER  BY d.dest_id;
```

`transmit_mode`/`affirm` derivan de `ASYNC`/`SYNC`/`NOAFFIRM`/`AFFIRM` declarados en `LOG_ARCHIVE_DEST_n` — no se selecciona el connect descriptor completo (`SERVICE`), sólo lo necesario para clasificar estado.

# Notes by version

`V$ARCHIVE_DEST`/`V$ARCHIVE_DEST_STATUS` estables desde 10g en las columnas usadas.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`. `database_role_scope: PRIMARY` — destinos de archive activos con `TARGET = STANDBY` son relevantes principalmente desde el primary (un standby también puede tener destinos configurados hacia un tercer sitio en cascada, fuera de alcance de esta fase).

# Cost classification rationale

`LOW` — acotado a `max 32` destinos posibles (límite de Oracle), filtrado a activos.

# License notes

Ninguna.

# Sanitization notes

`dest_name`/`error` → MASK por defecto (pueden contener hostnames/nombres de servicio en el texto de error).

# Evolution via `/change query`

Ampliar a `NET_TIMEOUT`/`REOPEN`/`MAX_FAILURE` explícitos (hoy cubiertos por `dataguard/archive-destinations` vía una lectura complementaria) vía `/change query` si un skill los requiere en la misma query.

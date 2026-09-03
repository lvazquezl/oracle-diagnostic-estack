---
query_id: Q-DISC-INSTANCE-001
version: 1.0.0

domain: oracle
purpose: Estado de instancia y modo (single/RAC)

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$INSTANCE, GV$INSTANCE]
privileges_required: [SELECT on V$INSTANCE, SELECT on GV$INSTANCE]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 50
max_output_bytes: 16384

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT inst_id, instance_name, instance_number, host_name, status,
       database_status, active_state, shutdown_pending, startup_time
FROM   gv$instance
ORDER  BY inst_id;
```

Sobre un target standalone, `gv$instance` devuelve una sola fila — la misma query sirve para ambos casos, evitando duplicar una versión "single" y otra "RAC".

# Notes by version

`ACTIVE_STATE` estable desde 10g. Sin diferencias estructurales relevantes hasta 23ai.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

Instancia es independiente de tenancy — `ANY_CONTAINER`.

# Cost classification rationale

`LOW`: número de filas acotado al número de instancias del cluster (típicamente < 32), sin joins costosos.

# License notes

Ninguna.

# Sanitization notes

`host_name` → MASK por defecto; `instance_name` → MASK; el resto → KEEP.

# Evolution via `/change query`

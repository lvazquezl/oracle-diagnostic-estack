---
query_id: Q-ORA-REDO-SWITCH-FREQ-001
version: 1.1.0
domain: oracle
purpose: Frecuencia de log switches en una ventana reciente

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$LOG_HISTORY]
privileges_required: [SELECT on V$LOG_HISTORY]

risk_class: R0
cost_class: MEDIUM
timeout_seconds: 30
max_rows: 2000
max_output_bytes: 262144

sensitivity: LOW
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_cost_medium.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT thread#, TRUNC(first_time,'HH24') AS hour_bucket, COUNT(*) AS switch_count
FROM   v$log_history
WHERE  first_time >= :window_start AND first_time <= :window_end
GROUP  BY thread#, TRUNC(first_time,'HH24')
ORDER  BY thread#, hour_bucket;
```

Requiere `constraints.time_window` explícito en el Task Package — ventana obligatoria (`cost_class: MEDIUM`, ver `policies/query-cost-policy.md`).

# Notes by version

Sin diferencias estructurales relevantes.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER` (corregido en Compatibility Hardening — era `CDB_ROOT`, valor inválido para 10g/11g donde Multitenant no existe). `V$LOG_HISTORY` es CDB-wide, no `CON_ID`-scoped.

# Cost classification rationale

`MEDIUM`: histórico con ventana de tiempo — acotado por `max_rows` y ventana obligatoria.

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP.

# Evolution via `/change query`

---
query_id: Q-PERF-REDO-001
version: 1.0.0

domain: performance
purpose: Volumen de redo generado y tasa de commits/rollbacks, acumulado desde el arranque de la instancia

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$SYSSTAT]
privileges_required: [SELECT on V$SYSSTAT]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 10
max_output_bytes: 4096

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_low.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT MAX(DECODE(name, 'redo size', value))            AS redo_size_bytes,
       MAX(DECODE(name, 'redo entries', value))          AS redo_entries,
       MAX(DECODE(name, 'user commits', value))          AS user_commits,
       MAX(DECODE(name, 'user rollbacks', value))        AS user_rollbacks
FROM   v$sysstat
WHERE  name IN ('redo size', 'redo entries', 'user commits', 'user rollbacks');
```

Se correlaciona con `Q-PERF-IO-001` (`log file sync`/`log file parallel write`) por `performance/commit-redo` para distinguir comportamiento de aplicación (commit frecuente, valor alto de `user_commits` con `redo_size` proporcional) de latencia de storage de redo (`log file parallel write` alto sin `user_commits` proporcionalmente alto).

# Notes by version

`V$SYSSTAT` y estos nombres de estadística son estables 10g–23ai.

# Notes by platform

Ninguna — query SQL pura.

# Container / role scope notes

`ANY_CONTAINER`. `database_role_scope: PRIMARY` — redo generado por transacciones de aplicación es mínimo en standby (que aplica redo recibido, un patrón distinto, fuera de alcance de esta query).

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP.

# Evolution via `/change query`

Ninguno previsto.

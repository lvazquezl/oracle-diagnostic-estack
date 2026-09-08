---
query_id: Q-DG-ARCHIVED-LOG-001
version: 1.0.0

domain: dataguard
purpose: Secuencias recibidas/aplicadas por thread, ventana acotada — nunca un scan histórico ilimitado (# 55 del prompt de Fase 5)

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: STANDBY

objects_accessed: [V$ARCHIVED_LOG]
privileges_required: [SELECT on V$ARCHIVED_LOG]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 30
max_rows: 500
max_output_bytes: 262144

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_dataguard_archived_log_query.sh, tests/test_query_cost_medium.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT thread#, MAX(sequence#) AS last_received_sequence,
       MAX(CASE WHEN applied = 'YES' THEN sequence# END) AS last_applied_sequence
FROM   v$archived_log
WHERE  first_time >= SYSDATE - :time_window_hours / 24
GROUP  BY thread#
ORDER  BY thread#;
```

Siempre parametrizada por `:time_window_hours` (`# 55` — nunca un scan histórico ilimitado) — el skill que consume esta query fija un valor por defecto acotado (ej. 24h) salvo que el DBA pida explícitamente una ventana mayor, dentro de `max_rows`.

# Notes by version

`V$ARCHIVED_LOG` estable desde 10g en las columnas usadas.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`. `database_role_scope: STANDBY` — el detalle de recibido/aplicado por thread tiene sentido medido desde el standby.

# Cost classification rationale

`MEDIUM` — `V$ARCHIVED_LOG` puede crecer mucho en ambientes con alta generación de redo; la ventana de tiempo y el `GROUP BY thread#` acotan el resultado, pero el escaneo subyacente sigue siendo más costoso que una vista pre-agregada.

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP (secuencias/threads no son sensibles).

# Evolution via `/change query`

Filtro adicional por `dest_id`/destino específico vía `/change query` si un skill lo requiere.

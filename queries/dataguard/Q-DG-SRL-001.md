---
query_id: Q-DG-SRL-001
version: 1.0.0

domain: dataguard
purpose: Standby redo logs por thread — grupos, tamaño, estado, comparado con online redo del thread correspondiente

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$STANDBY_LOG, V$LOG]
privileges_required: [SELECT on V$STANDBY_LOG, SELECT on V$LOG]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 100
max_output_bytes: 32768

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_dataguard_srl_query.sh, tests/test_srl_inventory.sh, tests/test_srl_thread_awareness.sh, tests/test_srl_size_awareness.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT thread#, COUNT(*) AS group_count, MAX(bytes)/1048576 AS size_mb, status
FROM   v$standby_log
GROUP  BY thread#, status
ORDER  BY thread#;
```

Consultada junto con `V$LOG` (ya certificada en Oracle Core, `Q-ORA-REDO-001`) para comparar `group_count`/`size_mb` de SRL contra el online redo del thread correspondiente — esta query sólo aporta el lado standby redo log, el skill hace la comparación.

# Notes by version

`V$STANDBY_LOG` estable desde 10g.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`. `database_role_scope: ANY` — SRL existe tanto en el standby (activo) como puede preexistir configurado en el primary (para soportar switchback), la query lee lo que exista en el sitio consultado.

# Cost classification rationale

`LOW` — acotado al número de grupos SRL configurados (típicamente <20 por thread).

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP.

# Evolution via `/change query`

N/A — vista estable.

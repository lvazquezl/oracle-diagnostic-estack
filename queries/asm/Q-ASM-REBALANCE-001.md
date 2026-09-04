---
query_id: Q-ASM-REBALANCE-001
version: 1.0.0

domain: asm
purpose: Visibilidad de operaciones ASM en curso (rebalance y otras) — nunca control

supported_oracle_versions: [11gR2, 12c, 18c, 19c, 21c, 23ai]
supported_os: [Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server]
supported_architectures: [Standalone, RAC, RAC One Node]

container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [GV$ASM_OPERATION]
privileges_required: [SELECT on GV$ASM_OPERATION]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 50
max_output_bytes: 16384

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_asm_rebalance.sh, tests/test_asm_no_rebalance_execution.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT inst_id, group_number, operation, state, power,
       actual, sofar, est_work, est_rate, est_minutes
FROM   gv$asm_operation
ORDER  BY inst_id, group_number;
```

Devuelve 0 filas cuando no hay operación activa — ese es el estado normal, no un error.

# Notes by version

`GV$ASM_OPERATION` estable desde 11gR2.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`NOT_APPLICABLE`.

# Cost classification rationale

`LOW` — la vista está vacía en el caso común (sin rebalance activo) y acotada al número de operaciones activas.

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP — progreso agregado, no datos de aplicación.

# Evolution via `/change query`

N/A — vista estable.

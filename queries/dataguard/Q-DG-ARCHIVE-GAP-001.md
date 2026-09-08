---
query_id: Q-DG-ARCHIVE-GAP-001
version: 1.0.0

domain: dataguard
purpose: Rangos de secuencia faltantes por thread — thread-aware, nunca comparado entre threads como una sola serie (# 15, # 58 del prompt de Fase 5)

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: STANDBY

objects_accessed: [V$ARCHIVE_GAP]
privileges_required: [SELECT on V$ARCHIVE_GAP]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 50
max_output_bytes: 16384

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_dataguard_gap_query.sh, tests/test_archive_gap.sh, tests/test_rac_thread_gap.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT thread#, low_sequence#, high_sequence#
FROM   v$archive_gap
ORDER  BY thread#, low_sequence#;
```

Cada fila ya viene separada por `THREAD#` — el skill que consume esta evidencia nunca reordena/combina secuencias entre threads distintos (`# 15`).

# Notes by version

`V$ARCHIVE_GAP` estable desde 10g.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`. `database_role_scope: STANDBY`.

# Cost classification rationale

`LOW` — la vista sólo tiene filas cuando hay un gap real; un ambiente sano devuelve 0 filas.

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP.

# Evolution via `/change query`

N/A — vista estable, sin extensión prevista.

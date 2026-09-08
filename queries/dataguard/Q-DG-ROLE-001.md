---
query_id: Q-DG-ROLE-001
version: 1.0.0

domain: dataguard
purpose: Rol, modo de apertura, estado de switchover, protección y flashback — role discovery robusto (# 9 del prompt de Fase 5)

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$DATABASE]
privileges_required: [SELECT on V$DATABASE]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 1
max_output_bytes: 4096

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_dataguard_role_query.sh, tests/test_primary_standby_detection.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_dg_role_query_only_uses_vdatabase_columns.sh, tests/test_log_archive_config_not_selected_from_vdatabase.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT db_unique_name, database_role, open_mode, switchover_status,
       protection_mode, protection_level, force_logging, flashback_on
FROM   v$database;
```

`DATABASE_ROLE` es la única fuente de verdad de rol — nunca se infiere de `OPEN_MODE` (`# 9`: una base en `READ ONLY` no es automáticamente standby).

`LOG_ARCHIVE_CONFIG` **no** es columna de `V$DATABASE` (defecto de certificación corregido en PHASE 5 — DATA GUARD COMPATIBILITY & QUERY CERTIFICATION HARDENING, ver `docs/PHASE_5_COMPATIBILITY_HARDENING.md`) — es un parámetro de inicialización, se obtiene vía `Q-ORA-PARAMETERS-001` (`V$PARAMETER`, ya certificada en Oracle Core) filtrando `name = 'log_archive_config'`. `dataguard/role`/`dataguard/configuration-drift` correlacionan ambas evidencias, nunca seleccionan `LOG_ARCHIVE_CONFIG` desde `V$DATABASE`.

# Notes by version

Todas las columnas usadas son estables desde 10g. `FLASHBACK_ON` reporta `YES`/`NO`/`RESTORE POINT ONLY` según versión — el skill lo trata como booleano cuando es `YES`, cualquier otro valor se reporta textual.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER` — en CDB, Data Guard aplica al CDB completo, la query se ejecuta desde `CDB$ROOT`. `database_role_scope: ANY` porque el rol es precisamente lo que esta query determina.

# Cost classification rationale

`LOW` — una sola fila, sin joins.

# License notes

Ninguna — metadata core de rol, no requiere Diagnostics Pack ni Active Data Guard.

# Sanitization notes

`db_unique_name` → MASK por defecto.

# Evolution via `/change query`

Ninguna evolución prevista — vista estable en todas las versiones soportadas.

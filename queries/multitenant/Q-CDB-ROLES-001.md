---
query_id: Q-CDB-ROLES-001
version: 1.0.0

domain: multitenant
purpose: Visibilidad de roles comunes vs. locales por contenedor — nunca DDL

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: CDB_ROOT_ONLY
database_role_scope: ANY

objects_accessed: [CDB_ROLES]
privileges_required: [SELECT on CDB_ROLES]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 200
max_output_bytes: 65536

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_lockdown_profile_modify.sh, tests/test_no_write_operations.sh, tests/test_multitenant_container_scope.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT con_id, role, common, oracle_maintained
FROM   cdb_roles
ORDER  BY con_id, common DESC, role;
```

`COMMON` (`YES`/`NO`) es la fuente de verdad de rol común vs. local (`# 23` del prompt). Sólo visibility/assessment — nunca DDL, no se convierte en Security deep assessment.

# Notes by version

`CDB_ROLES.COMMON`/`ORACLE_MAINTAINED` disponibles desde 12.1.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`CDB_ROOT_ONLY`. `database_role_scope: ANY`.

# Cost classification rationale

`LOW` — número de roles típicamente acotado (decenas), incluso con roles locales por PDB.

# License notes

Ninguna.

# Sanitization notes

`role` → MASK por defecto salvo roles `ORACLE_MAINTAINED = 'Y'` (nombres estándar).

# Evolution via `/change query`

N/A — privilegios otorgados a cada rol quedan fuera de alcance de esta fase (Security deep assessment futuro).

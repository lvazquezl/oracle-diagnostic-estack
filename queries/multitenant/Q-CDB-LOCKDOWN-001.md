---
query_id: Q-CDB-LOCKDOWN-001
version: 1.0.0

domain: multitenant
purpose: Visibilidad de lockdown profiles asignados y resumen de reglas — sólo lectura, nunca modifica perfiles

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: CDB_ROOT_ONLY
database_role_scope: ANY

objects_accessed: [CDB_LOCKDOWN_PROFILES]
privileges_required: [SELECT on CDB_LOCKDOWN_PROFILES]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 500
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

# Nota de version: DBA_LOCKDOWN_PROFILES/CDB_LOCKDOWN_PROFILES existen desde 12.2 (Lockdown
# Profiles introducidos en esa versión) — no en 12.1. Verificado antes de declarar metadata.
tests: [tests/test_no_write_operations.sh, tests/test_no_lockdown_profile_modify.sh, tests/test_multitenant_query_version_compatibility.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT con_id, profile_name, rule_type, rule, clause, clause_option, status
FROM   cdb_lockdown_profiles
ORDER  BY con_id, profile_name, rule_type, rule;
```

Sólo visibility/assessment — nunca `ALTER LOCKDOWN PROFILE` (`# 32` del prompt). El skill (`multitenant/lockdown-profiles`) resume las reglas por perfil y correlaciona `con_id`/`profile_name` con la PDB que lo tiene asignado (asignación visible en `DBA_PDBS`/`CDB_PDBS`, no en esta vista misma).

# Notes by version

`CDB_LOCKDOWN_PROFILES` disponible desde 12.2 — Lockdown Profiles no existen en 12.1 (`# 5`: no asumir features modernas en 12.1).

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`CDB_ROOT_ONLY`. `database_role_scope: ANY`.

# Cost classification rationale

`LOW` — número de perfiles/reglas es acotado (los 3 perfiles por defecto `PRIVATE_DBAAS`/`PUBLIC_DBAAS`/`SAAS` más los definidos por el DBA).

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP (nombres de perfil/reglas son configuración de seguridad, no datos de aplicación).

# Evolution via `/change query`

N/A — no se convierte en Security deep assessment (`# 32`, `# 73`).

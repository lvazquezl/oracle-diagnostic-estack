---
query_id: Q-SEC-COMMON-LOCAL-USERS-001
version: 1.0.0

domain: security
purpose: >
  Visibilidad cross-container de usuarios comunes vs. locales para Security posture assessment
  — reutiliza la vista CDB_USERS ya certificada en Fase 6, con las columnas de posture
  adicionales que Q-CDB-USERS-001 declaró explícitamente fuera de su propio alcance (# 23 del
  prompt de Fase 8, "no se convierte en Security deep assessment" en Q-CDB-USERS-001).

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: CDB_ROOT_ONLY
database_role_scope: ANY

objects_accessed: [CDB_USERS]
privileges_required: [SELECT on CDB_USERS]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 20
max_rows: 500
max_output_bytes: 131072

sensitivity: HIGH
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_no_password_hash_exposure.sh, tests/test_security_common_local_users.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT con_id, username, common, account_status, oracle_maintained, authentication_type,
       profile, lock_date, expiry_date
FROM   cdb_users
ORDER  BY con_id, common DESC, username;
```

Extiende `Q-CDB-USERS-001` (que sólo selecciona `con_id, username, common, account_status,
oracle_maintained`) con `authentication_type, profile, lock_date, expiry_date` para permitir
password/profile posture cross-container en Security, sin duplicar la certificación base de
`Q-CDB-USERS-001` — ambas queries coexisten con propósitos distintos (visibilidad básica vs.
posture assessment).

# Notes by version

`CDB_USERS` certificada desde 12.1 (Fase 6). Todas las columnas seleccionadas aquí están
disponibles desde 12.1 (mirror de `DBA_USERS`, que ya las tiene desde esa versión — ver
`Q-SEC-ACCOUNT-INVENTORY-001-V2`).

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`CDB_ROOT_ONLY`. `database_role_scope: ANY`.

# Cost classification rationale

`MEDIUM` — `CDB_USERS` puede tener cientos de filas en un CDB con muchas PDBs.

# License notes

Ninguna.

# Sanitization notes

`username` → MASK por defecto salvo `oracle_maintained = 'Y'` — mismo criterio que
`Q-CDB-USERS-001`. Nunca se recolecta ninguna columna relacionada con credenciales.

# Evolution via `/change query`

N/A.

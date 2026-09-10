---
query_id: Q-CDB-USERS-001
version: 1.0.0

domain: multitenant
purpose: Visibilidad de usuarios comunes vs. locales por contenedor — nunca password hashes, nunca DDL

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

tests: [tests/test_no_write_operations.sh, tests/test_no_common_user_create.sh, tests/test_no_local_user_create.sh, tests/test_no_password_hash_collection.sh, tests/test_multitenant_query_cost.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT con_id, username, common, account_status, oracle_maintained
FROM   cdb_users
ORDER  BY con_id, common DESC, username;
```

`COMMON` (`YES`/`NO`) es la fuente de verdad de identidad común vs. local — nunca inferida por convención de nombre (`# 23` del prompt: sólo visibility/assessment). Nunca selecciona `PASSWORD`/`SPARE4` ni ninguna columna de hash — no existe en `CDB_USERS` de todas formas, pero se deja explícito por diseño de seguridad. `ORACLE_MAINTAINED` distingue usuarios propios de Oracle (ej. `SYS`, `SYSTEM`) de los creados por el DBA, relevante para `multitenant/components` (`# 24`).

# Notes by version

`CDB_USERS.COMMON`/`ORACLE_MAINTAINED` disponibles desde 12.1 (mirror de `DBA_USERS`, ya con estas columnas desde esa versión).

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`CDB_ROOT_ONLY`. `database_role_scope: ANY`.

# Cost classification rationale

`MEDIUM` — `CDB_USERS` puede tener cientos de filas en un CDB con muchas PDBs y usuarios locales por PDB.

# License notes

Ninguna.

# Sanitization notes

`username` → MASK por defecto salvo usuarios `ORACLE_MAINTAINED = 'Y'` (nombres estándar de Oracle, no sensibles). Nunca se recolecta ninguna columna relacionada con credenciales.

# Evolution via `/change query`

N/A — no se convierte en Security deep assessment (`# 73`); ampliación de privilegios/roles asignados queda fuera de alcance de esta fase.

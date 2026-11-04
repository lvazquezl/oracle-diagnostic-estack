---
query_id: Q-SEC-ACCOUNT-INVENTORY-001
version: 2.0.0

domain: security
purpose: >
  Inventario normalizado de cuentas (account_status, profile, created, expiry_date, lock_date, y
  — sólo 11.2+ — authentication_type, y — sólo 12.1.0.2+ — common/oracle_maintained/last_login)
  — nunca password/hash/verifier (# 7 del prompt de Fase 8; boundaries de patch-level verificados
  en el hardening de Query Compatibility/Static Validator y en la corrección final de
  source-of-truth).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_USERS, CDB_USERS]
privileges_required: [SELECT on DBA_USERS, SELECT on CDB_USERS]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 500
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY


variants:
  - variant_id: Q-SEC-ACCOUNT-INVENTORY-001-V1
    label: legacy_pre12c
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_pre12c, 10.2–11.2: DBA_USERS, sin authentication_type en 10g/11.1)"
  - variant_id: Q-SEC-ACCOUNT-INVENTORY-001-V2
    label: multitenant_pre12102
    oracle_versions: {min: "12.1", max: "12.1.0.1"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (multitenant_pre12102, 12.1–12.1.0.1: CDB_USERS con con_id, sin common/oracle_maintained/last_login)"
  - variant_id: Q-SEC-ACCOUNT-INVENTORY-001-V3
    label: modern_12102plus
    oracle_versions: {min: "12.1.0.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V3 (modern_12102plus, 12.1.0.2–23.0: CDB_USERS completa, solo cuentas propias o abiertas)"

tests: [tests/test_no_write_operations.sh, tests/test_no_password_hash_exposure.sh, tests/test_security_account_inventory.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_pre12c, 10.2–11.2: DBA_USERS, sin authentication_type en 10g/11.1)

```sql
SELECT username, account_status, profile,
       CASE WHEN expiry_date IS NOT NULL THEN ROUND((expiry_date - SYSDATE) * 24, 1) END AS hours_to_expiry,
       CASE WHEN lock_date IS NOT NULL THEN ROUND((SYSDATE - lock_date) * 24, 1) END AS hours_since_lock
FROM   dba_users
ORDER  BY username;
```

# Statement / procedure (read-only) — Variant V2 (multitenant_pre12102, 12.1–12.1.0.1: CDB_USERS con con_id, sin common/oracle_maintained/last_login)

```sql
SELECT con_id, username, account_status, profile, authentication_type,
       CASE WHEN expiry_date IS NOT NULL THEN ROUND((expiry_date - SYSDATE) * 24, 1) END AS hours_to_expiry,
       CASE WHEN lock_date IS NOT NULL THEN ROUND((SYSDATE - lock_date) * 24, 1) END AS hours_since_lock
FROM   cdb_users
ORDER  BY con_id, username;
```

# Statement / procedure (read-only) — Variant V3 (modern_12102plus, 12.1.0.2–23.0: CDB_USERS completa, solo cuentas propias o abiertas)

```sql
SELECT con_id, username, account_status, profile, authentication_type, common, oracle_maintained,
       CASE WHEN last_login IS NOT NULL THEN ROUND((CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE)
                 - CAST(SYS_EXTRACT_UTC(last_login) AS DATE)) * 24, 1) END AS hours_since_last_login,
       CASE WHEN expiry_date IS NOT NULL THEN ROUND((expiry_date - SYSDATE) * 24, 1) END AS hours_to_expiry,
       CASE WHEN lock_date IS NOT NULL THEN ROUND((SYSDATE - lock_date) * 24, 1) END AS hours_since_lock
FROM   cdb_users
WHERE  oracle_maintained = 'N' OR account_status NOT LIKE '%LOCKED%'
ORDER  BY con_id, oracle_maintained, username;
```

# Notes by version

`authentication_type` existe desde 11.2; `common`, `oracle_maintained` y `last_login` desde 12.1.0.2. V3 (12.1.0.2+) limita a cuentas propias o abiertas: las cuentas de Oracle bloqueadas no aportan al assessment y llenarían el tope de filas.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

V1 describe la base (no CDB). V2/V3 leen `CDB_USERS` desde el root: cubren los contenedores visibles por el `CONTAINER_DATA` de la cuenta de diagnóstico.

# Cost classification rationale

`LOW` — `DBA_USERS` rara vez excede unos cientos de filas por container.

# License notes

Ninguna.

# Sanitization notes

`username` y `profile` son identificadores (se enmascaran; el seudónimo de `profile` coincide dentro de la sesión con el de `Q-SEC-PASSWORD-PROFILES-001`, lo que permite saber qué perfil usa cada cuenta). Las fechas (`created`, `lock_date`, `expiry_date`, `last_login`) ya no salen: se calculan en la base como horas con el mismo reloj. `user_id` no se selecciona. Nunca se selecciona ninguna columna de credencial.

# Evolution via `/change query`

Extensiones de columnas (ej. nuevas columnas de posture) vía `/change query`; nuevos boundaries
de versión requieren verificación WebFetch/WebSearch antes de certificar (`/change compatibility`).

2.0.0 CHG-ESTACK-B7-SECURITY-COVERAGE-001: 2.0.0: CDB_USERS por contenedor (V2/V3), fechas convertidas en horas, filtro de cuentas propias o abiertas en V3, sin `user_id`.

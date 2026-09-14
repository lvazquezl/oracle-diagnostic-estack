---
query_id: Q-SEC-ACCOUNT-INVENTORY-001
version: 1.0.0

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

objects_accessed: [DBA_USERS]
privileges_required: [SELECT on DBA_USERS]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 500
max_output_bytes: 131072

sensitivity: HIGH
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-ACCOUNT-INVENTORY-001-V1
    label: legacy_pre12c
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_pre12c, 10g-11g)"
  - variant_id: Q-SEC-ACCOUNT-INVENTORY-001-V2
    label: multitenant_pre12102
    oracle_versions: {min: "12.1", max: "12.1.0.1"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (multitenant_pre12102, 12.1.0.1)"
  - variant_id: Q-SEC-ACCOUNT-INVENTORY-001-V3
    label: modern_12102plus
    oracle_versions: {min: "12.1.0.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V3 (modern_12102plus, 12.1.0.2+)"

tests: [tests/test_no_write_operations.sh, tests/test_no_password_hash_exposure.sh, tests/test_security_account_inventory.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_pre12c, 10g-11g)

```sql
SELECT username, user_id, account_status, lock_date, expiry_date, created, profile
FROM   dba_users
ORDER  BY username;
```

`COMMON`/`ORACLE_MAINTAINED`/`LAST_LOGIN`/`AUTHENTICATION_TYPE` no existen en 10g (Multitenant
no existe; `AUTHENTICATION_TYPE` es 11.2+, `# 22` del prompt) — en 10g/11.1 estos campos publican
`null`/`NOT_APPLICABLE` por diseño de versión, nunca inventados.

# Statement / procedure (read-only) — Variant V2 (multitenant_pre12102, 12.1.0.1)

```sql
SELECT username, user_id, account_status, lock_date, expiry_date, created, profile,
       authentication_type
FROM   dba_users
ORDER  BY username;
```

`AUTHENTICATION_TYPE` verificada disponible desde 11.2 (certificada independientemente de
`COMMON`/`ORACLE_MAINTAINED`/`LAST_LOGIN`, `# 12` del prompt de corrección final: "No asumir que
`AUTHENTICATION_TYPE` comparte automáticamente el mismo boundary"). `COMMON`/`ORACLE_MAINTAINED`/
`LAST_LOGIN` NO se seleccionan en esta variante — las tres requieren específicamente 12.1.0.2
(PHASE 8 FINAL SOURCE-OF-TRUTH CORRECTION: footnote oficial verbatim en
`docs.oracle.com/database/121/REFRN/...` de `DBA_USERS`, verificado en el HTML crudo: "This
column is available starting with Oracle Database 12c Release 1 (12.1.0.2)", adjunta a las tres
columnas — corrige la certificación previa que trataba `COMMON`/`ORACLE_MAINTAINED` como
disponibles desde 12.1.0.1). `security/security-account-inventory` publica
`common: NOT_AVAILABLE`, `oracle_maintained: NOT_AVAILABLE`, `last_login: NOT_AVAILABLE` para
esta variante, nunca inventado.

# Statement / procedure (read-only) — Variant V3 (modern_12102plus, 12.1.0.2+)

```sql
SELECT username, user_id, account_status, lock_date, expiry_date, created, profile,
       authentication_type, common, oracle_maintained, last_login
FROM   dba_users
ORDER  BY username;
```

`COMMON`/`ORACLE_MAINTAINED`/`LAST_LOGIN` verificados disponibles desde 12.1.0.2 específicamente
— mismo footnote oficial (ver arriba). `PASSWORD_CHANGE_DATE` deliberadamente NO se selecciona
aquí pese a existir desde 19c — no aporta a account inventory base; se consulta en
`Q-SEC-PASSWORD-VERSIONS-001` junto con `PASSWORD_VERSIONS` cuando la política de password
strength lo requiere. Nunca se selecciona `PASSWORD` (deprecated) ni `SPARE4` — no existe
capacidad de leer material de credencial en este dominio (`# 26` del prompt de Fase 8).

# Notes by version

10g/11g: sin `COMMON`/`ORACLE_MAINTAINED`/`LAST_LOGIN`/`AUTHENTICATION_TYPE`. 12.1-12.1.0.1:
`AUTHENTICATION_TYPE` disponible (certificada independientemente, 11.2+); `COMMON`/
`ORACLE_MAINTAINED`/`LAST_LOGIN` NO (`NOT_AVAILABLE`, las tres requieren 12.1.0.2). 12.1.0.2+:
todas disponibles. `password_change_date` (19c+) fuera de esta query por diseño — ver arriba.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER` — dentro de un CDB, `DBA_USERS` muestra sólo el container conectado (root o PDB
específica); `CDB_USERS` (Fase 6, `Q-CDB-USERS-001`) es la vista complementaria cross-container
para visibilidad common/local a través de todo el CDB.

# Cost classification rationale

`LOW` — `DBA_USERS` rara vez excede unos cientos de filas por container.

# License notes

Ninguna.

# Sanitization notes

`username` → MASK por defecto salvo `oracle_maintained = 'Y'` (nombres estándar Oracle, no
sensibles, Variant V3 únicamente) — mismo criterio que `Q-CDB-USERS-001`. En Variants V1/V2 (sin
`oracle_maintained`), `username` se enmascara siempre salvo coincidencia con una lista estática de
cuentas Oracle-maintained conocidas por convención (`SYS`, `SYSTEM`, `OUTLN`, etc.), nunca
inferida de una columna que no existe en esa variante. Nunca se recolecta `PASSWORD`, `SPARE4`,
password hash, ni verifier.

# Evolution via `/change query`

Extensiones de columnas (ej. nuevas columnas de posture) vía `/change query`; nuevos boundaries
de versión requieren verificación WebFetch/WebSearch antes de certificar (`/change compatibility`).

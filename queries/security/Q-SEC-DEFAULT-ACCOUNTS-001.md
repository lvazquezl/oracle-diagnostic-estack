---
query_id: Q-SEC-DEFAULT-ACCOUNTS-001
version: 1.0.0

domain: security
purpose: >
  Identifica cuentas que aún usan su contraseña por defecto (`DBA_USERS_WITH_DEFPWD`) —
  visibilidad de nombre de cuenta, nunca la contraseña por defecto misma (# 8, # 115 del
  prompt de Fase 8).

supported_oracle_versions: [11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_USERS_WITH_DEFPWD, DBA_USERS]
privileges_required: [SELECT on DBA_USERS_WITH_DEFPWD, SELECT on DBA_USERS]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 200
max_output_bytes: 65536

sensitivity: HIGH
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-DEFAULT-ACCOUNTS-001-V1
    label: legacy_pre12102
    oracle_versions: {min: "11.0", max: "12.1.0.1"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_pre12102)"
  - variant_id: Q-SEC-DEFAULT-ACCOUNTS-001-V2
    label: modern_12102plus
    oracle_versions: {min: "12.1.0.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_12102plus)"

tests: [tests/test_no_write_operations.sh, tests/test_security_default_accounts.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_pre12102)

```sql
SELECT d.username, u.account_status
FROM   dba_users_with_defpwd d
JOIN   dba_users u ON u.username = d.username
ORDER  BY d.username;
```

`DBA_USERS.ORACLE_MAINTAINED` verificada disponible sólo desde **12.1.0.2** (PHASE 8 FINAL
SOURCE-OF-TRUTH CORRECTION — footnote oficial verbatim en la página de referencia
`docs.oracle.com/database/121/REFRN/...` de `DBA_USERS`, verificado en el HTML crudo: "This
column is available starting with Oracle Database 12c Release 1 (12.1.0.2)"; corrige la
certificación previa "12.1.0.1", basada en evidencia indirecta insuficiente) — no existe en
11g ni en 12.1.0.1. Esta columna NUNCA se selecciona en esta variante. `security/default-accounts`
publica `oracle_maintained: NOT_AVAILABLE` para esta variante, nunca inventado (`# 7` del
hardening).

# Statement / procedure (read-only) — Variant V2 (modern_12102plus)

```sql
SELECT d.username, u.account_status, u.oracle_maintained
FROM   dba_users_with_defpwd d
JOIN   dba_users u ON u.username = d.username
ORDER  BY d.username;
```

`DBA_USERS.ORACLE_MAINTAINED` disponible desde 12.1.0.2 (footnote oficial — ver arriba), igual
que `DBA_USERS.LAST_LOGIN` (no usada por esta query, mismo footnote).

`DBA_USERS_WITH_DEFPWD` verificada disponible desde 11g (WebSearch) — no existe en 10g. En 10g,
`security/default-accounts` publica `has_default_password: NOT_AVAILABLE`, nunca inventado (`#
115` del prompt de Fase 8).

# Notes by version

10g: query completa fuera de alcance — `not_certified_queries` incluye este `query_id` con razón
`view_not_available_pre_11g`. 11g-12.1.0.1: Variant V1, sin `oracle_maintained` (columna no
existe hasta 12.1.0.2). 12.1.0.2+: Variant V2, con `oracle_maintained` — mismo footnote oficial
que `COMMON`/`LAST_LOGIN`, ver
`docs/PHASE_8_FINAL_DBA_USERS_12102_SOURCE_OF_TRUTH_CORRECTION.md`.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW` — típicamente un puñado de cuentas Oracle-maintained.

# License notes

Ninguna.

# Output normalization

Ambas variantes normalizan al mismo modelo (`security/default-accounts`, # 7 del hardening):

```yaml
default_account:
  username_token:
  account_status:
  oracle_maintained: "Y"|"N"|NOT_AVAILABLE
  source_variant: Q-SEC-DEFAULT-ACCOUNTS-001-V1|Q-SEC-DEFAULT-ACCOUNTS-001-V2
```

Variant V1 (legacy_pre12102) siempre publica `oracle_maintained: NOT_AVAILABLE` — nunca `"Y"`/`"N"`
inventado. Variant V2 (modern_12102plus) publica el valor real de la columna.

# Sanitization notes

`username` → MASK por defecto salvo `oracle_maintained = 'Y'` (Variant V2) — en Variant V1,
`oracle_maintained` es `NOT_AVAILABLE`, así que el criterio de excepción no aplica y `username`
se enmascara siempre salvo que el nombre coincida con un cuenta Oracle-maintained conocida por
convención (`SYS`, `SYSTEM`, `OUTLN`, etc. — lista estática, nunca inferida de `oracle_maintained`
porque esa columna no existe en esta variante).

# Evolution via `/change query`

N/A.

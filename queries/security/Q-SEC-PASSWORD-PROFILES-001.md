---
query_id: Q-SEC-PASSWORD-PROFILES-001
version: 1.0.0

domain: security
purpose: >
  Parámetros de password/account policy por profile — base de password/profile posture y
  password-strength policy assessment (# 14, # 16 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_PROFILES]
privileges_required: [SELECT on DBA_PROFILES]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 200
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_security_password_profiles.sh, tests/test_password_minimum_length_policy.sh, tests/test_password_life_time_policy.sh, tests/test_failed_login_attempts_policy.sh, tests/test_password_lock_time_policy.sh, tests/test_password_grace_time_policy.sh, tests/test_password_reuse_time_policy.sh, tests/test_password_reuse_max_policy.sh, tests/test_password_verify_function_present.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT profile, resource_name, resource_type, limit
FROM   dba_profiles
WHERE  resource_name IN ('FAILED_LOGIN_ATTEMPTS', 'PASSWORD_LIFE_TIME', 'PASSWORD_REUSE_TIME',
                          'PASSWORD_REUSE_MAX', 'PASSWORD_LOCK_TIME', 'PASSWORD_GRACE_TIME',
                          'PASSWORD_VERIFY_FUNCTION', 'INACTIVE_ACCOUNT_TIME')
ORDER  BY profile, resource_name;
```

`resource_name` es un `WHERE IN` explícito — nunca se selecciona `*` sobre `DBA_PROFILES` (que
incluye recursos no relacionados con password, ej. `SESSIONS_PER_USER`, `CPU_PER_SESSION`, fuera
de alcance de este dominio). `INACTIVE_ACCOUNT_TIME` como `RESOURCE_NAME` existe como fila sólo
desde 12.2 (verificado — múltiples fuentes independientes citan "12c Release 2"; en 10g/11g/12.1
simplemente no aparece esa fila, nunca se asume `UNLIMITED` por defecto sin evidencia).

# Notes by version

Columna `resource_name`/`limit`/`resource_type` estables desde versiones muy tempranas. El valor
`INACTIVE_ACCOUNT_TIME` de `resource_name` sólo aparece desde 12.2.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW` — típicamente menos de una docena de profiles por instancia.

# License notes

Ninguna.

# Sanitization notes

`profile`/`resource_name`/`limit` son metadata de configuración, no PII → KEEP.
`PASSWORD_VERIFY_FUNCTION` (el nombre de función en `limit`) → KEEP (nombre de objeto PL/SQL, no
secreto).

# Evolution via `/change query`

N/A.

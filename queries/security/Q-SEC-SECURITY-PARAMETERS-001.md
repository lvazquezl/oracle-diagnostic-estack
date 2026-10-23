---
query_id: Q-SEC-SECURITY-PARAMETERS-001
version: 2.0.0

domain: security
purpose: Parámetros de inicialización con impacto de seguridad — security-parameters (# 36 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$PARAMETER]
privileges_required: [SELECT on V$PARAMETER]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 20
max_output_bytes: 16384

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-SECURITY-PARAMETERS-001-V1
    label: all_versions
    oracle_versions: {min: "10.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (all_versions, 10.2–23.0: parámetros de seguridad con valor clasificado)"

tests: [tests/test_no_write_operations.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (all_versions, 10.2–23.0: parámetros de seguridad con valor clasificado)

```sql
SELECT name AS parameter_name, isdefault,
       CASE WHEN REGEXP_LIKE(value, '^[0-9]{1,15}$') THEN TO_NUMBER(value) END AS value_number,
       CASE WHEN UPPER(value) IN ('TRUE', 'FALSE') THEN UPPER(value) END AS value_flag,
       CASE WHEN UPPER(value) IN ('ALERT', 'DB', 'DB, EXTENDED', 'EXCLUSIVE', 'EXTENDED', 'LOG', 'NONE', 'OS', 'SHARED', 'TRACE', 'XML', 'XML, EXTENDED') THEN UPPER(value) END AS value_keyword
FROM   v$parameter
WHERE  name IN ('audit_sys_operations', 'audit_trail', 'global_names', 'o7_dictionary_accessibility', 'os_authent_prefix', 'os_roles', 'remote_login_passwordfile', 'remote_os_authent', 'remote_os_roles', 'resource_limit',
                'sec_case_sensitive_logon', 'sec_max_failed_login_attempts', 'sec_protocol_error_trace_action',
                'sec_return_server_release_banner', 'sql92_security')
ORDER  BY name;
```

# Notes by version

Un parámetro que no existe en la versión (por ejemplo `o7_dictionary_accessibility` en 19c) simplemente no devuelve fila.

# Notes by platform

Ninguna.

# Container / role scope notes

Valores de la instancia vistos desde el root.

# Cost classification rationale

`LOW`.

# License notes

Ninguna.

# Sanitization notes

El valor nunca sale crudo: solo como número, `TRUE`/`FALSE` o una palabra clave de una lista cerrada (patrón de `Q-ORA-PARAMETERS-001`). `os_authent_prefix` solo informa si es default.

# Evolution via `/change query`

N/A.

2.0.0 CHG-ESTACK-B7-SECURITY-COVERAGE-001: 2.0.0: valor clasificado (number/flag/keyword) en vez de crudo; 15 parámetros de seguridad.

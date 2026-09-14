---
query_id: Q-SEC-SECURITY-PARAMETERS-001
version: 1.0.0

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

tests: [tests/test_no_write_operations.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT name, value, isdefault
FROM   v$parameter
WHERE  name IN ('remote_login_passwordfile', 'o7_dictionary_accessibility',
                'sec_case_sensitive_logon', 'sql92_security', 'remote_os_authent', 'audit_trail')
ORDER  BY name;
```

Cada parámetro se evalúa con version-awareness por `security/security-parameters` — ej.
`O7_DICTIONARY_ACCESSIBILITY` es legacy (default `FALSE` desde 10g) y `REMOTE_OS_AUTHENT`
default `FALSE` desde 11g; ninguna aplicabilidad se asume universal sin verificar el default real
de cada versión (`# 36` del prompt).

# Notes by version

`V$PARAMETER` estable. Cada parámetro individual puede no existir/estar deprecado en versiones
específicas — `security/security-parameters` publica `applicable: false` para los que no
aplican al target, nunca inventa un valor.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW`.

# License notes

Ninguna.

# Sanitization notes

`value` → KEEP (valores de parámetro de seguridad, no PII).

# Evolution via `/change query`

N/A.

---
query_id: Q-SEC-PASSWORD-VERSIONS-001
version: 1.0.0

domain: security
purpose: >
  Awareness de tipo de verifier de password (legacy/modern) por cuenta, nunca contenido — password-verifiers (# 25, # 26 del prompt de Fase 8).

supported_oracle_versions: [11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_USERS]
privileges_required: [SELECT on DBA_USERS]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 500
max_output_bytes: 65536

sensitivity: HIGH
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_no_password_verifier_exposure.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT username, password_versions
FROM   dba_users
ORDER  BY username;
```

`PASSWORD_VERSIONS` reporta qué formatos de hash existen para la cuenta (`10G`, `11G`, `12C`,
`HTTP`) — nunca el valor del hash mismo. `security/password-verifiers` traduce esto a
`LEGACY_PRESENT|MODERN_PRESENT|MIXED|UNKNOWN`, nunca expone la cadena cruda de
`PASSWORD_VERSIONS` tal cual si contuviera algo más que el indicador de formato (no lo contiene,
pero el skill nunca lo asume sin normalizar).

# Notes by version

`PASSWORD_VERSIONS` disponible desde 11g (introducida junto con case-sensitive passwords/SHA-1
hashing, 11.1) — en 10g no existe esta columna, `password_verifiers` publica
`capability_status: UNSUPPORTED`.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW`.

# License notes

Ninguna.

# Sanitization notes

`username` → MASK por defecto. `password_versions` → KEEP (es un indicador de formato, ej.
"10G 11G", nunca el hash mismo) pero normalizado a un enum antes de reportarse — nunca la cadena
cruda de Oracle.

# Evolution via `/change query`

N/A.

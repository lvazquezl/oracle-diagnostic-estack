---
query_id: Q-SEC-OLS-STATUS-001
version: 1.0.0

domain: security
purpose: Instalado/habilitado de Oracle Label Security — siempre licensing-gated, nunca modifica (# 40 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$OPTION]
privileges_required: [SELECT on V$OPTION]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 5
max_output_bytes: 8192

sensitivity: LOW
sanitization_required: false

license_requirements: "Oracle Label Security — SEPARATELY_LICENSED salvo confirmación explícita del DBA"

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_ols_awareness.sh, tests/test_security_licensing_gate.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT value
FROM   v$option
WHERE  parameter = 'Oracle Label Security';
```

`PARAMETER = 'Oracle Label Security'` es el string exacto verificado (case-sensitive,
WebSearch). Nunca crea/modifica policies/labels.

# Notes by version

`V$OPTION` estable desde versiones muy tempranas.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW`.

# License notes

`SEPARATELY_LICENSED` por defecto.

# Sanitization notes

Ninguna.

# Evolution via `/change query`

N/A.

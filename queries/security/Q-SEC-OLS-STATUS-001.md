---
query_id: Q-SEC-OLS-STATUS-001
version: 2.0.0

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

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-OLS-STATUS-001-V1
    label: all_versions
    oracle_versions: {min: "10.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (all_versions, 10.2–23.0: estado de la opción)"

tests: [tests/test_no_write_operations.sh, tests/test_ols_awareness.sh, tests/test_security_licensing_gate.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (all_versions, 10.2–23.0: estado de la opción)

```sql
SELECT value AS ols_option
FROM   v$option
WHERE  parameter = 'Oracle Label Security';
```

# Notes by version

`V$OPTION` es estable en todas las versiones soportadas.

# Notes by platform

Ninguna.

# Container / role scope notes

Instancia.

# Cost classification rationale

`LOW`.

# License notes

Leer `V$OPTION` no usa Oracle Label Security: indica si está habilitada. El uso de la opción sí requiere licencia.

# Sanitization notes

Un solo valor `TRUE`/`FALSE`.

# Evolution via `/change query`

N/A.

2.0.0 CHG-ESTACK-B7-SECURITY-COVERAGE-001: 2.0.0: columna `ols_option` (antes `value`), `license_requirements: none` (lectura de estado).

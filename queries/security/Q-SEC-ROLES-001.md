---
query_id: Q-SEC-ROLES-001
version: 1.0.0

domain: security
purpose: Inventario de roles definidos (# 10 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_ROLES]
privileges_required: [SELECT on DBA_ROLES]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 200
max_output_bytes: 65536

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-ROLES-001-V1
    label: legacy_pre12c
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_pre12c, 10g-11g)"
  - variant_id: Q-SEC-ROLES-001-V2
    label: modern_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_12plus, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_security_roles.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_pre12c, 10g-11g)

```sql
SELECT role
FROM   dba_roles
ORDER  BY role;
```

# Statement / procedure (read-only) — Variant V2 (modern_12plus, 12.1+)

```sql
SELECT role, common, oracle_maintained
FROM   dba_roles
ORDER  BY common DESC, role;
```

# Notes by version

`COMMON`/`ORACLE_MAINTAINED` en `DBA_ROLES` disponibles desde 12.1 (Multitenant).

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW`.

# License notes

Ninguna.

# Sanitization notes

`role` → KEEP (nombres de rol no son PII, salvo convención de nombrado sensible del cliente —
evaluado caso a caso por sanitizers/data-classification-policy.md).

# Evolution via `/change query`

N/A.

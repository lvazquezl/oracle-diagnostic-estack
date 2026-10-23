---
query_id: Q-SEC-PUBLIC-SYSTEM-GRANTS-001
version: 2.0.0

domain: security
purpose: System privileges otorgados a PUBLIC — PUBLIC exposure analysis (# 12 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_SYS_PRIVS, CDB_SYS_PRIVS]
privileges_required: [SELECT on DBA_SYS_PRIVS, SELECT on CDB_SYS_PRIVS]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 200
max_output_bytes: 65536

sensitivity: HIGH
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-PUBLIC-SYSTEM-GRANTS-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_SYS_PRIVS)"
  - variant_id: Q-SEC-PUBLIC-SYSTEM-GRANTS-001-V2
    label: cdb_aware_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_12plus, 12.1–23.0: CDB_SYS_PRIVS con con_id)"

tests: [tests/test_no_write_operations.sh, tests/test_security_public_grants.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_SYS_PRIVS)

```sql
SELECT privilege, admin_option
FROM   dba_sys_privs
WHERE  grantee = 'PUBLIC'
ORDER  BY privilege;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_12plus, 12.1–23.0: CDB_SYS_PRIVS con con_id)

```sql
SELECT con_id, privilege, admin_option
FROM   cdb_sys_privs
WHERE  grantee = 'PUBLIC'
ORDER  BY con_id, privilege;
```

# Notes by version

`CDB_SYS_PRIVS` existe desde 12.1.

# Notes by platform

Ninguna.

# Container / role scope notes

V2 cubre los contenedores visibles por `CONTAINER_DATA`.

# Cost classification rationale

`LOW` — PUBLIC rara vez tiene más de unas pocas docenas de system privileges.

# License notes

Ninguna.

# Sanitization notes

Los privilegios de sistema son términos de Oracle (`privilege` como `oracle_term`).

# Evolution via `/change query`

N/A.

2.0.0 CHG-ESTACK-B7-SECURITY-COVERAGE-001: 2.0.0: `CDB_SYS_PRIVS` por contenedor y `admin_option`.

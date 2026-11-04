---
query_id: Q-SEC-ROLES-001
version: 2.0.0

domain: security
purpose: Inventario de roles definidos (# 10 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_ROLES, CDB_ROLES]
privileges_required: [SELECT on DBA_ROLES, SELECT on CDB_ROLES]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 200
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY


variants:
  - variant_id: Q-SEC-ROLES-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_ROLES, conteo)"
  - variant_id: Q-SEC-ROLES-001-V2
    label: cdb_aware_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_12plus, 12.1–23.0: CDB_ROLES por contenedor, common y oracle_maintained)"

tests: [tests/test_no_write_operations.sh, tests/test_security_roles.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_ROLES, conteo)

```sql
SELECT COUNT(*) AS role_count
FROM   dba_roles;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_12plus, 12.1–23.0: CDB_ROLES por contenedor, common y oracle_maintained)

```sql
SELECT con_id, common, oracle_maintained, COUNT(*) AS role_count
FROM   cdb_roles
GROUP  BY con_id, common, oracle_maintained
ORDER  BY con_id, common DESC, oracle_maintained;
```

# Notes by version

V2 mantiene la frontera 12.1 de 1.x (`COMMON`/`ORACLE_MAINTAINED` de `CDB_ROLES`), igual que `Q-SEC-ROLE-SYSTEM-PRIVILEGES-001`.

# Notes by platform

Ninguna.

# Container / role scope notes

V2 cubre los contenedores visibles por `CONTAINER_DATA`.

# Cost classification rationale

`LOW`.

# License notes

Ninguna.

# Sanitization notes

Solo conteos. Los nombres de roles propios se ven, enmascarados, en `Q-SEC-ROLE-GRANTS-001` y en los collectors de privilegios.

# Evolution via `/change query`

N/A.

2.0.0 CHG-ESTACK-B7-SECURITY-COVERAGE-001: 2.0.0: conteo por contenedor, `common` y `oracle_maintained`, sin nombres.

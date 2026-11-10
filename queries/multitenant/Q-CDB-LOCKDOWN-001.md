---
query_id: Q-CDB-LOCKDOWN-001
version: 2.0.0

domain: multitenant
purpose: Lockdown profiles por contenedor: perfil de Oracle o propio, tipo y estado de regla y cantidad de reglas — sólo lectura, nunca modifica perfiles

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: CDB_ROOT_ONLY
database_role_scope: ANY

objects_accessed: [CDB_LOCKDOWN_PROFILES]
privileges_required: [SELECT on CDB_LOCKDOWN_PROFILES]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 200
max_output_bytes: 32768

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-CDB-LOCKDOWN-001-V1
    label: lockdown_122plus
    oracle_versions: {min: "12.2", max: "23.0"}
    container_scope: CDB_ROOT_ONLY
    sql_block: "Variant V1 (lockdown_122plus, 12.2–23.0: CDB_LOCKDOWN_PROFILES)"

tests: [tests/test_no_write_operations.sh, tests/test_no_lockdown_profile_modify.sh, tests/test_multitenant_query_version_compatibility.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (lockdown_122plus, 12.2–23.0: CDB_LOCKDOWN_PROFILES)

```sql
SELECT con_id,
       CASE WHEN profile_name IN ('PRIVATE_DBAAS', 'PUBLIC_DBAAS', 'SAAS') THEN 'ORACLE' ELSE 'CUSTOM' END AS profile_kind,
       profile_name AS lockdown_profile,
       NVL(rule_type, 'NONE') AS rule_type,
       NVL(status, 'NONE') AS rule_status,
       COUNT(rule) AS rules
FROM   cdb_lockdown_profiles
GROUP  BY con_id, profile_name, rule_type, status
ORDER  BY con_id, profile_name, rule_type, status;
```

# Notes by version

Lockdown profiles desde 12.2; no existen en 12.1.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`CDB_ROOT_ONLY`: los perfiles se definen en `CDB$ROOT` (o en un application root). Qué perfil usa cada PDB (`PDB_LOCKDOWN`) no es observable desde esta vista: se declara como limitación.

# Cost classification rationale

`LOW` — vista pequeña de metadata.

# License notes

Ninguna.

# Sanitization notes

El nombre de un perfil propio se enmascara (`lockdown_profile`); `profile_kind` conserva si es de Oracle (`PRIVATE_DBAAS`, `PUBLIC_DBAAS`, `SAAS`) o propio. `RULE`, `CLAUSE` y `CLAUSE_OPTION` no salen: solo cuántas reglas hay por tipo y estado.

# Evolution via `/change query`

2.0.0 CHG-ESTACK-B8-OPS-COVERAGE-001: conteo de reglas por perfil, tipo y estado; reglas y cláusulas fuera.

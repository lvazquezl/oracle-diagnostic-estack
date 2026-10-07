---
query_id: Q-ORA-COMPONENTS-001
version: 2.0.0
domain: oracle
purpose: Estado y versión de componentes registrados

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_REGISTRY, CDB_REGISTRY]
privileges_required: [SELECT on DBA_REGISTRY, SELECT on CDB_REGISTRY]

risk_class: R0
cost_class: LOW
timeout_seconds: 10
max_rows: 100
max_output_bytes: 32768

sensitivity: LOW
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

variants:
  - variant_id: Q-ORA-COMPONENTS-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2)"
  - variant_id: Q-ORA-COMPONENTS-001-V2
    label: cdb_aware_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_12plus, 12.1+: CDB_* con con_id)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2)

```sql
SELECT comp_id, comp_name, version, status
FROM   dba_registry
ORDER  BY status, comp_name;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_12plus, 12.1+: CDB_* con con_id)

```sql
SELECT con_id, comp_id, comp_name, version, status
FROM   cdb_registry
ORDER  BY con_id, status, comp_name;
```

# Notes by version

`CDB_REGISTRY` disponible desde 12c como alternativa por PDB.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW`: número fijo y pequeño de componentes.

# License notes

Un componente `VALID` con `OPTION OFF` es evidencia útil para `policies/licensing-awareness-policy.md` (confirma que la feature no está en uso), pero esta query no determina licenciamiento por sí sola.

# Sanitization notes

Todos los campos → KEEP (nombres de componente Oracle estándar, no sensibles).

# Evolution via `/change query`

2.0.0 CHG-ESTACK-PDB-COVERAGE-001: V2 (12.1+) lee `CDB_REGISTRY` y agrega `con_id`: componentes por contenedor (un componente INVALID en la PDB ya no queda oculto).

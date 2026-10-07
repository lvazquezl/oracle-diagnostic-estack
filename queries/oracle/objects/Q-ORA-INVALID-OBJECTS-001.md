---
query_id: Q-ORA-INVALID-OBJECTS-001
version: 2.0.0
domain: oracle
purpose: Objetos inválidos por owner/tipo, priorizando schemas de sistema

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_OBJECTS, CDB_OBJECTS]
privileges_required: [SELECT on DBA_OBJECTS, SELECT on CDB_OBJECTS]

risk_class: R0
cost_class: MEDIUM
timeout_seconds: 20
max_rows: 500
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

variants:
  - variant_id: Q-ORA-INVALID-OBJECTS-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2)"
  - variant_id: Q-ORA-INVALID-OBJECTS-001-V2
    label: cdb_aware_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_12plus, 12.1+: CDB_* con con_id)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2)

```sql
SELECT owner, object_type, object_name,
       CASE WHEN owner IN ('SYS','SYSTEM') THEN 'SYSTEM' ELSE 'APPLICATION' END AS category
FROM   dba_objects
WHERE  status = 'INVALID'
ORDER  BY category, owner, object_type;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_12plus, 12.1+: CDB_* con con_id)

```sql
SELECT con_id, owner, object_type, object_name,
       CASE WHEN owner IN ('SYS','SYSTEM') THEN 'SYSTEM' ELSE 'APPLICATION' END AS category
FROM   cdb_objects
WHERE  status = 'INVALID'
ORDER  BY con_id, category, owner, object_type;
```

# Notes by version

Sin diferencias estructurales relevantes.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW`: el conjunto de objetos inválidos es típicamente pequeño respecto al total de `DBA_OBJECTS`.

# License notes

Ninguna.

# Sanitization notes

`owner`/`object_name` → MASK por defecto salvo que sea `SYS`/`SYSTEM` (nombres de sistema, no sensibles).

# Evolution via `/change query`

2.0.0 CHG-ESTACK-PDB-COVERAGE-001: V2 (12.1+) lee `CDB_OBJECTS` y agrega `con_id`: desde CDB$ROOT cubre el root y las PDB visibles por `CONTAINER_DATA` (FND-0021 de ANA-20261007-001). En non-CDB `con_id` es 0. `cost_class` sube a MEDIUM: `CDB_*` recorre todos los contenedores.

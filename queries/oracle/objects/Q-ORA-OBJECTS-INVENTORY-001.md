---
query_id: Q-ORA-OBJECTS-INVENTORY-001
version: 1.0.0
domain: oracle
purpose: Inventario agregado de objetos por owner/tipo/estado

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_OBJECTS]
privileges_required: [SELECT on DBA_OBJECTS]

risk_class: R0
cost_class: MEDIUM
timeout_seconds: 30
max_rows: 1000
max_output_bytes: 262144

sensitivity: MEDIUM
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_no_application_table_access.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT owner, object_type, status, COUNT(*) AS object_count
FROM   dba_objects
GROUP  BY owner, object_type, status
ORDER  BY object_count DESC;
```

Sólo metadata agregada — nunca contenido de las tablas ni filas de aplicación.

# Notes by version

`CDB_OBJECTS` disponible desde 12c como alternativa consolidada cross-PDB (no usada por defecto en Fase 2).

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`MEDIUM`: `DBA_OBJECTS` puede ser grande en esquemas con muchos objetos; la agregación por owner/tipo/estado lo acota a un resultado manejable.

# License notes

Ninguna.

# Sanitization notes

`owner` → MASK por defecto (puede revelar nombre de aplicación/cliente).

# Evolution via `/change query`

---
query_id: Q-CDB-CONTAINER-DATA-001
version: 1.0.0
domain: multitenant
purpose: Contenedores que la cuenta de diagnóstico puede ver desde CDB$ROOT (atributo CONTAINER_DATA), para declarar el alcance real de las vistas CDB_* y V$ filtradas

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: CDB_ROOT_ONLY
database_role_scope: ANY

objects_accessed: [DBA_CONTAINER_DATA]
privileges_required: [SELECT on DBA_CONTAINER_DATA]

risk_class: R0
cost_class: LOW
timeout_seconds: 10
max_rows: 100
max_output_bytes: 16384

sensitivity: LOW
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_collector_factory.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT CASE WHEN container_name IS NULL       THEN 'NONE'
            WHEN container_name = 'CDB$ROOT'  THEN 'ROOT'
            WHEN container_name = 'PDB$SEED'  THEN 'SEED'
            ELSE 'PDB' END                                                    AS container_kind,
       CASE WHEN container_name IN ('CDB$ROOT', 'PDB$SEED') THEN NULL
            ELSE container_name END                                           AS pdb_name,
       default_attr, all_containers,
       CASE WHEN object_name IS NULL THEN 'DEFAULT' ELSE 'OBJECT' END         AS attr_scope
FROM   dba_container_data
WHERE  username = SYS_CONTEXT('USERENV', 'SESSION_USER')
ORDER  BY 1, 2;
```

Sin filas: la cuenta solo ve el contenedor al que está conectada. `all_containers = 'Y'`: ve todos. Si no, una fila por contenedor permitido (`pdb_name` se enmascara). `attr_scope = 'OBJECT'` indica que el atributo se dio para una vista concreta, no por defecto.

# Notes by version

`DBA_CONTAINER_DATA` existe desde 12.1 (multitenant).

# Notes by platform

Ninguna diferencia.

# Container / role scope notes

`CDB_ROOT_ONLY`: el atributo `CONTAINER_DATA` solo aplica a usuarios comunes conectados al root.

# Cost classification rationale

`LOW`: pocas filas, filtradas por el usuario de la sesión.

# License notes

Ninguna.

# Sanitization notes

`pdb_name` → MASK; tipo de contenedor y flags (Y/N, DEFAULT/OBJECT) → KEEP. No expone otros usuarios: filtra por `SESSION_USER`.

# Evolution via `/change query`

CHG-ESTACK-ASSESSMENT-ACCURACY-001 — creada: la revisión de ANA-20261008-001 mostró que `V$PDBS`, `GV$SERVICES` y las `CDB_*` dependen de `CONTAINER_DATA` (PDB$SEED no aparecía) y que el alcance se infería de la documentación, no de la base (FND-0025).

---
query_id: Q-CDB-PARAMETERS-001
version: 1.0.0

domain: multitenant
purpose: Scope de parámetros no-default entre CDB$ROOT y PDBs — heredado vs. override vs. instance-specific

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: CDB_ROOT_ONLY
database_role_scope: ANY

objects_accessed: [GV$SYSTEM_PARAMETER]
privileges_required: [SELECT on GV$SYSTEM_PARAMETER]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 20
max_rows: 500
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_multitenant_query_cost.sh, tests/test_no_parameter_change.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT con_id, inst_id, name, value, ispdb_modifiable, isinstance_modifiable
FROM   gv$system_parameter
WHERE  ispdb_modifiable = 'TRUE'
ORDER  BY name, con_id, inst_id;
```

`ISPDB_MODIFIABLE` distingue parámetros que pueden diferir por PDB de los que son estrictamente CDB-wide — acotar a `'TRUE'` evita traer miles de parámetros idénticos en todas las PDBs por herencia (`# 21` del prompt: diferenciar heredado/override/instance-specific). El skill (`multitenant/parameters`) correlaciona `con_id=1` (CDB$ROOT, valor base) contra cada PDB para determinar si el valor es heredado o un override real.

# Notes by version

`GV$SYSTEM_PARAMETER.ISPDB_MODIFIABLE`/`CON_ID` disponibles desde 12.1 (multitenant). `ISINSTANCE_MODIFIABLE` estable desde 10g, reutilizada aquí para distinguir override instance-specific de override PDB-specific.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`CDB_ROOT_ONLY` — `GV$SYSTEM_PARAMETER` ya es CDB-aware, una sola consulta desde CDB$ROOT cubre todos los contenedores. `database_role_scope: ANY`.

# Cost classification rationale

`MEDIUM` — el filtro `ispdb_modifiable='TRUE'` acota significativamente, pero el escaneo subyacente de `GV$SYSTEM_PARAMETER` sobre muchas PDBs/instancias sigue siendo más costoso que una query de una sola fila.

# License notes

Ninguna.

# Sanitization notes

`value` → condicional (`DROP` si el nombre del parámetro sugiere contenido sensible, ej. rutas de wallet, mismo criterio que `Q-ORA-PARAMETERS-001` de Oracle Core).

# Evolution via `/change query`

N/A — vista estable.

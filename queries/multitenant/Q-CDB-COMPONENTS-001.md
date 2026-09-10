---
query_id: Q-CDB-COMPONENTS-001
version: 1.0.0

domain: multitenant
purpose: Salud de componentes por contenedor — distingue problemas de CDB$ROOT de problemas específicos de PDB

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: CDB_ROOT_ONLY
database_role_scope: ANY

objects_accessed: [CDB_REGISTRY]
privileges_required: [SELECT on CDB_REGISTRY]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 500
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_multitenant_container_scope.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT con_id, comp_id, comp_name, version, status
FROM   cdb_registry
ORDER  BY con_id, status, comp_name;
```

Mismo modelo que `Q-ORA-COMPONENTS-001` (Oracle Core, `DBA_REGISTRY`), extendido a `CDB_REGISTRY` con `con_id` — `multitenant/components` distingue si un componente `INVALID`/`OPTION_OFF`/`UPGRADED`/`LOADING` corresponde a CDB$ROOT (`con_id=1`) o a una PDB específica (`# 25` del prompt). No duplica el análisis de invalid objects de Oracle Core, sólo lo extiende con el contexto de contenedor.

# Notes by version

`CDB_REGISTRY` disponible desde 12.1 (mirror de `DBA_REGISTRY`, ya certificada en Oracle Core).

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`CDB_ROOT_ONLY`. `database_role_scope: ANY`.

# Cost classification rationale

`LOW` — número de componentes registrados es fijo y pequeño por contenedor (decenas), aunque se multiplique por el número de PDBs sigue siendo acotado.

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP (nombres de componente Oracle estándar, no sensibles).

# Evolution via `/change query`

N/A — vista estable.

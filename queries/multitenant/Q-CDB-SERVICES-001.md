---
query_id: Q-CDB-SERVICES-001
version: 1.0.0

domain: multitenant
purpose: Servicios por PDB — nombre, CON_ID, instancias activas, CLB/RLB goal, para correlacionar placement de servicio con la PDB correcta

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: CDB_ROOT_ONLY
database_role_scope: ANY

objects_accessed: [GV$SERVICES, GV$ACTIVE_SERVICES]
privileges_required: [SELECT on GV$SERVICES, SELECT on GV$ACTIVE_SERVICES]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 200
max_output_bytes: 32768

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_pdb_services.sh, tests/test_multitenant_container_scope.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT s.con_id,
       s.name          AS service_name,
       s.clb_goal,
       s.goal          AS rlb_goal,
       a.inst_id       AS active_instance
FROM   gv$services s
LEFT   JOIN gv$active_services a
       ON  a.name = s.name AND a.inst_id = s.inst_id AND a.con_id = s.con_id
WHERE  s.con_id > 1
ORDER  BY s.con_id, s.name, a.inst_id;
```

Mismo patrón certificado que `Q-RAC-SERVICES-001` (Fase 4) — extendido con `con_id` (columna real de `GV$SERVICES`/`GV$ACTIVE_SERVICES` desde 12.1, ambas multitenant-aware) para atribuir cada servicio a su PDB. `WHERE s.con_id > 1` excluye servicios internos de CDB$ROOT (`con_id=1`) fuera de alcance de este análisis por PDB.

# Notes by version

`GV$SERVICES`/`GV$ACTIVE_SERVICES` con columna `con_id` desde 12.1 (multitenant). Columnas base (`name`/`clb_goal`/`goal`/`inst_id`) ya certificadas en `Q-RAC-SERVICES-001` desde 11gR2 — aquí sólo se certifican para el rango CDB (12.1+).

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`CDB_ROOT_ONLY` — se ejecuta desde CDB$ROOT para ver servicios de todas las PDBs de una vez (`GV$` ya es CDB-aware). `database_role_scope: ANY`.

# Cost classification rationale

`LOW` — acotado al número de servicios configurados × instancias, típicamente decenas.

# License notes

Ninguna.

# Sanitization notes

`service_name` → MASK por defecto (puede revelar nombre de aplicación/cliente).

# Evolution via `/change query`

Si se requiere `network_registration`/estado de registro real en listener, correlacionar con `oracle-network-analyst` (`# 14`, `# 36` del prompt) en vez de duplicar aquí.

---
query_id: Q-CDB-CONTAINERS-001
version: 1.0.0

domain: multitenant
purpose: Topología completa de contenedores (CDB$ROOT + todas las PDBs) — visión general, distinta del inventario detallado de PDBs

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: CDB_ROOT_ONLY
database_role_scope: ANY

objects_accessed: [V$CONTAINERS]
privileges_required: [SELECT on V$CONTAINERS]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 200
max_output_bytes: 32768

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_multitenant_container_scope.sh, tests/test_multitenant_query_version_compatibility.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT con_id, name, open_mode
FROM   v$containers
ORDER  BY con_id;
```

`V$CONTAINERS` incluye CDB$ROOT (`con_id=1`) además de todas las PDBs — a diferencia de `Q-CDB-PDB-STATE-001` (`V$PDBS`, sólo PDBs de usuario, `con_id > 1`), esta query da la topología completa del CDB de un vistazo, incluyendo el estado del propio root. Deliberadamente acotada a `con_id`/`name`/`open_mode` — `V$CONTAINERS` comparte la mayoría de sus columnas con `V$PDBS` (incl. `application_root`/`proxy_pdb`/`local_undo`), pero el detalle completo de PDB ya lo cubre `Q-CDB-PDB-STATE-001`; duplicarlo aquí violaría "no duplicar skills existentes" (`# 4` del prompt).

# Notes by version

`V$CONTAINERS` disponible desde 12.1 — columnas usadas aquí (`con_id`/`name`/`open_mode`) estables en todo el rango 12.1–23ai, sin necesidad de variantes.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`CDB_ROOT_ONLY` — se ejecuta desde CDB$ROOT para ver la topología completa. `database_role_scope: ANY`.

# Cost classification rationale

`LOW` — una fila por contenedor (root + PDBs), típicamente decenas.

# License notes

Ninguna.

# Sanitization notes

`name` → MASK por defecto (tokenizado — `CDB_ROOT` para con_id=1, `PDB_NNN` para el resto, consistente con `Q-CDB-PDB-STATE-001`).

# Evolution via `/change query`

Si un análisis futuro requiere `member_cdb` (CDB Fleet awareness) u otras columnas de `V$CONTAINERS`, ampliar vía `/change query` con necesidad diagnóstica real — no agregar "por si acaso".

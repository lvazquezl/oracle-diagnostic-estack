---
query_id: Q-CDB-PDB-STATE-001
version: 1.0.0

domain: multitenant
purpose: Inventario y estado de cada PDB — open mode, restricted, tamaño, recovery status, y (12.2+) Application Containers/Proxy PDB/Local Undo awareness

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: CDB_ROOT_ONLY
database_role_scope: ANY

objects_accessed: [V$PDBS]
privileges_required: [SELECT on V$PDBS]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 200
max_output_bytes: 65536

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

# Corrige el gap pre-existente detectado en Fase 6: Q-CDB-PDB-STATE-001 figuraba "materializada" en
# queries/REGISTRY.md desde Foundation sin archivo real (mismo patrón que RAC/ASM en Fase 4 y
# Data Guard en Fase 5). V$PDBS.APPLICATION_ROOT/APPLICATION_PDB/APPLICATION_SEED/PROXY_PDB/
# LOCAL_UNDO fueron introducidas en 12.2 — Application Containers y Local Undo NO existen en 12.1
# (# 5, # 19 del prompt de Fase 6) — verificado contra Oracle Database Reference antes de declarar
# metadata (no repetir el defecto circular de Fase 5 Compatibility Hardening).
variants:
  - variant_id: Q-CDB-PDB-STATE-001-V1
    label: legacy_121
    oracle_versions: {min: "12.1", max: "12.1"}
    container_scope: CDB_ROOT_ONLY
    sql_block: "Variant V1 (legacy_121, 12.1 only)"
  - variant_id: Q-CDB-PDB-STATE-001-V2
    label: modern_122plus
    oracle_versions: {min: "12.2", max: "23.0"}
    container_scope: CDB_ROOT_ONLY
    sql_block: "Variant V2 (modern_122plus, 12.2+)"

tests: [tests/test_no_write_operations.sh, tests/test_pdb_inventory.sh, tests/test_pdb_state.sh, tests/test_multitenant_container_scope.sh, tests/test_multitenant_query_version_compatibility.sh, tests/test_multitenant_query_cost.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_121, 12.1 only)

```sql
SELECT con_id, name, open_mode, restricted, open_time, total_size, recovery_status
FROM   v$pdbs
WHERE  con_id > 1
ORDER  BY con_id;
```

Application Containers/Proxy PDB/Local Undo no existen en 12.1 — no se seleccionan `application_root`/`application_pdb`/`application_seed`/`proxy_pdb`/`local_undo` en esta variante (bug real evitado deliberadamente, no un olvido).

# Statement / procedure (read-only) — Variant V2 (modern_122plus, 12.2+)

```sql
SELECT con_id, name, open_mode, restricted, open_time, total_size, recovery_status,
       application_root, application_pdb, application_seed, proxy_pdb, local_undo
FROM   v$pdbs
WHERE  con_id > 1
ORDER  BY con_id;
```

`local_undo`: `1` = local undo habilitado, `0` = shared undo (`# 19`, `# 20` del prompt) — nunca inferido, siempre leído directamente. `application_root`/`application_pdb`/`application_seed`/`proxy_pdb` alimentan `multitenant/application-containers` y `multitenant/proxy-pdb` sin necesidad de una query separada.

`WHERE con_id > 1` excluye CDB$ROOT (con_id=1) y el seed de CDB (con_id=2 normalmente ya excluido si aplica) — esta query es específicamente inventario de PDBs de usuario; el estado de CDB$ROOT se cubre en `Q-CDB-CONTAINERS-001`.

# Notes by version

`V$PDBS` disponible desde 12.1. Columnas verificadas contra Oracle Database Reference 19c (`compatibility/oracle-dictionary/views.yaml#v$pdbs`) — `application_root`/`application_pdb`/`application_seed`/`proxy_pdb`/`local_undo` exclusivas de V2 (12.2+).

# Notes by platform

Ninguna — SQL puro en ambas variantes.

# Container / role scope notes

`CDB_ROOT_ONLY` en ambas variantes — se ejecuta desde CDB$ROOT para ver todas las PDBs; ejecutarla desde dentro de una PDB sólo devolvería esa PDB (`# 9` del prompt: nunca asumir que `CON_ID` habilita ejecución desde cualquier contenedor). `database_role_scope: ANY`.

# Cost classification rationale

`LOW` — una fila por PDB, típicamente decenas, no miles.

# License notes

Ninguna — metadata core de contenedor. Multi-PDB más allá del límite de edición es `LICENSE_DEPENDENT`, señalado por el skill, no por esta query.

# Sanitization notes

`name` → MASK por defecto (puede revelar nombre de cliente/aplicación, tokenizado como `PDB_NNN`).

# Evolution via `/change query`

Nueva major Oracle: verificar si `V$PDBS` agrega columnas antes de asumir compatibilidad — `/change compatibility`.

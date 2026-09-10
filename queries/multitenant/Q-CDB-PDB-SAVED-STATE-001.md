---
query_id: Q-CDB-PDB-SAVED-STATE-001
version: 2.0.0

domain: multitenant
purpose: Visibilidad de PDB save state (qué PDBs quedarían abiertas automáticamente tras un restart de CDB) — nunca ejecuta SAVE STATE/DISCARD STATE

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: CDB_ROOT_ONLY
database_role_scope: ANY

objects_accessed: [DBA_PDB_SAVED_STATES]
privileges_required: [SELECT on DBA_PDB_SAVED_STATES]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 200
max_output_bytes: 32768

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING: corrige un defecto real de
# la construcción base de Fase 6 — CDB_PDB_SAVED_STATES no es una vista Oracle real (verificado:
# WebFetch a docs.oracle.com/en/database/oracle/oracle-database/19/refrn/CDB_PDB_SAVED_STATES.html
# devuelve HTTP 404). La vista real es DBA_PDB_SAVED_STATES. Además, la feature (no sólo la vista)
# requiere patch level 12.1.0.2 — no existe en 12.1.0.0/12.1.0.1 (# 4-7 del prompt de hardening).
variants:
  - variant_id: Q-CDB-PDB-SAVED-STATE-001-V1
    label: pdb_saved_state_1210x2plus
    oracle_versions: {min: "12.1.0.2", max: "23.0"}
    container_scope: CDB_ROOT_ONLY
    sql_block: "Variant V1 (pdb_saved_state_1210x2plus, 12.1.0.2+)"

tests: [tests/test_no_write_operations.sh, tests/test_no_save_state_execution.sh, tests/test_multitenant_container_scope.sh, tests/test_pdb_saved_state_uses_dba_view.sh, tests/test_cdb_pdb_saved_states_not_certified.sh, tests/test_pdb_saved_state_12101_not_supported.sh, tests/test_pdb_saved_state_12102_supported.sh, tests/test_pdb_saved_state_columns_valid.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (pdb_saved_state_1210x2plus, 12.1.0.2+)

```sql
SELECT con_id, con_name, instance_name, state, restricted
FROM   dba_pdb_saved_states
ORDER  BY con_id, instance_name;
```

Sólo visibilidad (`# 12` del prompt de Fase 6 base) — el estado sólo se registra si el save state se hizo con la PDB en `READ ONLY`/`READ WRITE` (`ALTER PLUGGABLE DATABASE ... SAVE STATE` en modo `MOUNTED` no registra nada, comportamiento documentado de Oracle, no un bug de esta query). Ausencia de fila para una PDB no implica error — implica que no tiene estado guardado, se abrirá según el comportamiento por defecto del CDB tras el restart. Un target 12.1.0.0/12.1.0.1 no tiene variante compatible — el Query Variant Resolver devuelve `status: UNSUPPORTED` (feature de patch level, no ausencia genérica de versión).

# Notes by version

`DBA_PDB_SAVED_STATES` (7 columnas: `CON_ID`, `CON_NAME`, `INSTANCE_NAME`, `CON_UID`, `GUID`, `STATE`, `RESTRICTED` — verificadas contra Oracle Database Reference 19c) disponible desde **12.1.0.2** (PDB Saved State introducido en ese patch level, no en 12.1.0.0/12.1.0.1). Minimum certified version: `12.1.0.2`. Boundary enforcement: el Query Variant Resolver compartido (`scripts/lib/version.sh`, patch-level-aware — `normalize_oracle_version`/`compare_oracle_versions`/`version_in_range`) — ningún test local reimplementa esta comparación (PHASE 6 — VERSION RESOLVER CONSOLIDATION FINALIZATION, ver `docs/PHASE_6_FINAL_PDB_IDENTITY_PATCH_RESOLVER_HARDENING.md`). `instance_name` relevante en RAC — en Standalone reporta una sola instancia. `CDB_PDB_SAVED_STATES` (nombre usado en la construcción base de Fase 6) **no es una vista Oracle real** — corregido en el hardening de compatibilidad.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`CDB_ROOT_ONLY`. `database_role_scope: ANY`.

# Cost classification rationale

`LOW` — típicamente 0 a decenas de filas (una por PDB con estado guardado, por instancia en RAC).

# License notes

Ninguna.

# Sanitization notes

`con_name` → MASK por defecto, mismo tokenizado que `Q-CDB-PDB-STATE-001`.

# Evolution via `/change query`

N/A — vista estable.

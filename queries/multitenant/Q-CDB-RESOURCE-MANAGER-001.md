---
query_id: Q-CDB-RESOURCE-MANAGER-001
version: 1.0.0

domain: multitenant
purpose: Visibilidad de CDB Resource Plan y directivas por PDB (shares, utilization limit, parallel server limit) — sólo lectura, nunca modifica Resource Manager

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: CDB_ROOT_ONLY
database_role_scope: ANY

objects_accessed: [DBA_CDB_RSRC_PLAN_DIRECTIVES]
privileges_required: [SELECT on DBA_CDB_RSRC_PLAN_DIRECTIVES]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 200
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

# El nombre real de esta vista es DBA_CDB_RSRC_PLAN_DIRECTIVES, no "CDB_RSRC_PLAN_DIRECTIVES" como
# aparece en el ejemplo conceptual del prompt de Fase 6 (# 8) — verificado contra Oracle Database
# Reference antes de declarar metadata (no repetir el defecto circular de metadata-sin-fuente-
# documental encontrado y corregido en PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY
# HARDENING). DBA_RSRC_PLAN_DIRECTIVES (sin CDB) es la vista legacy de consumer groups
# intra-instancia — un objeto distinto, fuera de alcance aquí.
tests: [tests/test_no_write_operations.sh, tests/test_pdb_resource_manager_visibility.sh, tests/test_no_resource_plan_change.sh, tests/test_no_resource_limit_change.sh, tests/test_multitenant_container_scope.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT plan, pluggable_database, shares, utilization_limit, parallel_server_limit
FROM   dba_cdb_rsrc_plan_directives
ORDER  BY plan, pluggable_database;
```

`DBA_CDB_RSRC_PLAN_DIRECTIVES` es la vista real para directivas CDB→PDB (share de recursos entre PDBs) — distinta de `DBA_RSRC_PLAN_DIRECTIVES` (legacy, consumer groups dentro de una instancia). Sólo visibilidad — nunca `ALTER SYSTEM SET RESOURCE_MANAGER_PLAN` ni cambios de pending area (`# 31` del prompt).

# Notes by version

`DBA_CDB_RSRC_PLAN_DIRECTIVES` disponible desde 12.1 (Resource Manager para PDBs).

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`CDB_ROOT_ONLY` — el CDB Resource Plan sólo es visible/administrable desde CDB$ROOT. `database_role_scope: ANY`.

# Cost classification rationale

`LOW` — número de directivas acotado al número de PDBs × planes definidos, típicamente pequeño.

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP (nombres de plan/PDB no contienen datos de aplicación; `pluggable_database` sigue la política de tokenización del skill consumidor).

# Evolution via `/change query`

N/A — vista estable.

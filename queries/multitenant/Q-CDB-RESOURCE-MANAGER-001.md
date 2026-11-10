---
query_id: Q-CDB-RESOURCE-MANAGER-001
version: 2.0.0

domain: multitenant
purpose: CDB Resource Plans y directivas por PDB (shares, utilization limit, parallel server limit), con el plan activo marcado — sólo lectura, nunca modifica Resource Manager

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: CDB_ROOT_ONLY
database_role_scope: ANY

objects_accessed: [DBA_CDB_RSRC_PLAN_DIRECTIVES, V$RSRC_PLAN]
privileges_required: [SELECT on DBA_CDB_RSRC_PLAN_DIRECTIVES, SELECT on V$RSRC_PLAN]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 200
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-CDB-RESOURCE-MANAGER-001-V1
    label: cdb_plans_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: CDB_ROOT_ONLY
    sql_block: "Variant V1 (cdb_plans_12plus, 12.1–23.0: DBA_CDB_RSRC_PLAN_DIRECTIVES)"

tests: [tests/test_no_write_operations.sh, tests/test_pdb_resource_manager_visibility.sh, tests/test_no_resource_plan_change.sh, tests/test_no_resource_limit_change.sh, tests/test_multitenant_container_scope.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (cdb_plans_12plus, 12.1–23.0: DBA_CDB_RSRC_PLAN_DIRECTIVES)

```sql
SELECT CASE WHEN d.plan IN ('DEFAULT_CDB_PLAN', 'DEFAULT_MAINTENANCE_PLAN', 'ORA$INTERNAL_CDB_PLAN', 'ORA$QOS_CDB_PLAN')
            THEN 'ORACLE' ELSE 'CUSTOM' END AS plan_kind,
       d.plan AS plan_name,
       CASE WHEN d.plan IN (SELECT p.name FROM v$rsrc_plan p WHERE p.con_id IN (0, 1) AND p.is_top_plan = 'TRUE')
            THEN 'YES' ELSE 'NO' END AS plan_active,
       CASE WHEN d.pluggable_database = 'ORA$DEFAULT_PDB_DIRECTIVE' THEN 'DEFAULT_PDB'
            WHEN d.pluggable_database = 'ORA$AUTOTASK' THEN 'AUTOTASK'
            WHEN d.pluggable_database IS NULL THEN 'OTHER' ELSE 'PDB' END AS directive_kind,
       CASE WHEN d.pluggable_database LIKE 'ORA$%' THEN NULL ELSE d.pluggable_database END AS pdb_name,
       d.shares, d.utilization_limit, d.parallel_server_limit
FROM   dba_cdb_rsrc_plan_directives d
ORDER  BY d.plan, d.pluggable_database;
```

# Notes by version

`DBA_CDB_RSRC_PLAN_DIRECTIVES` y `V$RSRC_PLAN.CON_ID` desde 12.1. Las directivas por perfil de PDB (12.2+) salen como `directive_kind` `OTHER`.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`CDB_ROOT_ONLY`. En RAC, `plan_active` refleja la instancia consultada.

# Cost classification rationale

`LOW` — vistas pequeñas de metadata.

# License notes

Ninguna.

# Sanitization notes

Los nombres de plan y de PDB se enmascaran; `plan_kind` conserva si el plan es de Oracle y `directive_kind` si la directiva es la de PDB por defecto, la de autotask o una PDB concreta. `COMMENTS` nunca se selecciona.

# Evolution via `/change query`

2.0.0 CHG-ESTACK-B8-OPS-COVERAGE-001: plan activo, tipo de plan y de directiva; nombres enmascarados.

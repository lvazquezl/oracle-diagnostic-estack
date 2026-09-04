---
query_id: Q-RAC-TOPOLOGY-001
version: 1.0.0

domain: rac
purpose: Topología de instancias RAC — enumeración vía GV$INSTANCE cruzada con V$ACTIVE_INSTANCES

supported_oracle_versions: [11gR2, 12c, 18c, 19c, 21c, 23ai]
supported_os: [Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server]
supported_architectures: [RAC, RAC One Node]

container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [GV$INSTANCE, V$ACTIVE_INSTANCES]
privileges_required: [SELECT on GV$INSTANCE, SELECT on V$ACTIVE_INSTANCES]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 50
max_output_bytes: 16384

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-RAC-TOPOLOGY-001-V1
    label: pre_multitenant
    oracle_versions: {min: "11.2", max: "11.2"}
    container_scope: NOT_APPLICABLE
    sql_block: "Variant V1 (pre_multitenant, 11.2)"
  - variant_id: Q-RAC-TOPOLOGY-001-V2
    label: multitenant_aware
    oracle_versions: {min: "12.1", max: latest}
    container_scope: NOT_APPLICABLE
    sql_block: "Variant V2 (multitenant_aware, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_rac_topology.sh, tests/test_every_logical_query_has_variant.sh, tests/test_no_variant_references_unknown_column.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (pre_multitenant, 11.2)

```sql
SELECT i.instance_number, i.instance_name, i.host_name, i.status,
       a.inst_number, a.inst_name
FROM   gv$instance i
JOIN   v$active_instances a ON a.inst_number = i.instance_number
ORDER  BY i.instance_number;
```

# Statement / procedure (read-only) — Variant V2 (multitenant_aware, 12.1+)

```sql
SELECT i.instance_number, i.instance_name, i.host_name, i.status,
       a.inst_number, a.inst_name, a.con_id
FROM   gv$instance i
JOIN   v$active_instances a ON a.inst_number = i.instance_number
ORDER  BY i.instance_number;
```

Sin `con_id` en V1 — Multitenant no existe en 11gR2 (misma razón que `Q-DISC-RAC-001`).

# Notes by version

`V$ACTIVE_INSTANCES`/`GV$INSTANCE` estables en ambas variantes desde 11gR2. No certificado para CRS 10g legacy — `oracle-rac-analyst` reporta `PARTIALLY_SUPPORTED` en esa familia.

# Notes by platform

Ninguna — SQL puro sobre `GV$`/`V$`.

# Container / role scope notes

`NOT_APPLICABLE` en ambas variantes — topología de cluster es independiente de tenancy.

# Cost classification rationale

`LOW` — acotado al número de instancias del cluster.

# License notes

Ninguna.

# Sanitization notes

`instance_name`/`host_name` → MASK por defecto.

# Evolution via `/change query`

Si una versión futura requiere un tercer concepto, evaluar V3 vía `/change compatibility`.

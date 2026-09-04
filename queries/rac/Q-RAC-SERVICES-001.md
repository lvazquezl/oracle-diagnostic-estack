---
query_id: Q-RAC-SERVICES-001
version: 1.0.0

domain: rac
purpose: Servicios de base de datos, su configuración de balanceo (CLB/RLB goal) y placement actual vs. activo

supported_oracle_versions: [11gR2, 12c, 18c, 19c, 21c, 23ai]
supported_os: [Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server]
supported_architectures: [RAC, RAC One Node]

container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [GV$SERVICES, GV$ACTIVE_SERVICES]
privileges_required: [SELECT on GV$SERVICES, SELECT on GV$ACTIVE_SERVICES]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 200
max_output_bytes: 65536

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-RAC-SERVICES-001-V1
    label: active_services_aware
    oracle_versions: {min: "11.2", max: latest}
    container_scope: NOT_APPLICABLE
    sql_block: "Variant V1 (active_services_aware, 11.2+)"

tests: [tests/test_no_write_operations.sh, tests/test_rac_services.sh, tests/test_every_logical_query_has_variant.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (active_services_aware, 11.2+)

```sql
SELECT s.name AS service_name,
       s.clb_goal,
       s.goal AS rlb_goal,
       a.inst_id AS active_instance
FROM   gv$services s
LEFT   JOIN gv$active_services a
       ON  a.name = s.name AND a.inst_id = s.inst_id
ORDER  BY s.name, a.inst_id;
```

10g/11gR1 (RAC pre-11gR2) no tiene variante declarada — no certificado en este catálogo, mismo criterio que `Q-RAC-TOPOLOGY-001`/`Q-DISC-RAC-001` (`oracle-rac-analyst` reporta `PARTIALLY_SUPPORTED` para esa familia, nunca inventa un SQL sin `GV$ACTIVE_SERVICES` sólo para rellenar el rango).

# Notes by version

`GV$ACTIVE_SERVICES` estable desde 11gR2 — distingue configurado (`GV$SERVICES`) de activo (`GV$ACTIVE_SERVICES`), base del modelo `configured placement` vs. `actual placement` (`# 15` del prompt de Fase 4).

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`NOT_APPLICABLE` — configuración de servicio es independiente de tenancy.

# Cost classification rationale

`LOW` — acotado al número de servicios configurados.

# License notes

Ninguna.

# Sanitization notes

`service_name` → MASK por defecto (puede revelar nombre de aplicación/cliente).

# Evolution via `/change query`

Ampliar con metadata TAF/Application Continuity vía `/change query` cuando esté certificada.

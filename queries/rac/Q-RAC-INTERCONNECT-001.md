---
query_id: Q-RAC-INTERCONNECT-001
version: 1.0.0

domain: rac
purpose: Interfaces de interconnect privado activas por instancia

supported_oracle_versions: [11gR2, 12c, 18c, 19c, 21c, 23ai]
supported_os: [Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server]
supported_architectures: [RAC]

container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [GV$CLUSTER_INTERCONNECTS]
privileges_required: [SELECT on GV$CLUSTER_INTERCONNECTS]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 50
max_output_bytes: 16384

sensitivity: HIGH
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_rac_interconnect.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT inst_id, name, ip_address, is_public, source
FROM   gv$cluster_interconnects
ORDER  BY inst_id;
```

# Notes by version

`GV$CLUSTER_INTERCONNECTS` estable desde 11gR2 (RAC pre-11gR2 fuera de soporte de este catálogo).

# Notes by platform

Ninguna — SQL puro. Metadata de interfaz OS complementaria (bonding/VLAN) se obtiene vía `rac/gi-network-interfaces`/`network/interconnect`, no por esta query.

# Container / role scope notes

`NOT_APPLICABLE` — el interconnect es una propiedad de instancia, no de contenedor.

# Cost classification rationale

`LOW` — acotado al número de instancias.

# License notes

Ninguna.

# Sanitization notes

`ip_address`/`name` → MASK por defecto (siempre, sensibilidad `HIGH`).

# Evolution via `/change query`

Redes ASM/backup dedicadas adicionales, si la arquitectura las expone en una vista futura, vía `/change compatibility`.

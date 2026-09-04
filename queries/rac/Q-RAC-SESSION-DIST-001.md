---
query_id: Q-RAC-SESSION-DIST-001
version: 2.0.0

domain: rac
purpose: Distribución de sesiones activas por instancia y servicio

supported_oracle_versions: [11gR2, 12c, 18c, 19c, 21c, 23ai]
supported_os: [Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server]
supported_architectures: [RAC, RAC One Node]

container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [GV$SESSION, GV$SERVICES]
privileges_required: [SELECT on GV$SESSION, SELECT on GV$SERVICES]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 30
max_rows: 5000
max_output_bytes: 1048576

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_rac_standalone_detection.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_contract_requires_license_metadata.sh, tests/test_query_cost_medium.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT s.inst_id,
       s.service_name,
       COUNT(*) AS session_count
FROM   gv$session s
WHERE  s.type = 'USER'
  AND  s.status = 'ACTIVE'
GROUP  BY s.inst_id, s.service_name
ORDER  BY s.service_name, s.inst_id;
```

Nunca selecciona `s.sql_id`, `s.program` con detalle de aplicación más allá de lo necesario para el conteo, ni ninguna columna de `s.module`/`s.action` con contenido potencialmente sensible sin pasar antes por sanitización.

# Notes by version

Estable desde 11gR2. En 10g/11gR1 (RAC pre-11gR2) esta query no está certificada — `oracle-rac-analyst` lo declara `UNDETERMINED` para esas versiones.

# Notes by platform

Ninguna diferencia — es SQL puro sobre `GV$`, independiente del OS.

# Sanitization notes

`service_name` → MASK por defecto (puede revelar nombre de aplicación/cliente); `inst_id`/`session_count` → KEEP.

# Evolution via `/change query`

Ampliar a incluir `wait_class` de la sesión (para cruce con `performance/wait-events`) vía `/change query` — evaluado, no incluido en Fase 1 para mantener la query acotada y de bajo costo.

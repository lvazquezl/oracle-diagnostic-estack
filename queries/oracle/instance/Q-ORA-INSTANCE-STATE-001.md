---
query_id: Q-ORA-INSTANCE-STATE-001
version: 2.0.0
domain: oracle
purpose: Estado operativo de instancia(s) — status, startup_time, shutdown_pending

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [GV$INSTANCE]
privileges_required: [SELECT on GV$INSTANCE]

risk_class: R0
cost_class: LOW
timeout_seconds: 10
max_rows: 50
max_output_bytes: 16384

sensitivity: LOW
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

# Oracle Core Compatibility Hardening: bug VARIANT_REQUIRED corregido — la sentencia única
# original leía instance_role (11g+) sin guardia mientras declaraba soporte desde 10g.
variants:
  - variant_id: Q-ORA-INSTANCE-STATE-001-V1
    label: legacy_10g
    oracle_versions: {min: "10.2", max: "10.2"}
    container_scope: NOT_APPLICABLE
    sql_block: "Variant V1 (legacy_10g, 10.2)"
  - variant_id: Q-ORA-INSTANCE-STATE-001-V2
    label: modern_11plus
    oracle_versions: {min: "11.0", max: latest}
    container_scope: NOT_APPLICABLE
    sql_block: "Variant V2 (modern_11plus, 11.0+)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_every_logical_query_has_variant.sh, tests/test_no_variant_references_unknown_column.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g, 10.2)

```sql
SELECT inst_id, status, database_status, active_state, shutdown_pending, startup_time
FROM   gv$instance
ORDER  BY inst_id;
```

Sin `instance_role` — no disponible en `GV$INSTANCE` en 10g (columna introducida en 11g para awareness de standby en RAC).

# Statement / procedure (read-only) — Variant V2 (modern_11plus, 11.0+)

```sql
SELECT inst_id, status, database_status, active_state, shutdown_pending, startup_time, instance_role
FROM   gv$instance
ORDER  BY inst_id;
```

Sobre un target standalone, `gv$instance` devuelve una sola fila en ambas variantes — la misma query sirve para single/RAC, evitando duplicar una versión "single" y otra "RAC" (la distinción real que sí importa es por versión, no por arquitectura).

# Notes by version

`INSTANCE_ROLE` (`PRIMARY_INSTANCE`/`STANDBY_INSTANCE`) sólo existe desde 11g → exclusivo de V2. El resto de columnas (`STATUS`, `DATABASE_STATUS`, `ACTIVE_STATE`, `SHUTDOWN_PENDING`, `STARTUP_TIME`) estables desde 10g en ambas variantes. Ver `compatibility/oracle-dictionary/views.yaml#v$instance`.

# Notes by platform

Ninguna diferencia en ninguna variante.

# Container / role scope notes

Estado de instancia es independiente de tenancy en ambas variantes — `NOT_APPLICABLE`.

# Cost classification rationale

`LOW` en ambas variantes: acotado al número de instancias.

# License notes

Ninguna en ninguna variante.

# Sanitization notes

Todos los campos → KEEP en ambas variantes.

# Evolution via `/change query`

Sin cambios estructurales esperados para versiones futuras salvo que Oracle deprecara `INSTANCE_ROLE` (improbable) — cualquier cambio sigue `/change compatibility`.

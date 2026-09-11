---
query_id: Q-RMAN-BACKUP-DEVICE-001
version: 1.0.0

domain: rman
purpose: Dispositivos/canales actualmente asignados (device type, estado) — visibilidad, nunca ALLOCATE/RELEASE CHANNEL

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [V$BACKUP_DEVICE]
privileges_required: [SELECT on V$BACKUP_DEVICE]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 100
max_output_bytes: 32768

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-RMAN-BACKUP-DEVICE-001-V1
    label: all_versions
    oracle_versions: {min: "10.2", max: "23.0"}
    container_scope: NOT_APPLICABLE
    sql_block: "Variant V1 (all_versions, 10g-23ai)"

tests: [tests/test_no_write_operations.sh, tests/test_no_channel_allocate_execution.sh, tests/test_channel_inventory.sh, tests/test_rman_query_version_compatibility.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (all_versions, 10g-23ai)

```sql
SELECT device_type, device_name, physical_device_name
FROM   v$backup_device;
```

Refleja únicamente dispositivos actualmente asignados durante un job en ejecución — vacía si no hay backup/restore corriendo en ese momento (comportamiento documentado, no error). Sólo lectura — nunca `ALLOCATE CHANNEL`/`RELEASE CHANNEL`.

# Notes by version

Vista pre-10g, certificada 10g-23ai sin variante adicional. Configuración persistente de canales (no sólo los activos en este momento) se evalúa vía `Q-RMAN-CONFIGURATION-001` (`CHANNEL ... DEVICE TYPE ...`).

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`NOT_APPLICABLE` — canales no tienen concepto de contenedor propio.

# Cost classification rationale

`LOW` — a lo sumo un puñado de filas (canales concurrentes activos).

# License notes

Ninguna.

# Sanitization notes

`DEVICE_NAME`/`PHYSICAL_DEVICE_NAME` → MASK (puede revelar convención de nombre de dispositivo SBT/media manager).

# Evolution via `/change query`

N/A — vista estable.

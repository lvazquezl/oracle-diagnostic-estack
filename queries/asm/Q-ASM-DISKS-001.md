---
query_id: Q-ASM-DISKS-001
version: 2.0.0

domain: asm
purpose: Salud de discos ASM por disk group y failure group: discos, capacidad, no miembros, fuera de línea, en estado anormal y errores de lectura/escritura — sin discovery, nunca el listado de discos

supported_oracle_versions: [11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC, RAC One Node]

container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [V$ASM_DISK_STAT]
privileges_required: [SELECT on V$ASM_DISK_STAT]

risk_class: R0
cost_class: LOW

timeout_seconds: 30
max_rows: 200
max_output_bytes: 16384

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-ASM-DISKS-001-V1
    label: all_versions
    oracle_versions: {min: "11.2", max: "23.0"}
    container_scope: NOT_APPLICABLE
    sql_block: "Variant V1 (all_versions, 11.2–23.0: V$ASM_DISK_STAT agregado por failure group)"

tests: [tests/test_no_write_operations.sh, tests/test_asm_disk_health.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (all_versions, 11.2–23.0: V$ASM_DISK_STAT agregado por failure group)

```sql
SELECT group_number AS diskgroup_number,
       failgroup,
       COUNT(*) AS disks,
       SUM(total_mb) AS total_mb,
       SUM(CASE WHEN group_number > 0 AND header_status <> 'MEMBER' THEN 1 ELSE 0 END) AS disks_not_member,
       SUM(CASE WHEN mode_status <> 'ONLINE' THEN 1 ELSE 0 END) AS disks_not_online,
       SUM(CASE WHEN state <> 'NORMAL' THEN 1 ELSE 0 END) AS disks_not_normal,
       SUM(read_errs) AS read_errors,
       SUM(write_errs) AS write_errors
FROM   v$asm_disk_stat
GROUP  BY group_number, failgroup
ORDER  BY group_number, failgroup;
```

# Notes by version

`V$ASM_DISK_STAT` existe desde 10.2; el catálogo certifica ASM desde 11.2.

# Notes by platform

Igual en todas las plataformas con ASM. Sin ASM, 0 filas.

# Container / role scope notes

`NOT_APPLICABLE`: ASM no es por contenedor. Desde una instancia de base de datos se ven los discos de los disk groups que usa.

# Cost classification rationale

`LOW` — `V$ASM_DISK_STAT` no dispara discovery de discos (a diferencia de `V$ASM_DISK`, que era el motivo del costo `MEDIUM`).

# License notes

Ninguna.

# Sanitization notes

PATH: antes tokenizado, desde 2.0.0 nunca se selecciona; tampoco `NAME`. `FAILGROUP` se enmascara (alias estable en la sesión) para que `asm/failure-groups` compare la cantidad de discos y la capacidad entre failure groups. Solo conteos y MB por número de disk group y failure group (el grupo 0 son discos candidatos o sin grupo, donde `HEADER_STATUS` distinto de `MEMBER` es normal).

# Evolution via `/change query`

2.0.0 CHG-ESTACK-B8-OPS-COVERAGE-001: de la lista de discos anómalos a conteos y capacidad por disk group y failure group (enmascarado) sobre `V$ASM_DISK_STAT`; rutas y nombres de disco fuera.

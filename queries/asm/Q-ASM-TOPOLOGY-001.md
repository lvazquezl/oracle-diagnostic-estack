---
query_id: Q-ASM-TOPOLOGY-001
version: 2.0.0

domain: asm
purpose: Topología ASM — instancias y disk groups montados, capacidad vía V$ASM_DISKGROUP_STAT (sin disco discovery)

supported_oracle_versions: [11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server]
supported_architectures: [Standalone, RAC, RAC One Node]

container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [V$ASM_CLIENT, V$ASM_DISKGROUP_STAT]
privileges_required: [SELECT on V$ASM_CLIENT, SELECT on V$ASM_DISKGROUP_STAT]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 100
max_output_bytes: 32768

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_asm_diskgroup_stat_default.sh, tests/test_asm_capacity_usable_file.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT c.instance_name AS asm_instance, c.db_name, c.status, c.software_version,
       g.name AS diskgroup, g.state, g.type,
       g.total_mb, g.free_mb, g.usable_file_mb, g.required_mirror_free_mb
FROM   v$asm_client c
LEFT   JOIN v$asm_diskgroup_stat g ON g.group_number = c.group_number
ORDER  BY c.instance_name, g.name;
```

Usa `V$ASM_DISKGROUP_STAT`, no `V$ASM_DISKGROUP` — no dispara disk discovery, apto para polling rutinario (`# 23` del prompt de Fase 4, hardening heredado de Foundation).

# Notes by version

**2.0.0 (`CHG-ESTACK-ORA19C-LAB-007`, breaking):** `GV$ASM_INSTANCE` no existe (no figura en *Automatic Storage Management Administrator's Guide* 19c ni en la Reference; confirmado en Oracle real por `Q-DICT-VERIFY`, sobre una base que usa ASM). Se reemplaza por `V$ASM_CLIENT`, que desde una instancia de base de datos muestra la instancia ASM que atiende sus archivos abiertos, con una fila por disk group en uso (se une a `V$ASM_DISKGROUP_STAT` por `group_number`, ya no con `ON 1=1`). Alcance: la(s) instancia(s) ASM **de esta base**, no un inventario del clúster.

`V$ASM_CLIENT`/`V$ASM_DISKGROUP_STAT` desde 11gR2 (verificado en la documentación y en Oracle real sólo en 19c). La familia se declara `11g` (canónica, exigida por el catálogo del gateway); el piso real es 11.2 (`config/query-compatibility-matrix.yaml`, min `"11.2"`) — `CHG-ESTACK-LAB-REVALIDATE-007`.

# Notes by platform

Ninguna — SQL puro sobre la instancia ASM.

# Container / role scope notes

`NOT_APPLICABLE` — ASM es infraestructura, no CDB/PDB.

# Cost classification rationale

`LOW` — `V$ASM_DISKGROUP_STAT` es de bajo costo por diseño (a diferencia de `V$ASM_DISKGROUP`).

# License notes

Ninguna.

# Sanitization notes

`diskgroup`/`instance_name` → MASK según política; métricas numéricas → KEEP.

# Evolution via `/change query`

`V$ASM_DISKGROUP` (disk discovery explícito) como query separada de mayor costo, vía `/change query`, cuando un escenario lo requiera explícitamente — nunca sustituye a esta query por defecto.

---
query_id: Q-ASM-TOPOLOGY-001
version: 1.0.0

domain: asm
purpose: Topología ASM — instancias y disk groups montados, capacidad vía V$ASM_DISKGROUP_STAT (sin disco discovery)

supported_oracle_versions: [11gR2, 12c, 18c, 19c, 21c, 23ai]
supported_os: [Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server]
supported_architectures: [Standalone, RAC, RAC One Node]

container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [GV$ASM_INSTANCE, V$ASM_DISKGROUP_STAT]
privileges_required: [SELECT on GV$ASM_INSTANCE, SELECT on V$ASM_DISKGROUP_STAT]

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
SELECT i.inst_id, i.instance_name, i.status,
       g.name AS diskgroup, g.state, g.type,
       g.total_mb, g.free_mb, g.usable_file_mb, g.required_mirror_free_mb
FROM   gv$asm_instance i
LEFT   JOIN v$asm_diskgroup_stat g ON 1=1
ORDER  BY i.inst_id, g.name;
```

Usa `V$ASM_DISKGROUP_STAT`, no `V$ASM_DISKGROUP` — no dispara disk discovery, apto para polling rutinario (`# 23` del prompt de Fase 4, hardening heredado de Foundation).

# Notes by version

`GV$ASM_INSTANCE`/`V$ASM_DISKGROUP_STAT` estables desde 11gR2.

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

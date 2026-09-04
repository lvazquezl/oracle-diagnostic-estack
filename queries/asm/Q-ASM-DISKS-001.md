---
query_id: Q-ASM-DISKS-001
version: 1.0.0

domain: asm
purpose: Salud de discos individuales — sólo discos anómalos (header/mode/errores), nunca el listado completo

supported_oracle_versions: [11gR2, 12c, 18c, 19c, 21c, 23ai]
supported_os: [Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server]
supported_architectures: [Standalone, RAC, RAC One Node]

container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [V$ASM_DISK]
privileges_required: [SELECT on V$ASM_DISK]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 30
max_rows: 500
max_output_bytes: 262144

sensitivity: HIGH
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_asm_disk_health.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_cost_medium.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT group_number, disk_number, name, failgroup,
       mount_status, header_status, mode_status, state,
       path, read_errs, write_errs
FROM   v$asm_disk
WHERE  header_status != 'MEMBER'
    OR read_errs > 0
    OR write_errs > 0
ORDER  BY group_number, disk_number;
```

Filtra en el propio SQL a discos anómalos — `max_rows: 500` es un límite de seguridad, no el comportamiento esperado (un ambiente sano devuelve 0 filas).

# Notes by version

`V$ASM_DISK` estable desde 11gR2 en las columnas usadas.

# Notes by platform

Ninguna — SQL puro. `PATH` refleja la convención de nombres del OS/multipath subyacente, tokenizado por el sanitizer.

# Container / role scope notes

`NOT_APPLICABLE`.

# Cost classification rationale

`MEDIUM` — `V$ASM_DISK` es más costosa que `V$ASM_DISKGROUP_STAT`; el filtro `WHERE` la acota, pero se clasifica de forma conservadora.

# License notes

Ninguna.

# Sanitization notes

`path` → siempre tokenizado (`PATH_TOKEN_NNN`), nunca expuesto completo. `name`/`failgroup` → MASK por defecto.

# Evolution via `/change query`

Umbral de `read_errs`/`write_errs` configurable vía `/change policy` si se requiere un umbral distinto de 0.

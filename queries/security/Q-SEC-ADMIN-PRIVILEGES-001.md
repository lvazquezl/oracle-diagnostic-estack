---
query_id: Q-SEC-ADMIN-PRIVILEGES-001
version: 1.0.0

domain: security
purpose: >
  Identidades con privilegios administrativos (SYSDBA/SYSOPER/SYSASM/SYSBACKUP/SYSDG/SYSKM)
  vía password file — admin privileges awareness, sin leer secrets (# 13 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$PWFILE_USERS]
privileges_required: [SELECT on V$PWFILE_USERS]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 100
max_output_bytes: 65536

sensitivity: HIGH
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-ADMIN-PRIVILEGES-001-V1
    label: legacy_10g
    oracle_versions: {min: "10.2", max: "10.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g)"
  - variant_id: Q-SEC-ADMIN-PRIVILEGES-001-V2
    label: modern_11plus
    oracle_versions: {min: "11.0", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_11plus, sin SYSBACKUP/SYSDG/SYSKM/COMMON)"
  - variant_id: Q-SEC-ADMIN-PRIVILEGES-001-V3
    label: modern_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V3 (modern_12plus, con SYSBACKUP/SYSDG/SYSKM/COMMON)"

tests: [tests/test_no_write_operations.sh, tests/test_security_admin_privileges.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g)

```sql
SELECT username, sysdba, sysoper
FROM   v$pwfile_users
ORDER  BY username;
```

`SYSASM` no existe en 10g — introducido 11gR1 (verificado WebSearch, separación de instance
type ASM).

# Statement / procedure (read-only) — Variant V2 (modern_11plus, sin SYSBACKUP/SYSDG/SYSKM/COMMON)

```sql
SELECT username, sysdba, sysoper, sysasm
FROM   v$pwfile_users
ORDER  BY username;
```

`SYSBACKUP`/`SYSDG`/`SYSKM`/`COMMON` no existen en 11g — introducidos en 12.1 (verificado
WebSearch, "Administrative Privileges and Job Role Separation ... 12c Release 1").

# Statement / procedure (read-only) — Variant V3 (modern_12plus, con SYSBACKUP/SYSDG/SYSKM/COMMON)

```sql
SELECT username, sysdba, sysoper, sysasm, sysbackup, sysdg, syskm, common
FROM   v$pwfile_users
ORDER  BY common DESC, username;
```

# Notes by version

Ver desglose por variante arriba — cada boundary verificado independientemente vía WebSearch
contra fuentes que documentan explícitamente la versión de introducción.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW` — el password file rara vez tiene más de unas pocas docenas de entradas.

# License notes

Ninguna.

# Sanitization notes

`username` → MASK por defecto salvo cuenta Oracle-maintained conocida (`SYS`). Nunca se lee
contenido del password file más allá de esta vista dinámica (sin acceso a filesystem).

# Evolution via `/change query`

N/A.

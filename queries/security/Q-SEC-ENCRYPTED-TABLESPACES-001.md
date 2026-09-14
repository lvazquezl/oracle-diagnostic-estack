---
query_id: Q-SEC-ENCRYPTED-TABLESPACES-001
version: 1.0.0

domain: security
purpose: Tablespaces con TDE tablespace encryption — tablespace-encryption (# 33 del prompt de Fase 8).

supported_oracle_versions: [11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$ENCRYPTED_TABLESPACES, DBA_TABLESPACES]
privileges_required: [SELECT on V$ENCRYPTED_TABLESPACES, SELECT on DBA_TABLESPACES]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 200
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_tablespace_encryption.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT t.tablespace_name,
       CASE WHEN e.ts# IS NOT NULL THEN 'ENCRYPTED' ELSE 'UNENCRYPTED' END AS classification,
       e.encryptionalg
FROM   dba_tablespaces t
LEFT   JOIN v$encrypted_tablespaces e ON e.ts# = (SELECT ts# FROM v$tablespace vt WHERE vt.name = t.tablespace_name)
ORDER  BY t.tablespace_name;
```

`LEFT JOIN` es deliberado — un tablespace sin fila en `V$ENCRYPTED_TABLESPACES` es
`UNENCRYPTED`, nunca `UNKNOWN` por ausencia de join (la ausencia misma es la evidencia).
`UNKNOWN` se reserva para cuando la query completa no puede certificarse (versión no soportada).

# Notes by version

`V$ENCRYPTED_TABLESPACES` verificada disponible desde 11.2 — mismo boundary que
`V$ENCRYPTION_WALLET`. En 10g/11.1, `security/tablespace-encryption` publica
`classification: NOT_APPLICABLE` con `capability_status: UNSUPPORTED`.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW`.

# License notes

Igual que `Q-SEC-TDE-WALLET-001` — Advanced Security Option donde aplique.

# Sanitization notes

`tablespace_name` → KEEP (metadata de configuración, no PII).

# Evolution via `/change query`

N/A.

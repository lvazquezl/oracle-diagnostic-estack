---
query_id: Q-SEC-DATA-REDACTION-POLICIES-001
version: 3.0.0

domain: security
purpose: >
  Presencia/configuración de políticas de Data Redaction (DBMS_REDACT) — data-redaction-awareness,
  licensed bajo Advanced Security Option, distinto de Data Masking and Subsetting (# 41, # 42
  del prompt de Fase 8).

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [REDACTION_POLICIES, REDACTION_COLUMNS]
privileges_required: [SELECT_CATALOG_ROLE]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 200
max_output_bytes: 65536

sensitivity: MEDIUM
sanitization_required: true

license_requirements: "Oracle Data Redaction (DBMS_REDACT) — Advanced Security Option"

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_no_redaction_change.sh, tests/test_data_redaction_awareness.sh, tests/test_security_licensing_gate.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT p.object_owner, p.object_name, p.policy_name, p.enable, c.column_name, c.function_type
FROM   redaction_policies p
LEFT   JOIN redaction_columns c
       ON  c.object_owner = p.object_owner AND c.object_name = p.object_name
ORDER  BY p.object_owner, p.object_name, c.column_name;
```

Una fila por columna redactada de cada política (o una fila por política sin columnas). Requiere `SELECT_CATALOG_ROLE`. Nunca ejecuta `DBMS_REDACT` — sólo lectura de metadata ya configurada. La 2.0.0 tenía dos sentencias en el mismo archivo y por eso nunca se podía resolver una variante única.

# Notes by version

`REDACTION_POLICIES`/`REDACTION_COLUMNS` verificadas disponibles desde 12.1 (WebSearch, `DBMS_
REDACT` introducido 12cR1) — en 10g/11g, `security/data-redaction-awareness` publica
`capability_status: UNSUPPORTED`.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW` — típicamente pocas políticas configuradas.

# License notes

Advanced Security Option (mismo bucket que TDE) — verificado WebSearch, distinto del Data
Masking and Subsetting Pack (`security/data-masking-awareness` nunca asume el mismo
licenciamiento, `# 42` del prompt).

# Sanitization notes

`object_owner`/`object_name`/`column_name` → MASK por defecto (pueden revelar estructura de
esquema de aplicación).

# Evolution via `/change query`

CHG-ESTACK-SEC-QUERIES-001 — 3.0.0: políticas y columnas en una sola sentencia (`LEFT JOIN`); antes eran dos sentencias y la query no resolvía.

N/A.

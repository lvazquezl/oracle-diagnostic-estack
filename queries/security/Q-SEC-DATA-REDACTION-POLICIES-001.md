---
query_id: Q-SEC-DATA-REDACTION-POLICIES-001
version: 1.0.0

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
SELECT object_owner, object_name, policy_name, enable
FROM   redaction_policies
ORDER  BY object_owner, object_name;
```

```sql
SELECT object_owner, object_name, column_name, policy_name, function_type
FROM   redaction_columns
ORDER  BY object_owner, object_name, column_name;
```

Requiere `SELECT_CATALOG_ROLE` (verificado WebSearch). Nunca ejecuta `DBMS_REDACT.ADD_POLICY/
ALTER_POLICY/DROP_POLICY` — sólo lectura de metadata ya configurada.

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

N/A.

---
query_id: Q-SEC-UNIFIED-AUDIT-POLICIES-001
version: 1.0.0

domain: security
purpose: Políticas de Unified Auditing habilitadas — audit configuration/unified-auditing (# 27 del prompt de Fase 8).

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [AUDIT_UNIFIED_ENABLED_POLICIES]
privileges_required: [SELECT on AUDIT_UNIFIED_ENABLED_POLICIES]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 200
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_no_audit_policy_change.sh, tests/test_unified_audit_detection.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT policy_name, entity_name, entity_type, success, failure
FROM   audit_unified_enabled_policies
ORDER  BY policy_name, entity_name;
```

# Notes by version

`AUDIT_UNIFIED_ENABLED_POLICIES` verificada disponible desde 12.1 (WebFetch/WebSearch) — no
existe en 10g/11g. En esas versiones, `security/unified-auditing` publica `capability_status:
UNSUPPORTED`, `security/traditional-auditing` es la vía de auditoría certificada.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW` — poblada sólo cuando Unified Auditing está habilitado, típicamente pocas políticas.

# License notes

Ninguna.

# Sanitization notes

`entity_name` → MASK por defecto salvo usuario Oracle-maintained conocido.

# Evolution via `/change query`

N/A.

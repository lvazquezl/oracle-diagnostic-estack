---
query_id: Q-TEMPLATE
version: 0.0.0

domain: ""
purpose: ""

supported_oracle_versions: []
supported_os: []
supported_architectures: []

container_scope: NOT_APPLICABLE
database_role_scope: NOT_APPLICABLE

objects_accessed: []
privileges_required: []

risk_class: R0
cost_class: LOW

timeout_seconds: 30
max_rows: 1000
max_output_bytes: 2097152

sensitivity: ""
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: []
status: candidate
---

# Statement / procedure (read-only)

```sql
-- SELECT-only. Ningún DML/DDL. Ver policies/forbidden-operations.md.
```

# Notes by version

# Notes by platform

# Container / role scope notes

Por qué este `container_scope`/`database_role_scope` (ver docs/CONTRACTS.md#query-contract-v2-foundation-hardening).

# Cost classification rationale

Por qué este `cost_class` (ver `policies/query-cost-policy.md`).

# License notes

Por qué este `license_requirements` (ver `policies/licensing-awareness-policy.md`). `none` si no depende de ninguna feature licenciada.

# Sanitization notes

Campos KEEP/MASK/HASH/TOKENIZE/DROP relevantes de esta query (ver `sanitizers/data-classification-policy.md`).

# Evolution via `/change query`

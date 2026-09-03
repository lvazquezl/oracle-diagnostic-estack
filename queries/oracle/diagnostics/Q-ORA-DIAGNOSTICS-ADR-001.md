---
query_id: Q-ORA-DIAGNOSTICS-ADR-001
version: 1.0.0
domain: oracle
purpose: Incidentes ADR abiertos y ubicación de ADR home

supported_oracle_versions: [11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [V$DIAG_INFO, DBA_OUTSTANDING_ALERTS]
privileges_required: [SELECT on V$DIAG_INFO, SELECT on DBA_OUTSTANDING_ALERTS]

risk_class: R0
cost_class: LOW
timeout_seconds: 15
max_rows: 100
max_output_bytes: 65536

sensitivity: MEDIUM
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT a.reason, a.message_type, a.suggested_action, a.creation_time
FROM   dba_outstanding_alerts a
WHERE  a.message_type IN ('Error','Warning')
ORDER  BY a.creation_time DESC;
```

No certificada para 10g (sin ADR) — `oracle-discovery-analyst`/`oracle/diagnostics` reportan `capability_status: UNSUPPORTED` para esa versión, no ejecutan esta query.

# Notes by version

ADR completo desde 11g. En 10g, `oracle/diagnostics` se degrada según Capability Degradation.

# Notes by platform

Ninguna a nivel SQL — la ruta física del ADR home difiere por plataforma pero no se lee en esta query.

# Container / role scope notes

`NOT_APPLICABLE` — ADR es de instancia física.

# Cost classification rationale

`LOW`: número típicamente pequeño de alertas activas.

# License notes

Ninguna.

# Sanitization notes

`reason`/`suggested_action` → condicional (pueden contener nombres de schema/objeto en el mensaje) — sanitización aplicada antes de llegar al modelo.

# Evolution via `/change query`

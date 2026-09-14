---
query_id: Q-SEC-UNIFIED-AUDIT-TRAIL-001
version: 1.0.0

domain: security
purpose: >
  Evidencia reciente de actividad privilegiada desde Unified Audit Trail — privileged-audit (#
  29 del prompt de Fase 8). Query filtrada — nunca todo UNIFIED_AUDIT_TRAIL (# 61 del prompt).

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [UNIFIED_AUDIT_TRAIL]
privileges_required: [SELECT on UNIFIED_AUDIT_TRAIL]

risk_class: R0
cost_class: HIGH

timeout_seconds: 20
max_rows: 200
max_output_bytes: 131072

sensitivity: HIGH
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_audit_query_budget.sh, tests/test_privileged_audit_awareness.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT event_timestamp, dbusername, action_name, object_schema, object_name, return_code
FROM   unified_audit_trail
WHERE  event_timestamp >= SYSTIMESTAMP - :time_window_days
AND    (dbusername = 'SYS'
        OR action_name IN ('GRANT', 'REVOKE', 'CREATE USER', 'ALTER USER', 'DROP USER',
                            'CREATE ROLE', 'ALTER ROLE', 'DROP ROLE', 'AUDIT', 'NOAUDIT'))
ORDER  BY event_timestamp DESC
FETCH FIRST :max_rows ROWS ONLY;
```

`FETCH FIRST` requiere 12.1+ (`compatibility/oracle-sql-syntax/features.yaml`, `FETCH_FIRST`,
`min_version: "12.1"`) — coincide exactamente con `min_version` de `UNIFIED_AUDIT_TRAIL` misma
(12.1), no requiere variante legacy porque esta query nunca se certifica para versión anterior a
12.1. `:time_window_days`/`:max_rows` son binds obligatorios — nunca se consulta sin filtro de
tiempo (`# 61` del prompt: "usar filtros").

# Notes by version

`UNIFIED_AUDIT_TRAIL` verificada disponible desde 12.1.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`HIGH` — audit trail puede crecer sin límite; `time_window_days`/`max_rows`/`timeout_seconds`/
`max_output_bytes` acotan agresivamente (# 59, # 61 del prompt).

# License notes

Ninguna.

# Sanitization notes

`dbusername` → MASK por defecto salvo `SYS`/cuenta Oracle-maintained. `object_schema`/
`object_name` → MASK. Nunca se selecciona texto SQL completo del comando auditado, sólo
metadata (`action_name`, no `sql_text`).

# Evolution via `/change query`

N/A.

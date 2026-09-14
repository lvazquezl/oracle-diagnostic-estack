---
query_id: Q-SEC-TRADITIONAL-AUDIT-001
version: 1.0.0

domain: security
purpose: >
  Traditional Auditing (AUDIT_TRAIL parameter + evidencia de sesión) — para versiones legacy o
  cuando Unified Auditing no cubre lo requerido (# 28 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$PARAMETER, DBA_AUDIT_SESSION]
privileges_required: [SELECT on V$PARAMETER, SELECT on DBA_AUDIT_SESSION]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 15
max_rows: 200
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-TRADITIONAL-AUDIT-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10g-11g)"
  - variant_id: Q-SEC-TRADITIONAL-AUDIT-001-V2
    label: modern_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_12plus, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_audit_query_budget.sh, tests/test_traditional_audit_detection.sh]
status: active
---

# Statement / procedure (read-only) — común a ambas variantes

```sql
SELECT name, value
FROM   v$parameter
WHERE  name = 'audit_trail';
```

Determina si `AUDIT_TRAIL` está en `NONE|OS|DB|DB_EXTENDED|XML|XML_EXTENDED` — parámetro único,
sin Top-N, sin necesidad de variante por versión.

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10g-11g)

```sql
SELECT username, timestamp, action_name, returncode
FROM   (SELECT username, timestamp, action_name, returncode
        FROM   dba_audit_session
        WHERE  timestamp >= SYSDATE - :time_window_days
        ORDER  BY timestamp DESC)
WHERE  ROWNUM <= :max_rows;
```

# Statement / procedure (read-only) — Variant V2 (modern_12plus, 12.1+)

```sql
SELECT username, timestamp, action_name, returncode
FROM   dba_audit_session
WHERE  timestamp >= SYSDATE - :time_window_days
ORDER  BY timestamp DESC
FETCH FIRST :max_rows ROWS ONLY;
```

`FETCH FIRST` requiere 12.1+ (`compatibility/oracle-sql-syntax/features.yaml`,
`FETCH_FIRST.min_version: "12.1"`) — Variant V1 usa `ROWNUM` sobre un inline view ya ordenado
(`ORDER BY` dentro del subquery, antes de aplicar `ROWNUM`, para semántica correcta de Top-N).
`:time_window_days`/`:max_rows` son binds obligatorios en ambas variantes — nunca se consulta
sin filtro de tiempo (`# 61` del prompt: "usar filtros").

# Notes by version

`AUDIT_TRAIL`/`DBA_AUDIT_SESSION` estables desde 8i+, certificados desde 10g (mínimo del
catálogo). Split de variante V1/V2 exclusivamente por la sintaxis de row-limiting, no por
diferencia de columnas.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`MEDIUM` — acotado por `time_window_days`/`max_rows` en ambas variantes.

# License notes

Ninguna.

# Sanitization notes

`username` → MASK por defecto salvo cuenta Oracle-maintained conocida.

# Evolution via `/change query`

N/A.

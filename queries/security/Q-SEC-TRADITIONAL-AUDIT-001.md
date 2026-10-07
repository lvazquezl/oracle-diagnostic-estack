---
query_id: Q-SEC-TRADITIONAL-AUDIT-001
version: 3.0.0

domain: security
purpose: Resumen de la auditoría tradicional de sesiones de los últimos 7 días por acción y código de retorno (conteos, sin filas crudas).
  Traditional Auditing (AUDIT_TRAIL parameter + evidencia de sesión) — para versiones legacy o
  cuando Unified Auditing no cubre lo requerido (# 28 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_AUDIT_SESSION, CDB_AUDIT_SESSION]
privileges_required: [SELECT on DBA_AUDIT_SESSION, SELECT on CDB_AUDIT_SESSION]

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
    label: cdb_aware_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_12plus, 12.1+)"

tests: [tests/test_no_write_operations.sh, tests/test_audit_query_budget.sh, tests/test_traditional_audit_detection.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10g-11g)

```sql
SELECT *
FROM  (SELECT action_name, returncode AS return_code,
              COUNT(*) AS event_count, COUNT(DISTINCT username) AS user_count
       FROM   dba_audit_session
       WHERE  timestamp >= SYSDATE - 7
       GROUP  BY action_name, returncode
       ORDER  BY COUNT(*) DESC)
WHERE  ROWNUM <= 100;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_12plus, 12.1+)

```sql
SELECT con_id, action_name, returncode AS return_code,
       COUNT(*) AS event_count, COUNT(DISTINCT username) AS user_count
FROM   cdb_audit_session
WHERE  timestamp >= SYSDATE - 7
GROUP  BY con_id, action_name, returncode
ORDER  BY COUNT(*) DESC
FETCH  FIRST 100 ROWS ONLY;
```

Ventana fija de 7 días y agregación en la base (logons y logoffs por código de retorno; `return_code` distinto de 0 = intento fallido, p. ej. 1017). El valor de `AUDIT_TRAIL` ya lo entrega `Q-ORA-PARAMETERS-001` (`value_keyword`). La 1.0.0 dependía de binds (`:time_window_days`, `:max_rows`) y fallaba con SP2-0552 en ejecución humana (LAB19S).

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

CHG-ESTACK-SEC-QUERIES-001 — 2.0.0: resumen agregado de 7 días sin binds; se retira el bloque común de `AUDIT_TRAIL` (cubierto por `Q-ORA-PARAMETERS-001`).

N/A.

3.0.0 CHG-ESTACK-PDB-COVERAGE-001: V2 (12.1+) lee `CDB_AUDIT_SESSION` con `con_id`.

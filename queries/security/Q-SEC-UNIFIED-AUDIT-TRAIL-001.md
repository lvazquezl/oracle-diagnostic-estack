---
query_id: Q-SEC-UNIFIED-AUDIT-TRAIL-001
version: 3.0.0

domain: security
purpose: Resumen de la auditoría unificada de los últimos 7 días por acción y resultado (conteos, sin filas crudas ni texto SQL).
  Evidencia reciente de actividad privilegiada desde Unified Audit Trail — privileged-audit (#
  29 del prompt de Fase 8). Query filtrada — nunca todo UNIFIED_AUDIT_TRAIL (# 61 del prompt).

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [UNIFIED_AUDIT_TRAIL, CDB_UNIFIED_AUDIT_TRAIL]
privileges_required: [SELECT on UNIFIED_AUDIT_TRAIL, SELECT on CDB_UNIFIED_AUDIT_TRAIL]

risk_class: R0
cost_class: HIGH

timeout_seconds: 20
max_rows: 200
max_output_bytes: 131072

sensitivity: HIGH
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-UNIFIED-AUDIT-TRAIL-001-V1
    label: unified_12_18
    oracle_versions: {min: "12.1", max: "18.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (unified_12_18, 12.1–18c)"
  - variant_id: Q-SEC-UNIFIED-AUDIT-TRAIL-001-V2
    label: cdb_19plus
    oracle_versions: {min: "19.0", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_19plus, 19c+: CDB_UNIFIED_AUDIT_TRAIL con con_id)"

tests: [tests/test_no_write_operations.sh, tests/test_audit_query_budget.sh, tests/test_privileged_audit_awareness.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (unified_12_18, 12.1–18c)

```sql
SELECT action_name, return_code,
       COUNT(*)                   AS event_count,
       COUNT(DISTINCT dbusername) AS user_count
FROM   unified_audit_trail
WHERE  event_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
GROUP  BY action_name, return_code
ORDER  BY COUNT(*) DESC
FETCH  FIRST 100 ROWS ONLY;
```

# Statement / procedure (read-only) — Variant V2 (cdb_19plus, 19c+: CDB_UNIFIED_AUDIT_TRAIL con con_id)

```sql
SELECT con_id, action_name, return_code,
       COUNT(*)                   AS event_count,
       COUNT(DISTINCT dbusername) AS user_count
FROM   cdb_unified_audit_trail
WHERE  event_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
GROUP  BY con_id, action_name, return_code
ORDER  BY COUNT(*) DESC
FETCH  FIRST 100 ROWS ONLY;
```

Ventana fija de 7 días y agregación en la base: cuántos eventos de cada acción (logon, DDL, grants, etc.) y con qué código de retorno, y cuántos usuarios distintos los generaron. La 1.0.0 nunca podía resolverse: listaba las acciones como literales (`'GRANT'`, `'AUDIT'`…), que el guard de sólo lectura veta en cualquier parte del SQL, y además dependía de binds. Sin filas crudas, sin usuarios ni objetos, sin texto SQL. Requiere el rol `AUDIT_VIEWER` (no incluido en `SELECT_CATALOG_ROLE`).

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

CHG-ESTACK-SEC-QUERIES-001 — 2.0.0: resumen agregado de 7 días sin literales vetados ni binds (antes no resolvía nunca).

N/A.

3.0.0 CHG-ESTACK-PDB-COVERAGE-001: V2 (19c+) lee `CDB_UNIFIED_AUDIT_TRAIL` con `con_id`. Se acota a 19c porque la Database Reference de 12.2 no documenta esa vista; existe y se validó en 19c (lab). 12.1–18c sigue con `UNIFIED_AUDIT_TRAIL` (solo el contenedor actual).

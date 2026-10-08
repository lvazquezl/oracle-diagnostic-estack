---
query_id: Q-ORA-UNDO-001
version: 2.0.0
domain: oracle
purpose: Configuración y uso del tablespace UNDO activo

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [V$PARAMETER, DBA_TABLESPACES, V$UNDOSTAT]
privileges_required: [SELECT on V$PARAMETER, SELECT on DBA_TABLESPACES, SELECT on V$UNDOSTAT]

risk_class: R0
cost_class: LOW
timeout_seconds: 15
max_rows: 100
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

variants:
  - variant_id: Q-ORA-UNDO-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2)"
  - variant_id: Q-ORA-UNDO-001-V2
    label: per_container_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (per_container_12plus, 12.1+: retención ajustada por con_id)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2)

```sql
SELECT (SELECT value FROM v$parameter WHERE name='undo_tablespace') AS undo_tablespace,
       (SELECT value FROM v$parameter WHERE name='undo_retention') AS undo_retention,
       (SELECT MAX(tuned_undoretention) FROM v$undostat
        WHERE begin_time >= SYSDATE - 1/24) AS tuned_undoretention_last_hour
FROM   dual;
```

# Statement / procedure (read-only) — Variant V2 (per_container_12plus, 12.1+: retención ajustada por con_id)

```sql
SELECT u.con_id,
       (SELECT value FROM v$parameter WHERE name='undo_tablespace') AS undo_tablespace,
       (SELECT value FROM v$parameter WHERE name='undo_retention')  AS undo_retention,
       MAX(u.tuned_undoretention)                                  AS tuned_undoretention_last_hour
FROM   v$undostat u
WHERE  u.begin_time >= SYSDATE - 1/24
GROUP  BY u.con_id
ORDER  BY u.con_id;
```

# Notes by version

`V$UNDOSTAT` estable desde 9i; `undo_management` relevante como parámetro sólo hasta 11g.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER` — desde 18c puede haber PDB local undo, interpretado por el skill.

# Cost classification rationale

`LOW`: subqueries de una sola fila cada una.

# License notes

Ninguna.

# Sanitization notes

Todos los campos → KEEP.

CHG-ESTACK-COLLECTOR-FACTORY-B1 — 1.0.1: se agrega `FROM dual`. Sin él la sentencia no es válida (ORA-00923); lo detectó la primera ejecución real en el lab.

# Evolution via `/change query`

2.0.0 CHG-ESTACK-ASSESSMENT-ACCURACY-001: V2 (12.1+) agrupa la retención ajustada por `con_id`: desde el root `V$UNDOSTAT` mezcla contenedores y con local undo cada PDB tiene la suya (revisión de ANA-20261008-001). `undo_tablespace`/`undo_retention` siguen siendo los del contenedor de la sesión.

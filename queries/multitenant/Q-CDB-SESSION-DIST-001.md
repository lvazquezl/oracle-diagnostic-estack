---
query_id: Q-CDB-SESSION-DIST-001
version: 1.0.0

domain: multitenant
purpose: Distribución de sesiones por PDB/instancia/servicio — metadata agregada, nunca SQL text ni bind values

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: CDB_ROOT_ONLY
database_role_scope: ANY

objects_accessed: [GV$SESSION]
privileges_required: [SELECT on GV$SESSION]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 20
max_rows: 500
max_output_bytes: 65536

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_pdb_sessions.sh, tests/test_no_bind_value_collection.sh, tests/test_no_application_table_access.sh, tests/test_multitenant_query_cost.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT s.con_id,
       s.inst_id,
       s.service_name,
       COUNT(*)                                        AS session_count,
       SUM(CASE WHEN s.status = 'ACTIVE'   THEN 1 ELSE 0 END) AS active_count,
       SUM(CASE WHEN s.status = 'INACTIVE' THEN 1 ELSE 0 END) AS inactive_count
FROM   gv$session s
WHERE  s.type = 'USER'
  AND  s.con_id > 1
GROUP  BY s.con_id, s.inst_id, s.service_name
ORDER  BY s.con_id, s.inst_id, s.service_name;
```

Mismo patrón certificado que `Q-RAC-SESSION-DIST-001` (Fase 4) — extendido con `con_id` (columna real de `GV$SESSION` desde 12.1, multitenant-aware) y desglose `active`/`inactive` en vez de sólo `ACTIVE` (`# 15` del prompt: `CON_ID`/`PDB`/`INSTANCE`/`SERVICE`/`SESSION COUNT`/`ACTIVE`/`INACTIVE`). Sólo metadata agregada — nunca `sql_id`/`sql_text`/bind values, consistente con `sanitizers/data-classification-policy.md` y `policies/forbidden-operations.md` (`# 15`: no exponer application data).

# Notes by version

`GV$SESSION.CON_ID` disponible desde 12.1. Resto de columnas (`inst_id`/`service_name`/`type`/`status`) estables desde 10g, ya certificadas en `Q-RAC-SESSION-DIST-001`.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`CDB_ROOT_ONLY` — `GV$SESSION` ya es CDB-aware, se consulta una vez desde CDB$ROOT. `database_role_scope: ANY`. `WHERE s.con_id > 1` excluye sesiones internas de CDB$ROOT.

# Cost classification rationale

`MEDIUM` — `GV$SESSION` puede tener miles de filas en un ambiente activo; el `GROUP BY` agrega antes de devolver resultado, pero el escaneo subyacente es más costoso que una vista pre-agregada.

# License notes

Ninguna.

# Sanitization notes

`service_name` → MASK por defecto. Ningún campo de sesión individual (`sql_id`, `program`, `module`, `client_identifier`) se selecciona — sólo el agregado.

# Evolution via `/change query`

Detalle de sesión individual (no agregado) sólo vía `/change query` con justificación diagnóstica específica y sanitización explícita adicional.

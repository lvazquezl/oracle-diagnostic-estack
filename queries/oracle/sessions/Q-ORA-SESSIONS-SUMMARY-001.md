---
query_id: Q-ORA-SESSIONS-SUMMARY-001
version: 1.0.0
domain: oracle
purpose: Resumen agregado de sesiones por estado/tipo, sesiones bloqueadas

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$SESSION]
privileges_required: [SELECT on V$SESSION]

risk_class: R0
cost_class: MEDIUM
timeout_seconds: 20
max_rows: 200
max_output_bytes: 65536

sensitivity: MEDIUM
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_application_data_blocked.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT status, type, COUNT(*) AS session_count,
       SUM(CASE WHEN blocking_session IS NOT NULL THEN 1 ELSE 0 END) AS blocked_count,
       MAX(CASE WHEN status='ACTIVE' THEN last_call_et ELSE NULL END) AS max_active_et
FROM   v$session
GROUP  BY status, type;
```

Nunca selecciona `sql_id`, `sql_text`, `module`/`action` con contenido no sanitizado, ni ninguna columna de aplicación — sólo agregados.

# Notes by version

`BLOCKING_SESSION` estable desde 10g (reemplazó al mecanismo anterior de `V$LOCK` join manual).

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER` — `CON_ID` disponible desde 12c si se requiere acotar por PDB.

# Cost classification rationale

`MEDIUM`: `GV$SESSION`-equivalente agregado, tamaño de tabla dinámica puede ser grande en ambientes con miles de sesiones — agregación evita escanear filas individuales hacia el modelo.

# License notes

Ninguna.

# Sanitization notes

Sólo agregados — sin columnas identificatorias de sesión individual salvo `blocked_count` (conteo, no identidad).

# Evolution via `/change query`

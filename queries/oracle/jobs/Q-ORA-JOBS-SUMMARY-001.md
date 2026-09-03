---
query_id: Q-ORA-JOBS-SUMMARY-001
version: 1.0.0
domain: oracle
purpose: Jobs Scheduler/legacy fallidos, de larga duración o deshabilitados

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]
container_scope: ANY_CONTAINER
database_role_scope: PRIMARY

objects_accessed: [DBA_SCHEDULER_JOBS]
privileges_required: [SELECT on DBA_SCHEDULER_JOBS]
# Oracle Core Compatibility Hardening: objects_accessed corregido — la v1.0 declaraba
# DBA_SCHEDULER_JOB_RUN_DETAILS y DBA_JOBS (legacy DBMS_JOB) sin que el SQL real los consultara
# (metadata/reality mismatch). DBA_JOBS legacy queda PLANNED como logical query separada
# (Q-ORA-JOBS-LEGACY-001, no creada en este hardening — no inventar un SELECT ficticio sólo
# para "usar" la vista) — ver docs/PHASE_2_COMPATIBILITY_HARDENING.md#other-query-fixes.

risk_class: R0
cost_class: MEDIUM
timeout_seconds: 20
max_rows: 500
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true
license_requirements: none
execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_no_application_table_access.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT j.owner, j.job_name, j.state, j.last_start_date, j.failure_count
FROM   dba_scheduler_jobs j
WHERE  j.state IN ('BROKEN','FAILED') OR j.failure_count > 0
ORDER  BY j.failure_count DESC;
```

Nunca lee el cuerpo PL/SQL del job (`DBA_SCHEDULER_JOBS.JOB_ACTION` con lógica de negocio) — sólo metadata de ejecución.

# Notes by version

`DBA_SCHEDULER_JOBS` desde 10g — cubre todo el rango declarado sin necesidad de variantes. `DBA_JOBS` (legacy `DBMS_JOB`) **no está cubierto por esta query** — un ambiente que use únicamente `DBMS_JOB` legado no verá esos jobs en `oracle/jobs`. Esto se reporta explícitamente como `capability_status: PARTIALLY_SUPPORTED` por el skill (`skills/oracle/jobs/SKILL.md`), no se omite silenciosamente.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER` — `CON_ID` desde 12c si aplica.

# Cost classification rationale

`MEDIUM`: filtro por estado acota el resultado, pero el escaneo base puede ser amplio en ambientes con muchos jobs.

# License notes

Ninguna.

# Sanitization notes

`job_name`/`owner` → MASK por defecto (puede revelar lógica de negocio).

# Evolution via `/change query`

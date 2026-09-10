---
query_id: Q-CDB-RESOURCE-USAGE-001
version: 2.0.0

domain: multitenant
purpose: Consumo de recursos por PDB (CPU, sesiones, parallel servers, SGA/PGA, I/O) — licensing-safe, nunca depende de AWR/ASH

# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING: corrige un defecto real de
# la construcción base de Fase 6 — V$RSRCPDBMETRIC se declaraba soportada desde 12c (12.1) sin
# verificación independiente. Verificado (WebFetch, docs.oracle.com/en/database/oracle/oracle-
# database/12.2/refrn/V-RSRCPDBMETRIC.html): "introduced in Oracle Database 12c Release 2
# (12.2.0.1)" — no existe en 12.1. Sin fuente equivalente certificada para PDB-level resource
# metrics en 12.1 (no se inventa una alternativa, # 11 del prompt de hardening) — en 12.1, esta
# capability degrada explícitamente a PARTIALLY_SUPPORTED (ver
# skills/multitenant/resource-usage/SKILL.md#version-degradation-121). "12c" se mantiene en esta
# lista descriptiva (mismo criterio que Q-CDB-LOCKDOWN-001, también 12.2+-only) — la precisión de
# 12.2 vive en config/query-compatibility-matrix.yaml y compatibility/oracle-dictionary/views.yaml.
supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: CDB_ROOT_ONLY
database_role_scope: ANY

objects_accessed: [V$RSRCPDBMETRIC]
privileges_required: [SELECT on V$RSRCPDBMETRIC]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 200
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_pdb_resource_usage.sh, tests/test_multitenant_container_scope.sh, tests/test_v_rsrcpdbmetric_not_supported_121.sh, tests/test_v_rsrcpdbmetric_supported_122.sh, tests/test_pdb_resource_usage_121_partial.sh, tests/test_pdb_resource_usage_122_supported.sh, tests/test_pdb_resource_usage_columns_valid.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT con_id, cpu_consumed_time, cpu_wait_time, num_cpus, cpu_utilization_limit,
       avg_cpu_utilization, avg_running_sessions, avg_waiting_sessions,
       running_sessions_limit, avg_active_parallel_servers, avg_queued_parallel_servers,
       parallel_servers_limit, sga_bytes, pga_bytes, iops, iombps, plan_name
FROM   v$rsrcpdbmetric
WHERE  con_id > 1
ORDER  BY con_id;
```

`V$RSRCPDBMETRIC` reporta una fila por PDB con la muestra del último minuto — disponible incluso sin un Resource Manager plan activo si `STATISTICS_LEVEL` es `TYPICAL`/`ALL` (comportamiento documentado de Oracle, no asumido). No requiere Diagnostics/Tuning Pack — licensing-safe (`# 30` del prompt: nunca depende de AWR/ASH salvo delegación explícita con Licensing Gate propio).

# Notes by version

`V$RSRCPDBMETRIC` disponible desde **12.2.0.1** — verificado (WebFetch, docs.oracle.com/en/database/oracle/oracle-database/12.2/refrn/V-RSRCPDBMETRIC.html): "introduced in Oracle Database 12c Release 2 (12.2.0.1)". La construcción base de Fase 6 declaraba min_version "12.1" sin verificación independiente — corregido en este hardening (`docs/PHASE_6_QUERY_COMPATIBILITY_HARDENING.md`). En 12.1, `V$RSRCPDBMETRIC` no existe y no hay una fuente equivalente certificada — la capability de resource usage degrada a `PARTIALLY_SUPPORTED` en vez de fingir soporte (ver `skills/multitenant/resource-usage/SKILL.md`). Columnas verificadas contra Oracle Database Reference 12.2.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`CDB_ROOT_ONLY`. `database_role_scope: ANY`. `WHERE con_id > 1` excluye la fila agregada de CDB completo si la vista la expone en `con_id=0`.

# Cost classification rationale

`LOW` — una fila por PDB, típicamente decenas.

# License notes

Ninguna — vista de Resource Manager base, no requiere Diagnostics/Tuning Pack.

# Sanitization notes

Todos los campos → KEEP (métricas numéricas, `plan_name` es configuración no sensible).

# Evolution via `/change query`

Histórico (`V$RSRC_PDB_HISTORY`) sólo vía `/change query` si se requiere tendencia — verificar licensing-safety antes de certificar (`# 8` del prompt: "when available/licensing-safe").

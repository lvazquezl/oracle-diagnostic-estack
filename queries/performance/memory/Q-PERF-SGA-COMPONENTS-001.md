---
query_id: Q-PERF-SGA-COMPONENTS-001
version: 1.0.0

domain: performance
purpose: Componentes dinámicos de la SGA (incluye java y streams pool): tamaño actual, mínimo, máximo y especificado, operaciones de resize desde el arranque y la última operación

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [V$SGA_DYNAMIC_COMPONENTS]
privileges_required: [SELECT on V$SGA_DYNAMIC_COMPONENTS]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 32
max_output_bytes: 8192

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-PERF-SGA-COMPONENTS-001-V1
    label: all_versions
    oracle_versions: {min: "10.2", max: "23.0"}
    container_scope: NOT_APPLICABLE
    sql_block: "Variant V1 (all_versions, 10.2–23.0: componentes de la instancia)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_collector_factory.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (all_versions, 10.2–23.0: componentes de la instancia)

```sql
SELECT sga_component,
       ROUND(SUM(current_size) / 1048576, 1) AS current_mb,
       ROUND(SUM(min_size) / 1048576, 1) AS min_mb,
       ROUND(SUM(max_size) / 1048576, 1) AS max_mb,
       ROUND(SUM(user_specified_size) / 1048576, 1) AS user_specified_mb,
       SUM(oper_count) AS resize_ops,
       MAX(last_oper_type) KEEP (DENSE_RANK LAST ORDER BY last_oper_time NULLS FIRST) AS last_oper_type,
       ROUND((SYSDATE - MAX(last_oper_time)) * 24, 1) AS hours_since_last_oper
FROM  (SELECT CASE WHEN component IN ('shared pool', 'large pool', 'java pool', 'streams pool', 'DEFAULT buffer cache', 'KEEP buffer cache',
                                      'RECYCLE buffer cache', 'DEFAULT 2K buffer cache', 'DEFAULT 4K buffer cache',
                                      'DEFAULT 8K buffer cache', 'DEFAULT 16K buffer cache', 'DEFAULT 32K buffer cache',
                                      'Shared IO Pool', 'Data Transfer Cache', 'In-Memory Area', 'memoptimize buffer cache',
                                      'ASM Buffer Cache', 'unified pga pool')
                   THEN component ELSE 'OTHER' END AS sga_component,
              current_size, min_size, max_size, user_specified_size, oper_count, last_oper_type, last_oper_time
       FROM   v$sga_dynamic_components)
GROUP  BY sga_component
ORDER  BY sga_component;
```

# Notes by version

`V$SGA_DYNAMIC_COMPONENTS` desde 10.1. Los componentes cambian entre versiones (`Shared IO Pool` 11g, `In-Memory Area` 12.1.0.2, `memoptimize buffer cache` 18c, `unified pga pool` 23ai); un nombre desconocido sale `OTHER`.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

Componentes de la instancia (no por contenedor). En RAC, de la instancia consultada. `resize_ops` y la última operación son desde el arranque: muchas operaciones en poco tiempo indican resize frecuente entre buffer cache y shared pool (ASMM/AMM).

# Cost classification rationale

`LOW` — una fila por componente.

# License notes

Ninguna.

# Sanitization notes

Solo nombres de componente (lista cerrada de Oracle), MB, conteos, el tipo de la última operación y horas. Fechas absolutas fuera.

# Evolution via `/change query`

1.0.0 CHG-ESTACK-C-NEW-QUERIES-001: creación (lote C, cobertura del assessment).

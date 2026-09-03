---
query_id: Q-DBA-TBS-USAGE-001
version: 2.0.0

domain: oracle
purpose: Uso agregado por tablespace permanente

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [standalone, rac]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_TABLESPACE_USAGE_METRICS, DBA_DATA_FILES, DBA_FREE_SPACE]
privileges_required: [SELECT on DBA_TABLESPACE_USAGE_METRICS, SELECT on DBA_DATA_FILES, SELECT on DBA_FREE_SPACE]

risk_class: R0
cost_class: LOW

timeout_seconds: 20
max_rows: 500
max_output_bytes: 131072

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

# Oracle Core Compatibility Hardening: bug VARIANT_REQUIRED corregido — la v1.0 tenía DOS
# sentencias SQL pegadas en un solo bloque con comentarios "-- 11g+"/"-- 10g fallback" y
# ninguna lógica real de selección. Ahora 2 variantes explícitas resueltas por el Query
# Variant Resolver, no por comentarios.
variants:
  - variant_id: Q-DBA-TBS-USAGE-001-V1
    label: legacy_10g
    oracle_versions: {min: "10.2", max: "10.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g, 10.2)"
  - variant_id: Q-DBA-TBS-USAGE-001-V2
    label: modern_11plus
    oracle_versions: {min: "11.0", max: latest}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (modern_11plus, 11.0+)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_oracle_core_tablespaces.sh, tests/test_every_logical_query_has_variant.sh, tests/test_no_variant_references_unknown_column.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g, 10.2)

```sql
SELECT df.tablespace_name,
       ROUND((df.bytes - NVL(fs.bytes,0)) / df.bytes * 100, 1) AS used_percent
FROM   (SELECT tablespace_name, SUM(bytes) bytes FROM dba_data_files GROUP BY tablespace_name) df,
       (SELECT tablespace_name, SUM(bytes) bytes FROM dba_free_space GROUP BY tablespace_name) fs
WHERE  df.tablespace_name = fs.tablespace_name(+)
ORDER  BY used_percent DESC;
```

Fallback certificado — `DBA_TABLESPACE_USAGE_METRICS` no existe en 10g. Este NO es un fallback "inventado": es la única variante certificada para 10g, derivada de vistas presentes desde versiones anteriores a 10g.

# Statement / procedure (read-only) — Variant V2 (modern_11plus, 11.0+)

```sql
SELECT tablespace_name, used_percent, used_space, tablespace_size
FROM   dba_tablespace_usage_metrics
ORDER  BY used_percent DESC;
```

# Notes by version

`DBA_TABLESPACE_USAGE_METRICS` desde 11g → exclusivo de V2. V1 (10g) deriva el mismo dato de `DBA_DATA_FILES`/`DBA_FREE_SPACE`, disponibles en 10g. Ver `compatibility/oracle-dictionary/views.yaml#dba_tablespace_usage_metrics`.

# Notes by platform

Ninguna diferencia en ninguna variante — SQL puro.

# Container / role scope notes

Válida en CDB$ROOT o PDB según la conexión en ambas variantes — `ANY_CONTAINER`.

# Cost classification rationale

`LOW` en ambas variantes: agregación simple, acotada al número de tablespaces (típicamente decenas, no miles).

# License notes

Ninguna en ninguna variante.

# Sanitization notes

`tablespace_name` → MASK por defecto en ambas variantes (puede revelar nombre de aplicación).

# Evolution via `/change query`

`DBA_FREE_SPACE`/`DBA_DATA_FILES` (V1) son estables desde versiones anteriores a 10g — sin riesgo de deprecación previsible. Cambios vía `/change compatibility`.

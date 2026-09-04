---
query_id: Q-RAC-GES-GCS-001
version: 1.0.0

domain: rac
purpose: Indicadores agregados de Global Enqueue Service / Global Cache Service por instancia

supported_oracle_versions: [11gR2, 12c, 18c, 19c, 21c, 23ai]
supported_os: [Oracle Linux, RHEL, SUSE, Solaris, AIX, Windows Server]
supported_architectures: [RAC]

container_scope: NOT_APPLICABLE
database_role_scope: ANY

objects_accessed: [GV$GES_STATISTICS, GV$GCS_STATISTICS, GV$INSTANCE_CACHE_TRANSFER]
privileges_required: [SELECT on GV$GES_STATISTICS, SELECT on GV$GCS_STATISTICS, SELECT on GV$INSTANCE_CACHE_TRANSFER]

risk_class: R0
cost_class: MEDIUM

timeout_seconds: 30
max_rows: 200
max_output_bytes: 131072

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_query_contract_requires_container_scope.sh, tests/test_query_contract_requires_role_scope.sh, tests/test_query_contract_requires_cost_class.sh, tests/test_query_cost_medium.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT g.inst_id, g.name AS ges_stat, g.value AS ges_value
FROM   gv$ges_statistics g
WHERE  g.name IN ('global lock async converts', 'global lock sync converts', 'global lock releases')
UNION ALL
SELECT c.inst_id, c.name AS gcs_stat, c.value AS gcs_value
FROM   gv$gcs_statistics c
WHERE  c.name IN ('global cache cr blocks received', 'global cache current blocks received')
ORDER  BY 1;
```

Sólo estadísticas agregadas, nunca detalle por bloque/objeto individual — evita convertir esta query en un vector de I/O elevado sobre estructuras internas de Cache Fusion.

# Notes by version

`GV$GES_STATISTICS`/`GV$GCS_STATISTICS`/`GV$INSTANCE_CACHE_TRANSFER` estables desde 11gR2.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`NOT_APPLICABLE` — estadísticas de Cache Fusion son a nivel instancia, no contenedor.

# Cost classification rationale

`MEDIUM` — las vistas `GV$GES_STATISTICS`/`GV$GCS_STATISTICS` pueden ser costosas de agregar cross-instance bajo carga alta; se acota a los nombres de estadística relevantes, nunca `SELECT *`.

# License notes

Ninguna — estadísticas GES/GCS no requieren Diagnostics Pack (son parte del motor RAC base, distinto de AWR).

# Sanitization notes

Todos los campos → KEEP — contadores agregados, no identifican datos de aplicación.

# Evolution via `/change query`

Estadísticas adicionales (`gc * time`) vía `/change query` si un patrón de correlación certificado lo requiere.

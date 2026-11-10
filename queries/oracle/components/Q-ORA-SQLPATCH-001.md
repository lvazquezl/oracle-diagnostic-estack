---
query_id: Q-ORA-SQLPATCH-001
version: 1.0.0

domain: oracle
purpose: Historial de parches SQL aplicados por datapatch (o catupgrd/catbundle en 10g/11g) por contenedor: acción, estado, tipo de parche, versión destino y horas desde la acción

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_REGISTRY_HISTORY, CDB_REGISTRY_SQLPATCH]
privileges_required: [SELECT on DBA_REGISTRY_HISTORY, SELECT on CDB_REGISTRY_SQLPATCH]

risk_class: R0
cost_class: LOW

timeout_seconds: 15
max_rows: 200
max_output_bytes: 32768

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-ORA-SQLPATCH-001-V1
    label: legacy_10g_11g
    oracle_versions: {min: "10.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_REGISTRY_HISTORY)"
  - variant_id: Q-ORA-SQLPATCH-001-V2
    label: sqlpatch_12_1_12_2
    oracle_versions: {min: "12.1", max: "12.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (sqlpatch_12_1_12_2, 12.1–12.2: CDB_REGISTRY_SQLPATCH por contenedor)"
  - variant_id: Q-ORA-SQLPATCH-001-V3
    label: sqlpatch_18plus
    oracle_versions: {min: "18.0", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V3 (sqlpatch_18plus, 18.0–23.0: tipo de parche y versión destino)"

tests: [tests/test_no_write_operations.sh, tests/test_query_limits.sh, tests/test_collector_factory.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_10g_11g, 10.2–11.2: DBA_REGISTRY_HISTORY)

```sql
SELECT p.action AS patch_action,
       p.id AS patch_id,
       'LEGACY' AS patch_type,
       'NOT_RECORDED' AS patch_status,
       p.version AS target_version,
       ROUND((CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) - CAST(SYS_EXTRACT_UTC(p.action_time) AS DATE)) * 24, 1) AS hours_since_action
FROM   dba_registry_history p
WHERE  p.action_time IS NOT NULL
ORDER  BY p.action_time DESC;
```

# Statement / procedure (read-only) — Variant V2 (sqlpatch_12_1_12_2, 12.1–12.2: CDB_REGISTRY_SQLPATCH por contenedor)

```sql
SELECT p.con_id,
       p.action AS patch_action,
       p.patch_id,
       'NOT_RECORDED' AS patch_type,
       p.status AS patch_status,
       ROUND((CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) - CAST(SYS_EXTRACT_UTC(p.action_time) AS DATE)) * 24, 1) AS hours_since_action
FROM   cdb_registry_sqlpatch p
ORDER  BY p.action_time DESC;
```

# Statement / procedure (read-only) — Variant V3 (sqlpatch_18plus, 18.0–23.0: tipo de parche y versión destino)

```sql
SELECT p.con_id,
       p.action AS patch_action,
       p.patch_id,
       p.patch_type,
       p.status AS patch_status,
       p.target_version,
       ROUND((CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) - CAST(SYS_EXTRACT_UTC(p.action_time) AS DATE)) * 24, 1) AS hours_since_action
FROM   cdb_registry_sqlpatch p
ORDER  BY p.action_time DESC;
```

# Notes by version

10g/11g: `DBA_REGISTRY_HISTORY` (CPU/PSU por `catbundle`); no registra estado ni tipo de parche (`NOT_RECORDED`, `LEGACY`). 12.1–12.2: `DBA_REGISTRY_SQLPATCH` sin `PATCH_TYPE` ni `TARGET_VERSION` (columnas de 18c). 18c+: `PATCH_TYPE` (`RU`, `RUR`, `INTERIM`, `CU`) y `TARGET_VERSION` (versión completa tras el parche).

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

12.1+ usa `CDB_REGISTRY_SQLPATCH`: desde `CDB$ROOT` muestra cada contenedor, de modo que una PDB donde datapatch no corrió o terminó con errores queda visible. En 10g/11g es la base completa.

# Cost classification rationale

`LOW` — decenas de filas por contenedor.

# License notes

Ninguna.

# Sanitization notes

`DESCRIPTION`, `LOGFILE`, `PATCH_DIRECTORY`, `PATCH_DESCRIPTOR`, `BUNDLE_DATA` y `COMMENTS` nunca se seleccionan. `patch_id` es el número público del parche de Oracle. `patch_action`, `patch_type` y `patch_status` son palabras cerradas; un valor fuera de la lista se descarta. Fechas absolutas fuera: solo horas desde la acción.

# Evolution via `/change query`

1.0.0 CHG-ESTACK-C-NEW-QUERIES-001: creación (lote C, cobertura del assessment).

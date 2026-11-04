---
query_id: Q-SEC-DATA-REDACTION-POLICIES-001
version: 4.0.0

domain: security
purpose: >
  Presencia/configuración de políticas de Data Redaction (DBMS_REDACT) — data-redaction-awareness,
  licensed bajo Advanced Security Option, distinto de Data Masking and Subsetting (# 41, # 42
  del prompt de Fase 8).

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [REDACTION_POLICIES, REDACTION_COLUMNS]
privileges_required: [SELECT_CATALOG_ROLE]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 200
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-DATA-REDACTION-POLICIES-001-V1
    label: aggregated_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (aggregated_12plus, 12.1–23.0: agregado por estado y tipo de función)"

tests: [tests/test_no_write_operations.sh, tests/test_no_redaction_change.sh, tests/test_data_redaction_awareness.sh, tests/test_security_licensing_gate.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (aggregated_12plus, 12.1–23.0: agregado por estado y tipo de función)

```sql
SELECT x.policy_enabled, x.function_type, COUNT(DISTINCT x.object_key) AS protected_objects,
       COUNT(x.column_name) AS redacted_columns
FROM  (SELECT CASE WHEN p.enable IN ('YES', 'NO') THEN p.enable ELSE 'OTHER' END AS policy_enabled,
              CASE c.function_type WHEN 'FULL REDACTION' THEN 'FULL' WHEN 'PARTIAL REDACTION' THEN 'PARTIAL'
                   WHEN 'REGEXP REDACTION' THEN 'REGEXP' WHEN 'RANDOM REDACTION' THEN 'RANDOM'
                   WHEN 'NO REDACTION' THEN 'NONE' WHEN 'NULLIFY REDACTION' THEN 'NULLIFY'
                   ELSE CASE WHEN c.column_name IS NULL THEN 'NO_COLUMN' ELSE 'OTHER' END END AS function_type,
              p.object_owner || '.' || p.object_name AS object_key, c.column_name
       FROM   redaction_policies p
       LEFT   JOIN redaction_columns c ON c.object_owner = p.object_owner AND c.object_name = p.object_name) x
GROUP  BY x.policy_enabled, x.function_type
ORDER  BY x.policy_enabled, x.function_type;
```

# Notes by version

Data Redaction existe desde 12.1. `NULLIFY REDACTION` aparece en versiones recientes; un valor desconocido sale como `OTHER`.

# Notes by platform

Ninguna.

# Container / role scope notes

`REDACTION_POLICIES`/`REDACTION_COLUMNS` describen el contenedor de la sesión (el root). No tienen variante `CDB_*`.

# Cost classification rationale

`LOW` — típicamente pocas políticas configuradas.

# License notes

Leer `REDACTION_POLICIES` y `REDACTION_COLUMNS` (diccionario) no usa Data Redaction; crear o aplicar políticas con `DBMS_REDACT` sí requiere Advanced Security Option. Por eso `license_requirements: none` desde 4.0.0: la consulta informa si la opción se usa, que es justamente lo que el licenciamiento necesita saber.

# Sanitization notes

Solo conteos por estado y tipo: dueño, objeto, columna y nombre de política nunca salen de la base. Requiere `SELECT_CATALOG_ROLE`.

# Evolution via `/change query`

CHG-ESTACK-SEC-QUERIES-001 — 3.0.0: políticas y columnas en una sola sentencia (`LEFT JOIN`); antes eran dos sentencias y la query no resolvía.

N/A.

4.0.0 CHG-ESTACK-B7-SECURITY-COVERAGE-001: 4.0.0: agregado sin identificadores, `license_requirements: none` (lectura de diccionario).

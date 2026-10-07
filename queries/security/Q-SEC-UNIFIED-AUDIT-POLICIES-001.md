---
query_id: Q-SEC-UNIFIED-AUDIT-POLICIES-001
version: 2.0.0

domain: security
purpose: Políticas de Unified Auditing habilitadas — audit configuration/unified-auditing (# 27 del prompt de Fase 8).

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [AUDIT_UNIFIED_ENABLED_POLICIES]
privileges_required: [SELECT on AUDIT_UNIFIED_ENABLED_POLICIES]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 200
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-UNIFIED-AUDIT-POLICIES-001-V1
    label: legacy_121_user_name
    oracle_versions: {min: "12.1", max: "12.1"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_121_user_name, 12.1)"
  - variant_id: Q-SEC-UNIFIED-AUDIT-POLICIES-001-V2
    label: entity_122plus
    oracle_versions: {min: "12.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (entity_122plus, 12.2+)"

tests: [tests/test_no_write_operations.sh, tests/test_no_audit_policy_change.sh, tests/test_unified_audit_detection.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_121_user_name, 12.1)

```sql
SELECT CASE WHEN policy_name LIKE 'ORA\_%' ESCAPE '\' OR policy_name LIKE 'ORA$%' THEN policy_name ELSE 'CUSTOM' END AS policy_name,
       CASE WHEN user_name = 'ALL USERS' THEN 'ALL_USERS' ELSE 'SPECIFIC' END AS entity_scope,
       success, failure,
       COUNT(*) AS entity_count
FROM   audit_unified_enabled_policies
GROUP  BY CASE WHEN policy_name LIKE 'ORA\_%' ESCAPE '\' OR policy_name LIKE 'ORA$%' THEN policy_name ELSE 'CUSTOM' END,
          CASE WHEN user_name = 'ALL USERS' THEN 'ALL_USERS' ELSE 'SPECIFIC' END,
          success, failure
ORDER  BY 1, 2;
```

# Statement / procedure (read-only) — Variant V2 (entity_122plus, 12.2+)

```sql
SELECT CASE WHEN policy_name LIKE 'ORA\_%' ESCAPE '\' OR policy_name LIKE 'ORA$%' THEN policy_name ELSE 'CUSTOM' END AS policy_name,
       entity_type,
       CASE WHEN entity_name = 'ALL USERS' THEN 'ALL_USERS' ELSE 'SPECIFIC' END AS entity_scope,
       success, failure,
       COUNT(*) AS entity_count
FROM   audit_unified_enabled_policies
GROUP  BY CASE WHEN policy_name LIKE 'ORA\_%' ESCAPE '\' OR policy_name LIKE 'ORA$%' THEN policy_name ELSE 'CUSTOM' END, entity_type,
          CASE WHEN entity_name = 'ALL USERS' THEN 'ALL_USERS' ELSE 'SPECIFIC' END,
          success, failure
ORDER  BY 1, 2, 3;
```

# Notes by version

`AUDIT_UNIFIED_ENABLED_POLICIES` verificada disponible desde 12.1 (WebFetch/WebSearch) — no
existe en 10g/11g. En esas versiones, `security/unified-auditing` publica `capability_status:
UNSUPPORTED`, `security/traditional-auditing` es la vía de auditoría certificada.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW` — poblada sólo cuando Unified Auditing está habilitado, típicamente pocas políticas.

# License notes

Ninguna.

# Sanitization notes

`entity_name` → MASK por defecto salvo usuario Oracle-maintained conocido.

# Evolution via `/change query`

N/A.

2.0.0 CHG-ESTACK-PDB-COVERAGE-001: Dos variantes: 12.1 tiene `USER_NAME`/`ENABLED_OPT`; desde 12.2 `ENTITY_NAME`/`ENTITY_TYPE`/`ENABLED_OPTION` (Oracle Database Reference 18c y 19c; la 1.0.0 usaba `entity_name` para 12.1 y fallaba). Las políticas propias salen como `CUSTOM`: solo se expone el nombre de las mantenidas por Oracle (`ORA_*`, `ORA$*`). Usuarios y roles no se exponen: solo si la política aplica a todos (`ALL_USERS`) o a entidades específicas, y cuántas. Alcance: el contenedor actual (no hay vista `CDB_*`).

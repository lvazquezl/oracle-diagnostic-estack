---
query_id: Q-SEC-PASSWORD-VERSIONS-001
version: 2.0.0

domain: security
purpose: >
  Awareness de tipo de verifier de password (legacy/modern) por cuenta, nunca contenido — password-verifiers (# 25, # 26 del prompt de Fase 8).

supported_oracle_versions: [11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [DBA_USERS, CDB_USERS]
privileges_required: [SELECT on DBA_USERS, SELECT on CDB_USERS]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 500
max_output_bytes: 65536

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-PASSWORD-VERSIONS-001-V1
    label: legacy_11g
    oracle_versions: {min: "11.1", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_11g, 11.1–11.2: DBA_USERS, conteo por versión de verificador)"
  - variant_id: Q-SEC-PASSWORD-VERSIONS-001-V2
    label: cdb_aware_121
    oracle_versions: {min: "12.1", max: "12.1.0.1"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_121, 12.1–12.1.0.1: CDB_USERS con con_id)"
  - variant_id: Q-SEC-PASSWORD-VERSIONS-001-V3
    label: cdb_aware_12102plus
    oracle_versions: {min: "12.1.0.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V3 (cdb_aware_12102plus, 12.1.0.2–23.0: CDB_USERS con oracle_maintained)"

tests: [tests/test_no_write_operations.sh, tests/test_no_password_verifier_exposure.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_11g, 11.1–11.2: DBA_USERS, conteo por versión de verificador)

```sql
SELECT CASE WHEN TRIM(password_versions) IN ('10G', '11G', '12C', '10G 11G', '10G 12C', '11G 12C', '10G 11G 12C') THEN TRIM(password_versions) ELSE 'OTHER' END AS password_versions, COUNT(*) AS account_count
FROM   dba_users
WHERE  password_versions IS NOT NULL
GROUP  BY CASE WHEN TRIM(password_versions) IN ('10G', '11G', '12C', '10G 11G', '10G 12C', '11G 12C', '10G 11G 12C') THEN TRIM(password_versions) ELSE 'OTHER' END
ORDER  BY 1;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_121, 12.1–12.1.0.1: CDB_USERS con con_id)

```sql
SELECT con_id, CASE WHEN TRIM(password_versions) IN ('10G', '11G', '12C', '10G 11G', '10G 12C', '11G 12C', '10G 11G 12C') THEN TRIM(password_versions) ELSE 'OTHER' END AS password_versions, COUNT(*) AS account_count
FROM   cdb_users
WHERE  password_versions IS NOT NULL
GROUP  BY con_id, CASE WHEN TRIM(password_versions) IN ('10G', '11G', '12C', '10G 11G', '10G 12C', '11G 12C', '10G 11G 12C') THEN TRIM(password_versions) ELSE 'OTHER' END
ORDER  BY 1, 2;
```

# Statement / procedure (read-only) — Variant V3 (cdb_aware_12102plus, 12.1.0.2–23.0: CDB_USERS con oracle_maintained)

```sql
SELECT con_id, oracle_maintained, CASE WHEN TRIM(password_versions) IN ('10G', '11G', '12C', '10G 11G', '10G 12C', '11G 12C', '10G 11G 12C') THEN TRIM(password_versions) ELSE 'OTHER' END AS password_versions, COUNT(*) AS account_count
FROM   cdb_users
WHERE  password_versions IS NOT NULL
GROUP  BY con_id, oracle_maintained, CASE WHEN TRIM(password_versions) IN ('10G', '11G', '12C', '10G 11G', '10G 12C', '11G 12C', '10G 11G 12C') THEN TRIM(password_versions) ELSE 'OTHER' END
ORDER  BY 1, 2, 3;
```

# Notes by version

`PASSWORD_VERSIONS` existe desde 11.1 (catálogo: 11.2); `ORACLE_MAINTAINED` desde 12.1.0.2.

# Notes by platform

Ninguna.

# Container / role scope notes

V2/V3 cubren los contenedores visibles por `CONTAINER_DATA`.

# Cost classification rationale

`LOW`.

# License notes

Ninguna.

# Sanitization notes

Solo conteos por combinación de verificadores (enum cerrado). Ningún usuario ni verificador sale de la base.

# Evolution via `/change query`

N/A.

2.0.0 CHG-ESTACK-B7-SECURITY-COVERAGE-001: 2.0.0: conteo agregado sin usuarios; `CDB_USERS` por contenedor.

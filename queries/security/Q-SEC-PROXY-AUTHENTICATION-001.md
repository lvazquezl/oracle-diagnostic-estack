---
query_id: Q-SEC-PROXY-AUTHENTICATION-001
version: 3.0.0

domain: security
purpose: Proxy authentication awareness (CONNECT THROUGH) — nunca credenciales (# 118 del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [PROXY_USERS, DBA_USERS]
privileges_required: [SELECT on PROXY_USERS, SELECT on DBA_USERS]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 200
max_output_bytes: 65536

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

# CHG-ESTACK-ORA19C-LAB-007: authorization_constraint no existe; la amplitud de roles activables está en FLAGS
# (Reference 11.2 y 19c). FLAGS no se pudo verificar en 10.2 → variante sin FLAGS por debajo de 11.2.
variants:
  - variant_id: Q-SEC-PROXY-AUTHENTICATION-001-V1
    label: legacy_pre112
    oracle_versions: {min: "10.2", max: "11.1"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_pre112)"
  - variant_id: Q-SEC-PROXY-AUTHENTICATION-001-V2
    label: flags_112
    oracle_versions: {min: "11.2", max: "12.1.0.1"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (flags_112_to_12101)"
  - variant_id: Q-SEC-PROXY-AUTHENTICATION-001-V3
    label: oracle_maintained_12102plus
    oracle_versions: {min: "12.1.0.2", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V3 (oracle_maintained_12102plus)"

tests: [tests/test_no_write_operations.sh, tests/test_security_admin_privileges.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_pre112)

```sql
SELECT proxy, client, authentication
FROM   proxy_users
ORDER  BY proxy, client;
```

# Statement / procedure (read-only) — Variant V2 (flags_112_to_12101)

```sql
SELECT proxy, client, authentication, flags
FROM   proxy_users
ORDER  BY proxy, client;
```

# Statement / procedure (read-only) — Variant V3 (oracle_maintained_12102plus)

```sql
SELECT p.proxy, pu.oracle_maintained AS proxy_oracle_maintained,
       p.client, cu.oracle_maintained AS client_oracle_maintained,
       p.authentication, p.flags
FROM   proxy_users p
LEFT   JOIN dba_users pu ON pu.username = p.proxy
LEFT   JOIN dba_users cu ON cu.username = p.client
ORDER  BY p.proxy, p.client;
```

**2.0.0 (`CHG-ESTACK-ORA19C-LAB-007`, breaking):** `authorization_constraint` no existe en `PROXY_USERS` (Reference 11.2 y 19c; confirmado en Oracle real por `Q-DICT-VERIFY`); la versión 1.0.0 fallaba con `ORA-00904`. El dato que la skill necesita (`PROXY MAY ACTIVATE ALL CLIENT ROLES` y afines) está en `FLAGS`. Por debajo de 11.2 no se afirma que exista: V1 no la selecciona y la skill reporta la amplitud como no disponible.

# Notes by version

`PROXY_USERS` estable desde versiones antiguas (proxy authentication vía OCI existe desde 9i) —
certificado desde 10g (mínimo soportado por el catálogo).

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW`.

# License notes

Ninguna.

# Sanitization notes

`proxy`/`client` → MASK por defecto.

# Evolution via `/change query`

N/A.

3.0.0 CHG-ESTACK-ASSESSMENT-ACCURACY-001: V3 (12.1.0.2+, donde `DBA_USERS.ORACLE_MAINTAINED` existe) agrega `oracle_maintained` del proxy y del cliente (`DBA_USERS`): sin eso no se podía saber si una relación con `PROXY MAY ACTIVATE ALL CLIENT ROLES` involucra cuentas propias (FND-0004 de ANA-20261007-001). Alcance: el contenedor de la sesión (`PROXY_USERS` no tiene vista `CDB_*`).

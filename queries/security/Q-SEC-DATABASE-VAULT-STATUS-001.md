---
query_id: Q-SEC-DATABASE-VAULT-STATUS-001
version: 2.0.0

domain: security
purpose: >
  Instalado/habilitado de Oracle Database Vault — siempre licensing-gated, nunca modifica (# 39
  del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$OPTION, DBA_REGISTRY]
privileges_required: [SELECT on V$OPTION, SELECT on DBA_REGISTRY]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 5
max_output_bytes: 8192

sensitivity: LOW
sanitization_required: false

license_requirements: "Oracle Database Vault — SEPARATELY_LICENSED salvo confirmación explícita del DBA"

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_no_database_vault_change.sh, tests/test_database_vault_awareness.sh, tests/test_security_licensing_gate.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT (SELECT value  FROM v$option    WHERE parameter = 'Oracle Database Vault') AS dv_option,
       (SELECT status FROM dba_registry WHERE comp_id   = 'DV')                    AS dv_registry_status
FROM   dual;
```

`dv_option` = `TRUE` cuando Database Vault está habilitado; `dv_registry_status` dice si el componente está instalado y en qué estado (`VALID`, `INVALID`…; nulo si no está instalado). Ya no consulta `DBA_DV_STATUS`, que sólo existe con Database Vault instalado y exige roles de DV: la 1.0.0 tenía dos sentencias y no resolvía.

# Notes by version

`V$OPTION` estable desde versiones muy tempranas. Database Vault disponible desde 10g Release 2
en adelante como opción separadamente licenciada.

# Notes by platform

Ninguna.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW`.

# License notes

`SEPARATELY_LICENSED` por defecto — `security/licensing-gates` nunca reporta `INCLUDED` sin
confirmación explícita del DBA en el Target Profile (`licensing_profile`).

# Sanitization notes

Ninguna — sólo booleanos/enums de configuración.

# Evolution via `/change query`

CHG-ESTACK-SEC-QUERIES-001 — 2.0.0: una sola sentencia sobre `V$OPTION` y `DBA_REGISTRY`, válida con o sin Database Vault instalado.

N/A.

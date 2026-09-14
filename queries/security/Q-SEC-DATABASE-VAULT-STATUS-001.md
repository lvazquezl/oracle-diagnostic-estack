---
query_id: Q-SEC-DATABASE-VAULT-STATUS-001
version: 1.0.0

domain: security
purpose: >
  Instalado/habilitado de Oracle Database Vault — siempre licensing-gated, nunca modifica (# 39
  del prompt de Fase 8).

supported_oracle_versions: [10g, 11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$OPTION, DBA_DV_STATUS]
privileges_required: [SELECT on V$OPTION, SELECT on DBA_DV_STATUS si está instalado]

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
SELECT value
FROM   v$option
WHERE  parameter = 'Oracle Database Vault';
```

Sólo si el resultado es `TRUE`, `security/database-vault-awareness` intenta opcionalmente:

```sql
SELECT status
FROM   dba_dv_status
WHERE  ROWNUM = 1;
```

`DBA_DV_STATUS` sólo existe cuando Database Vault está instalado — nunca se consulta sin
confirmar primero `V$OPTION`. `PARAMETER = 'Oracle Database Vault'` es el string exacto
verificado (case-sensitive, WebSearch).

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

N/A.

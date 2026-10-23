---
query_id: Q-SEC-TDE-WALLET-001
version: 2.0.0

domain: security
purpose: Estado de wallet/keystore de TDE — tde-awareness/keystore-awareness (# 31, # 32 del prompt de Fase 8).

supported_oracle_versions: [11g, 12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$ENCRYPTION_WALLET]
privileges_required: [SELECT on V$ENCRYPTION_WALLET]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 10
max_output_bytes: 16384

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-TDE-WALLET-001-V1
    label: legacy_11g
    oracle_versions: {min: "11.2", max: "11.2"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (legacy_11g, 11.2–11.2: V$ENCRYPTION_WALLET)"
  - variant_id: Q-SEC-TDE-WALLET-001-V2
    label: cdb_aware_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V2 (cdb_aware_12plus, 12.1–23.0: V$ENCRYPTION_WALLET con con_id y tipo de keystore)"

tests: [tests/test_no_write_operations.sh, tests/test_no_keystore_change.sh, tests/test_tde_awareness.sh, tests/test_keystore_awareness.sh, tests/test_no_wallet_secret_exposure.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (legacy_11g, 11.2–11.2: V$ENCRYPTION_WALLET)

```sql
SELECT wrl_type, status
FROM   v$encryption_wallet;
```

# Statement / procedure (read-only) — Variant V2 (cdb_aware_12plus, 12.1–23.0: V$ENCRYPTION_WALLET con con_id y tipo de keystore)

```sql
SELECT con_id, wrl_type, status, wallet_type, wallet_order, fully_backed_up
FROM   v$encryption_wallet
ORDER  BY con_id;
```

# Notes by version

`WALLET_TYPE`, `WALLET_ORDER`, `FULLY_BACKED_UP` y `CON_ID` existen desde 12.1.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

V2 devuelve una fila por contenedor (root y PDB visibles).

# Cost classification rationale

`LOW` — una sola fila.

# License notes

TDE requiere Advanced Security Option en versiones donde no está incluido en Enterprise Edition
base — `security/licensing-gates` reporta el status correspondiente, nunca asumido `INCLUDED`.

# Sanitization notes

`wrl_parameter` (ruta del keystore) nunca se selecciona: DROP en la base. Solo tipo, estado y orden del keystore, todos enums. Nunca se lee contraseña ni material de llave.

# Evolution via `/change query`

N/A.

2.0.0 CHG-ESTACK-B7-SECURITY-COVERAGE-001: 2.0.0: sin `wrl_parameter`; `wrl_type`, `wallet_order`, `fully_backed_up` y `con_id`.

---
query_id: Q-SEC-TDE-MASTER-KEYS-001
version: 1.0.0

domain: security
purpose: Llaves maestras de TDE por contenedor, solo conteos y antigüedad de la llave activa — postura TDE (rotación y respaldo).

supported_oracle_versions: [12c, 18c, 19c, 21c, 23ai]
supported_os: [todas]
supported_architectures: [Standalone, RAC]

container_scope: ANY_CONTAINER
database_role_scope: ANY

objects_accessed: [V$ENCRYPTION_KEYS]
privileges_required: [SELECT on V$ENCRYPTION_KEYS]

risk_class: R0
cost_class: LOW

timeout_seconds: 10
max_rows: 50
max_output_bytes: 16384

sensitivity: LOW
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

variants:
  - variant_id: Q-SEC-TDE-MASTER-KEYS-001-V1
    label: cdb_aware_12plus
    oracle_versions: {min: "12.1", max: "23.0"}
    container_scope: ANY_CONTAINER
    sql_block: "Variant V1 (cdb_aware_12plus, 12.1–23.0: V$ENCRYPTION_KEYS agregada por contenedor)"

tests: [tests/test_no_write_operations.sh, tests/test_no_keystore_change.sh, tests/test_no_wallet_secret_exposure.sh, tests/test_tde_posture.sh]
status: active
---

# Statement / procedure (read-only) — Variant V1 (cdb_aware_12plus, 12.1–23.0: V$ENCRYPTION_KEYS agregada por contenedor)

```sql
SELECT con_id, COUNT(*) AS master_keys,
       SUM(CASE WHEN backed_up = 'NO' THEN 1 ELSE 0 END) AS keys_not_backed_up,
       ROUND((CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) - CAST(SYS_EXTRACT_UTC(MAX(activation_time)) AS DATE)) * 24, 1) AS hours_since_last_activation
FROM   v$encryption_keys
GROUP  BY con_id
ORDER  BY con_id;
```

# Notes by version

`V$ENCRYPTION_KEYS` existe desde 12.1. En 11.2 el collector es `UNSUPPORTED`; la postura TDE usa solo `Q-SEC-TDE-WALLET-001`.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

Una fila por contenedor con llaves visibles en el keystore. Sin filas: no hay llaves maestras visibles (TDE no configurado o keystore cerrado); la postura se decide junto con `Q-SEC-TDE-WALLET-001`.

# Cost classification rationale

`LOW` — una fila por llave antes de agregar.

# License notes

Leer el estado del keystore y sus llaves no usa la opción. Usar TDE (cifrar datos) requiere Advanced Security Option fuera de los servicios cloud de Oracle que lo incluyen; la postura lo reporta como `LICENSE_REVIEW`, nunca asume el derecho de uso.

# Sanitization notes

`key_id`, `tag`, los datos del creador y las fechas nunca salen de la base: solo conteos por contenedor y las horas desde la activación de la llave más reciente. Nunca se lee material de llave ni la contraseña del keystore.

# Evolution via `/change query`

1.0.0 CHG-ESTACK-TDE-POSTURE-001: creación (postura TDE: rotación y respaldo de llaves maestras).

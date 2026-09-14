---
query_id: Q-SEC-TDE-WALLET-001
version: 1.0.0

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

sensitivity: MEDIUM
sanitization_required: true

license_requirements: none

execution_mode: READ_ONLY

tests: [tests/test_no_write_operations.sh, tests/test_no_keystore_change.sh, tests/test_tde_awareness.sh, tests/test_keystore_awareness.sh, tests/test_no_wallet_secret_exposure.sh]
status: active
---

# Statement / procedure (read-only)

```sql
SELECT wrl_parameter, status, wallet_type
FROM   v$encryption_wallet;
```

`wrl_parameter` es el path de configuración del wallet, nunca su contenido/password — se
sanitiza (`MASK`) antes de reportarse, igual que `snapshot_controlfile_path` en RMAN (Fase 7).
Nunca se selecciona ninguna columna con contenido de clave.

# Notes by version

`V$ENCRYPTION_WALLET` verificada disponible desde 11.2 (WebSearch) — en 10g/11.1, `security/
tde-awareness` publica `capability_status: UNSUPPORTED`.

# Notes by platform

Ninguna — SQL puro.

# Container / role scope notes

`ANY_CONTAINER`.

# Cost classification rationale

`LOW` — una sola fila.

# License notes

TDE requiere Advanced Security Option en versiones donde no está incluido en Enterprise Edition
base — `security/licensing-gates` reporta el status correspondiente, nunca asumido `INCLUDED`.

# Sanitization notes

`wrl_parameter` → MASK (path de filesystem, puede revelar convención interna). Nunca se expone
wallet password ni key material — no existe columna con ese contenido en esta vista de todas
formas.

# Evolution via `/change query`

N/A.

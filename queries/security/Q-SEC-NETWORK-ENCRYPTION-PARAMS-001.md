---
query_id: Q-SEC-NETWORK-ENCRYPTION-PARAMS-001
version: 2.0.0

domain: security
status: not_certified
not_certified_reason: INCORRECT_EVIDENCE_SOURCE
not_certified_since: "PHASE 8 — SECURITY QUERY COMPATIBILITY, ORACLE NET EVIDENCE & STATIC VALIDATOR HARDENING"
purpose: >
  RETIRADA — nunca certificar ni ejecutar. `SQLNET.ENCRYPTION_*`/`SQLNET.CRYPTO_CHECKSUM_*` son
  configuración de Oracle Net (`sqlnet.ora`), NUNCA parámetros de inicialización de instancia —
  `V$PARAMETER` no los expone salvo que un DBA los haya replicado manualmente como parámetro
  (comportamiento no garantizado, no certificable). Reemplazada por el collector semántico
  `get_oracle_net_security_configuration`, propiedad de `oracle-network-analyst` — ver
  `skills/network/oracle-net-security/SKILL.md` y
  `docs/PHASE_8_SECURITY_QUERY_ORACLE_NET_STATIC_VALIDATOR_HARDENING.md`. Este archivo se
  conserva únicamente como registro histórico del defecto corregido (# 24-26 del prompt de
  hardening) — no referenciado por ningún skill activo.

supported_oracle_versions: []
supported_os: []
supported_architectures: []

container_scope: NOT_APPLICABLE
database_role_scope: NOT_APPLICABLE

objects_accessed: []
privileges_required: []

risk_class: R0
cost_class: LOW

timeout_seconds: 0
max_rows: 0
max_output_bytes: 0

sensitivity: LOW
sanitization_required: false

license_requirements: none

execution_mode: NOT_EXECUTABLE

tests: []
---

# Statement / procedure — RETIRADA, nunca ejecutada

```text
-- NOT_CERTIFIED — conservado únicamente como evidencia histórica del defecto real corregido.
-- El SQL original (abajo, en bloque de texto — deliberadamente NO un bloque ```sql para que
-- ningún test/validador lo trate como una sentencia certificada) asumía incorrectamente que
-- SQLNET.* es un parámetro de instancia:
--
-- SELECT name, value
-- FROM   v$parameter
-- WHERE  name IN ('sqlnet.encryption_client', 'sqlnet.encryption_server',
--                 'sqlnet.crypto_checksum_client', 'sqlnet.crypto_checksum_server')
-- ORDER  BY name;
```

# Causa raíz del defecto (PHASE 8 — ORACLE NET EVIDENCE HARDENING)

`SQLNET.ENCRYPTION_*`/`SQLNET.CRYPTO_CHECKSUM_*` son configuración de **Oracle Net**
(`sqlnet.ora`), no parámetros de inicialización de instancia — `V$PARAMETER` refleja
`init.ora`/`spfile`, nunca `sqlnet.ora`. Una fila `SQLNET.*` en `V$PARAMETER` sólo aparecería si
un DBA la hubiera replicado manualmente ahí, un comportamiento no garantizado y por tanto no
certificable como fuente de evidencia. Esta era exactamente el defecto que el hardening debía
detectar (principio no-negociable: "SQLNET.\* IS NOT V\$PARAMETER EVIDENCE").

# Reemplazo

`security/network-encryption` y `security/tls-awareness` consumen ahora el collector semántico
`get_oracle_net_security_configuration` (`network/oracle-net-security`, propiedad de
`oracle-network-analyst`) — ver
`docs/PHASE_8_SECURITY_QUERY_ORACLE_NET_STATIC_VALIDATOR_HARDENING.md`.

# Evolution via `/change query`

N/A — archivo retirado, no evoluciona.

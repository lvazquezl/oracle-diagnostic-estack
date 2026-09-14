---
name: tde-awareness
id: security/tde-awareness
version: 1.0.0
domain: security
status: active
---

# Purpose

Analiza disponibilidad de TDE, tablespaces/columnas encriptadas, posture de key/keystore — nunca
ejecuta `OPEN/CLOSE KEYSTORE`, `SET KEY`, `ROTATE KEY`, `CREATE KEYSTORE` (`# 31` del prompt de
Fase 8).

# Supported Oracle versions

10g–23ai (wallet awareness 11.2+; column encryption 10.2+).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-SEC-TDE-WALLET-001`
- `Q-SEC-ENCRYPTED-COLUMNS-001`

# Optional evidence

`security/tablespace-encryption`, `security/keystore-awareness`.

# Licensing requirements

Advanced Security Option donde aplique — `security/licensing-gates` reporta el status.

# Query IDs

`Q-SEC-TDE-WALLET-001`, `Q-SEC-ENCRYPTED-COLUMNS-001`.

# Collector IDs

`get_tde_status`.

# Read-only operations

Lectura de `V$ENCRYPTION_WALLET`/`DBA_ENCRYPTED_COLUMNS`.

# Forbidden operations

Nunca `ADMINISTER KEY MANAGEMENT` en ninguna variante.

# Decision logic

1. En 10g (column encryption) sin wallet (11.2+) → `tde.available: true` (column-level),
   `wallet_state: NOT_APPLICABLE`.
2. En 10g/11.1 (sin `V$ENCRYPTION_WALLET`) → `capability_status: UNSUPPORTED` para
   tablespace-level TDE.
3. Nunca expone wallet password ni key material.

# Normal state

Wallet `OPEN` en instancias con TDE habilitado.

# Abnormal patterns

Wallet `CLOSED` en una instancia con tablespaces/columnas encriptadas — TDE efectivamente
inoperante.

# False positives

Ninguno — el estado del wallet es determinístico.

# Correlation rules

Integra con `security/keystore-awareness`, `security/tablespace-encryption`. Alimenta
`security/security-healthcheck`, `security/compliance-mapping`.

# Confidence model

`FACT`.

# Severity

`CRITICAL` si wallet `CLOSED` con datos sensibles esperados encriptados (política del cliente).

# Output schema

```yaml
tde:
  available: bool
  wallet_state: OPEN|CLOSED|OPEN_NO_MASTER_KEY|UNKNOWN|NOT_APPLICABLE
  encrypted_tablespaces: [{tablespace_token: string, encryption_algorithm: string|null}]
  encrypted_columns: [{table_token: string, column_token: string, encryption_algorithm: string|null}]
  evidence_refs: [EVD-...]
```

# Related skills

`security/keystore-awareness`, `security/tablespace-encryption`, `security/licensing-gates`.

# Escalation

Wallet `CLOSED` en producción con TDE esperado activo → `incident-root-cause-analyst`.

# Manual remediation guidance

`manual_action` sugiere `ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY ...` — siempre
`NOT_EXECUTED`, nunca la password del wallet se solicita/almacena.

# Security

`wrl_parameter` (path) → MASK. Nunca wallet password/key material.

# Tests

`tests/test_tde_awareness.sh`, `tests/test_no_keystore_change.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/encryption-posture.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

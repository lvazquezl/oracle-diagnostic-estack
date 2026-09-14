---
name: keystore-awareness
id: security/keystore-awareness
version: 1.0.0
domain: security
status: active
---

# Purpose

Awareness de tipo/estado de keystore sin exponer secretos — `keystore.secrets_exposed` siempre
`false` por diseño de schema (`# 32` del prompt de Fase 8).

# Supported Oracle versions

11g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`security/tde-awareness` ya ejecutado.

# Required evidence

- evidencia de `Q-SEC-TDE-WALLET-001`

# Optional evidence

Ninguna.

# Licensing requirements

Advanced Security Option donde aplique.

# Query IDs

`Q-SEC-TDE-WALLET-001`.

# Collector IDs

Ninguno — deriva de `tde-awareness`.

# Read-only operations

Ninguna adicional.

# Forbidden operations

Nunca abre/cierra keystore, nunca rota claves, nunca crea keystore.

# Decision logic

1. `wallet_type` mapea a `type: SOFTWARE|HSM|UNKNOWN`.
2. `auto_login` se infiere del `wallet_type` reportado (ej. `AUTOLOGIN`) cuando la vista lo
   distingue.
3. `secrets_exposed` es literalmente `false` en el schema — no existe ningún campo que pudiera
   exponer contenido de key material.

# Normal state

Keystore `OPEN`, tipo consistente con la arquitectura declarada por el DBA (software wallet o
HSM).

# Abnormal patterns

Keystore tipo `UNKNOWN` en una instancia con TDE activo — indica configuración no reconocible.

# False positives

Ninguno.

# Correlation rules

Consume `security/tde-awareness`. Alimenta `security/security-healthcheck`.

# Confidence model

`FACT`.

# Severity

Igual que `tde-awareness` para el estado del keystore.

# Output schema

```yaml
keystore:
  type: SOFTWARE|HSM|UNKNOWN|NOT_APPLICABLE
  status: OPEN|CLOSED|UNKNOWN
  auto_login: bool|null
  secrets_exposed: false
  evidence_refs: [EVD-...]
```

# Related skills

`security/tde-awareness`.

# Escalation

Ver `security/tde-awareness`.

# Manual remediation guidance

Ver `security/tde-awareness`.

# Security

`secrets_exposed: false` por diseño — nunca se recolecta wallet password/key material en ningún
punto del flujo.

# Tests

`tests/test_keystore_awareness.sh`, `tests/test_no_wallet_secret_exposure.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/encryption-posture.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

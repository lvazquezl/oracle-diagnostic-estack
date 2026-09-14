---
name: external-authentication
id: security/external-authentication
version: 1.0.0
domain: security
status: active
---

# Purpose

Distingue `PASSWORD|EXTERNAL|GLOBAL|NONE` — cuentas no autenticadas por password publican
`PASSWORD_POLICY_STATUS: NOT_APPLICABLE`, nunca marcadas non-compliant por no tener verify
function (`# 22` del prompt de Fase 8).

# Supported Oracle versions

11.2–23ai (`AUTHENTICATION_TYPE` es 11.2+).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`security/account-inventory` ya ejecutado.

# Required evidence

- evidencia ya recolectada por `security/account-inventory` (`authentication_type`)

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

Ninguna directa — deriva de `Q-SEC-ACCOUNT-INVENTORY-001`.

# Collector IDs

Ninguno.

# Read-only operations

Ninguna adicional.

# Forbidden operations

Nunca cambia el mecanismo de autenticación de una cuenta.

# Decision logic

1. `authentication_type = EXTERNAL|GLOBAL|NONE` → `password_policy_applicable: false`,
   `NOT_APPLICABLE` explícito, nunca non-compliant por ausencia de política de password.
2. En versión < 11.2 donde `authentication_type` no existe, `capability_status: UNSUPPORTED`.
3. `NONE` (18c+, schema-only accounts) se distingue explícitamente de `EXTERNAL`.

# Normal state

Mayoría `PASSWORD`; `EXTERNAL`/`GLOBAL` en integraciones con Kerberos/LDAP/Active Directory
conocidas.

# Abnormal patterns

Cuenta `NONE` (schema-only) esperada para tener sólo objetos, no login — si tiene login
histórico reciente, es una anomalía a investigar.

# False positives

`EXTERNAL`/`GLOBAL` no es en sí un riesgo — es una decisión arquitectónica del cliente
(autenticación centralizada).

# Correlation rules

Alimenta `security/password-policy-strength` (para exclusión correcta), `security/proxy-authentication`.

# Confidence model

`FACT`.

# Severity

Informativo — no genera severidad por sí solo.

# Output schema

```yaml
external_authentication:
  - user_token: string
    authentication_type: PASSWORD|EXTERNAL|GLOBAL|NONE
    password_policy_applicable: bool
    evidence_refs: [EVD-...]
```

# Related skills

`security/account-inventory`, `security/password-policy-strength`, `security/proxy-authentication`.

# Escalation

Ninguna directa.

# Manual remediation guidance

N/A.

# Security

`user_token` → MASK por defecto.

# Tests

`tests/test_password_policy_external_user_not_applicable.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/accounts.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

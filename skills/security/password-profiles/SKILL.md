---
name: password-profiles
id: security/password-profiles
version: 1.0.0
domain: security
status: active
---

# Purpose

Analiza parámetros de password/account policy por profile (`FAILED_LOGIN_ATTEMPTS,
PASSWORD_LIFE_TIME, PASSWORD_REUSE_TIME, PASSWORD_REUSE_MAX, PASSWORD_LOCK_TIME,
PASSWORD_GRACE_TIME, PASSWORD_VERIFY_FUNCTION, INACTIVE_ACCOUNT_TIME`) — nunca inseguro sin
policy/compliance target (`# 14` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai (`INACTIVE_ACCOUNT_TIME` sólo 12.2+).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-SEC-PASSWORD-PROFILES-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-SEC-PASSWORD-PROFILES-001`.

# Collector IDs

`get_password_profiles`.

# Read-only operations

Lectura de `DBA_PROFILES`.

# Forbidden operations

Nunca ejecuta `ALTER PROFILE`.

# Decision logic

1. Reporta cada `resource_name`/`limit` sin evaluar compliance aquí — eso es
   `security/password-policy-strength`.
2. `inactive_account_time: NOT_AVAILABLE` en versión < 12.2, nunca `UNLIMITED` inventado.

# Normal state

Profiles con límites configurados (no todos `UNLIMITED`/`DEFAULT`).

# Abnormal patterns

Todos los profiles en `UNLIMITED` para `FAILED_LOGIN_ATTEMPTS`/`PASSWORD_LIFE_TIME`.

# False positives

Ninguno — este skill es puramente descriptivo, la evaluación de compliance está en
`password-policy-strength`.

# Correlation rules

Alimenta `security/password-policy-strength`, `security/password-complexity`.

# Confidence model

`FACT`.

# Severity

Informativo — severidad se evalúa en `password-policy-strength`.

# Output schema

```yaml
password_profile_posture:
  - profile_token: string
    failed_login_attempts: string|null
    password_life_time: string|null
    password_reuse_time: string|null
    password_reuse_max: string|null
    password_lock_time: string|null
    password_grace_time: string|null
    password_verify_function: string|null
    inactive_account_time: string|null
    evidence_refs: [EVD-...]
```

# Related skills

`security/password-policy-strength`, `security/password-complexity`, `security/password-verify-function`.

# Escalation

Ninguna directa.

# Manual remediation guidance

N/A — descriptivo.

# Security

`profile_token` → KEEP (metadata de configuración).

# Tests

`tests/test_security_password_profiles.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/password-profile.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

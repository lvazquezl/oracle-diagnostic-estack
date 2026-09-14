---
name: stale-accounts
id: security/stale-accounts
version: 1.0.0
domain: security
status: active
---

# Purpose

Identifica cuentas inactivas — sólo si existe política/umbral explícito. Sin política:
`INSUFFICIENT_POLICY`, nunca inventa un umbral como "90 días" (`# 9` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai (`last_login` sólo 12.1+; en versiones anteriores, `INSUFFICIENT_EVIDENCE`).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`security/account-inventory` ya ejecutado. Requiere `Target Profile.security.account_inactivity_policy_days` (`# 52` del prompt) o instrucción explícita del DBA.

# Required evidence

- `Q-SEC-ACCOUNT-INVENTORY-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-SEC-ACCOUNT-INVENTORY-001`.

# Collector IDs

Ninguno — deriva de `account-inventory`.

# Read-only operations

Ninguna adicional.

# Forbidden operations

Nunca bloquea cuentas automáticamente.

# Decision logic

1. `Target Profile.security.account_inactivity_policy_days` presente → `policy_status: EVALUATED`, calcula `days_inactive` desde `last_login`.
2. Ausente → `policy_status: INSUFFICIENT_POLICY`, `threshold_days: null`, la lista de `accounts` queda vacía — nunca se inventa un umbral por defecto.
3. `last_login: null` (10g/11g) → `days_inactive: null`, cuenta reportada con `INSUFFICIENT_EVIDENCE` individual, nunca asumida stale ni activa.

# Normal state

`policy_status: INSUFFICIENT_POLICY` es un estado normal y esperado sin política definida — no
es un error del skill.

# Abnormal patterns

Cuentas con `days_inactive` muy superior al `threshold_days` definido, con privilegios
administrativos.

# False positives

Cuenta de servicio/batch con conexión infrecuente pero legítima (ej. job mensual) — el DBA debe
confirmar antes de recomendar bloqueo.

# Correlation rules

Alimenta `security/security-healthcheck`, `security/compliance-mapping`.

# Confidence model

`FACT` para `days_inactive` calculado. `INSUFFICIENT_EVIDENCE`/`INSUFFICIENT_POLICY` son estados
explícitos, no una degradación de confianza genérica.

# Severity

`MEDIUM` para cuenta stale sin privilegios administrativos, `HIGH` con privilegios
administrativos.

# Output schema

```yaml
stale_accounts:
  policy_status: INSUFFICIENT_POLICY|EVALUATED
  threshold_days: int|null
  accounts: [{user_token: string, last_login: string|null, days_inactive: int|null}]
  evidence_refs: [EVD-...]
```

# Related skills

`security/account-inventory`, `security/account-status`.

# Escalation

Cuenta administrativa stale por encima del umbral → finding, nunca acción automática.

# Manual remediation guidance

`manual_action` sugiere revisión/bloqueo manual tras confirmación de no-uso por el DBA — siempre
`NOT_EXECUTED`.

# Security

`user_token` → MASK por defecto.

# Tests

`tests/test_security_stale_account_policy.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/accounts.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

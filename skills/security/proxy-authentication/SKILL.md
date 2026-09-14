---
name: proxy-authentication
id: security/proxy-authentication
version: 1.0.0
domain: security
status: active
---

# Purpose

Proxy authentication awareness (CONNECT THROUGH) — nunca credenciales (`# 118` del prompt de
Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-SEC-PROXY-AUTHENTICATION-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-SEC-PROXY-AUTHENTICATION-001`.

# Collector IDs

`get_proxy_authentication`.

# Read-only operations

Lectura de `PROXY_USERS`.

# Forbidden operations

Nunca otorga/revoca `CONNECT THROUGH`.

# Decision logic

1. Relación `proxy`/`client` se reporta tal cual — nunca inferida.
2. `authorization_constraint` se evalúa para detectar `PROXY MAY ACTIVATE ALL CLIENT ROLES`
   (amplitud máxima de rol activable) vs. constraint más restrictivo.

# Normal state

Un número reducido de relaciones proxy/client documentadas (ej. middleware de aplicación).

# Abnormal patterns

Proxy con `PROXY MAY ACTIVATE ALL CLIENT ROLES` hacia una cuenta administrativa.

# False positives

Middleware de aplicación conocido con proxy hacia cuentas de servicio no es anómalo.

# Correlation rules

Alimenta `security/security-healthcheck`.

# Confidence model

`FACT`.

# Severity

`MEDIUM`/`HIGH` según amplitud de `authorization_constraint` y privilegios del `client`.

# Output schema

```yaml
proxy_authentication:
  - proxy_token: string
    client_token: string
    authentication: string
    authorization_constraint: string
    evidence_refs: [EVD-...]
```

# Related skills

`security/external-authentication`, `security/account-inventory`.

# Escalation

Ninguna directa.

# Manual remediation guidance

N/A — inventario puro.

# Security

`proxy_token`/`client_token` → MASK por defecto.

# Tests

`tests/test_security_admin_privileges.sh` (comparte cobertura de identidad con admin-privileges).

# Documentation requirements

Alimenta `analysis/ANA-*/accounts.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

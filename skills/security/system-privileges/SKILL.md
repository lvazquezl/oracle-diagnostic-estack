---
name: system-privileges
id: security/system-privileges
version: 1.0.0
domain: security
status: active
---

# Purpose

Analiza system privileges otorgados directamente y vía rol — base de dangerous privilege
detection (`# 10` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`security/roles` ya ejecutado (para resolución de `grant_path: VIA_ROLE`).

# Required evidence

- `Q-SEC-SYSTEM-PRIVILEGES-001`
- `Q-SEC-ROLE-SYSTEM-PRIVILEGES-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-SEC-SYSTEM-PRIVILEGES-001`, `Q-SEC-ROLE-SYSTEM-PRIVILEGES-001`.

# Collector IDs

`get_system_privileges`.

# Read-only operations

Lectura de `DBA_SYS_PRIVS`/`ROLE_SYS_PRIVS`.

# Forbidden operations

Nunca ejecuta `GRANT`/`REVOKE`.

# Decision logic

1. Para cada grantee, resuelve `grant_path: DIRECT|VIA_ROLE` usando `security/roles`.
2. `role_chain` completa se reporta cuando `VIA_ROLE`.

# Normal state

Privilegios administrativos concentrados en cuentas DBA conocidas.

# Abnormal patterns

`GRANT ANY PRIVILEGE`/`ALTER SYSTEM` en cuenta de aplicación.

# False positives

Ninguno — la presencia del grant es un hecho; la severidad se evalúa en `powerful-privileges`
con contexto.

# Correlation rules

Alimenta `security/powerful-privileges`, `security/admin-privileges`.

# Confidence model

`FACT`.

# Severity

Derivada en `security/powerful-privileges`, no aquí.

# Output schema

```yaml
system_privileges:
  - grantee_token: string
    privilege: string
    admin_option: bool
    grant_path: DIRECT|VIA_ROLE
    role_chain: [string]|null
    con_id: int|null
    evidence_refs: [EVD-...]
```

# Related skills

`security/roles`, `security/powerful-privileges`, `security/public-grants`.

# Escalation

Ninguna directa — `security/powerful-privileges` escala.

# Manual remediation guidance

N/A — inventario puro.

# Security

`grantee_token` → MASK por defecto.

# Tests

`tests/test_security_system_privileges.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/privileges.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

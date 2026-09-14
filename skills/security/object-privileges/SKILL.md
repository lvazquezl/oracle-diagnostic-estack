---
name: object-privileges
id: security/object-privileges
version: 1.0.0
domain: security
status: active
---

# Purpose

Analiza object privileges otorgados directamente y vía rol (`# 10` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`security/roles` ya ejecutado.

# Required evidence

- `Q-SEC-OBJECT-PRIVILEGES-001`
- `Q-SEC-ROLE-OBJECT-PRIVILEGES-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-SEC-OBJECT-PRIVILEGES-001`, `Q-SEC-ROLE-OBJECT-PRIVILEGES-001`.

# Collector IDs

`get_object_privileges`.

# Read-only operations

Lectura de `DBA_TAB_PRIVS`/`ROLE_TAB_PRIVS`.

# Forbidden operations

Nunca ejecuta `GRANT`/`REVOKE`.

# Decision logic

1. Resuelve `grant_path: DIRECT|VIA_ROLE` igual que `system-privileges`.
2. `max_rows`/`time_window` acotan el alcance — nunca se recupera el catálogo completo sin
   límite (# 59 del prompt).

# Normal state

Grants de aplicación concentrados en schemas propios.

# Abnormal patterns

`EXECUTE`/`SELECT` sobre paquetes `SYS.UTL_*` otorgado ampliamente sin justificación.

# False positives

Grants a un schema de reporting read-only conocido no son anómalos por sí solos.

# Correlation rules

Alimenta `security/public-grants`.

# Confidence model

`FACT`.

# Severity

Derivada por el skill consumidor con contexto de objeto/scope.

# Output schema

```yaml
object_privileges:
  - grantee_token: string
    privilege: string
    owner_token: string
    object_token: string
    grant_option: bool
    grant_path: DIRECT|VIA_ROLE
    evidence_refs: [EVD-...]
```

# Related skills

`security/roles`, `security/public-grants`.

# Escalation

Ninguna directa.

# Manual remediation guidance

N/A — inventario puro.

# Security

`grantee_token`/`owner_token` → MASK por defecto.

# Tests

`tests/test_security_object_privileges.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/privileges.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

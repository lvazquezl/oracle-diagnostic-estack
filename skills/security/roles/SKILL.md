---
name: roles
id: security/roles
version: 1.0.0
domain: security
status: active
---

# Purpose

Analiza roles definidos y sus grants (direct + nested), admin option, default roles, common/local
scope — nunca sólo grants directos (`# 10` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-SEC-ROLES-001`
- `Q-SEC-ROLE-GRANTS-001`
- `Q-SEC-NESTED-ROLE-GRANTS-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-SEC-ROLES-001`, `Q-SEC-ROLE-GRANTS-001`, `Q-SEC-NESTED-ROLE-GRANTS-001`.

# Collector IDs

`get_roles`.

# Read-only operations

Lectura de `DBA_ROLES`/`DBA_ROLE_PRIVS`/`ROLE_ROLE_PRIVS`.

# Forbidden operations

Nunca crea/altera/elimina roles.

# Decision logic

1. Construye la cadena de nested roles completa combinando `DBA_ROLE_PRIVS` + `ROLE_ROLE_PRIVS`
   — nunca asume que un usuario sin grant directo carece del privilegio.
2. `common`/`oracle_maintained` sólo se evalúan en 12.1+.

# Normal state

Roles Oracle-maintained estándar (`DBA`, `RESOURCE`, `CONNECT`) más roles de aplicación.

# Abnormal patterns

Rol custom con `admin_option` otorgado ampliamente sin justificación conocida.

# False positives

Nesting profundo de roles estándar de Oracle no es en sí anómalo.

# Correlation rules

Alimenta `security/system-privileges`, `security/object-privileges`, `security/powerful-privileges`.

# Confidence model

`FACT`.

# Severity

Informativo — severidad se deriva en `security/powerful-privileges`.

# Output schema

```yaml
roles:
  - role_token: string
    common: bool|NOT_APPLICABLE
    direct_grants_count: int|null
    nested_roles: [string]
    evidence_refs: [EVD-...]
```

# Related skills

`security/system-privileges`, `security/object-privileges`, `security/powerful-privileges`.

# Escalation

Ninguna directa.

# Manual remediation guidance

N/A — inventario puro.

# Security

`role_token` → KEEP/MASK según convención de nombrado del cliente.

# Tests

`tests/test_security_roles.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/privileges.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

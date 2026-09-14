---
name: account-status
id: security/account-status
version: 1.0.0
domain: security
status: active
---

# Purpose

Resumen agregado de `account_status` (OPEN/EXPIRED/LOCKED/EXPIRED & LOCKED/etc.) sobre el inventario de `security/account-inventory`.

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`security/account-inventory` ya ejecutado.

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

Ninguna adicional (reutiliza evidencia ya recolectada).

# Forbidden operations

Nunca desbloquea/expira cuentas.

# Decision logic

1. Agrega conteos por `account_status` real de la vista — nunca inventa un estado adicional.
2. Distingue `EXPIRED(GRACE)` de `EXPIRED` cuando la versión lo reporta así.

# Normal state

Mayoría `OPEN` con actividad conocida; algunas `LOCKED`/`EXPIRED` esperadas para cuentas
administrativas no usadas.

# Abnormal patterns

Alta proporción de cuentas `OPEN` sin `last_login` conocido en un ambiente con pocas
aplicaciones activas.

# False positives

Cuentas `EXPIRED(GRACE)` recientes no son necesariamente un problema — el usuario aún puede
autenticarse durante el grace period.

# Correlation rules

Alimenta `security/stale-accounts`, `security/security-healthcheck`.

# Confidence model

`FACT` — agregación directa de datos ya certificados.

# Severity

Informativo.

# Output schema

```yaml
account_status_summary:
  open_count: int|null
  expired_count: int|null
  locked_count: int|null
  expired_grace_count: int|null
  evidence_refs: [EVD-...]
```

# Related skills

`security/account-inventory`, `security/stale-accounts`.

# Escalation

Ninguna directa.

# Manual remediation guidance

N/A.

# Security

Sin campos sensibles adicionales — hereda sanitización de `account-inventory`.

# Tests

`tests/test_security_account_status.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/accounts.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

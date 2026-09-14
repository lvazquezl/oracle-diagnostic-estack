---
name: default-accounts
id: security/default-accounts
version: 1.0.0
domain: security
status: active
---

# Purpose

Clasifica cuentas en `ORACLE_MAINTAINED|APPLICATION|ADMINISTRATIVE|DEFAULT_SAMPLE|UNKNOWN` y detecta contraseñas por defecto sin exponer la contraseña misma (`# 8` del prompt de Fase 8).

# Supported Oracle versions

11g–23ai (`DBA_USERS_WITH_DEFPWD` no existe en 10g).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`security/account-inventory` ya ejecutado.

# Required evidence

- `Q-SEC-DEFAULT-ACCOUNTS-001`

# Optional evidence

`Q-SEC-ACCOUNT-INVENTORY-001` para `account_status` correlacionado.

# Licensing requirements

Ninguno.

# Query IDs

`Q-SEC-DEFAULT-ACCOUNTS-001`.

# Collector IDs

`get_default_accounts`.

# Read-only operations

Lectura de `DBA_USERS_WITH_DEFPWD`/`DBA_USERS`.

# Forbidden operations

Nunca bloquea/elimina cuentas. Nunca recomienda drop automático sin identificar dependencia (`# 8` del prompt).

# Decision logic

1. `classification` se determina por catálogo interno de nombres Oracle conocidos (`SYS`, `SYSTEM`, `OUTLN`, `DBSNMP`, etc. según versión) + `ORACLE_MAINTAINED = Y` — nunca por heurística de prefijo/sufijo de nombre sin catálogo.
2. `has_default_password` viene directamente de `DBA_USERS_WITH_DEFPWD` — en 10g, `NOT_AVAILABLE`.
3. Cuenta `DEFAULT_SAMPLE` (ej. `HR`, `SCOTT`, `OE`) `OPEN` con contraseña por defecto → finding `HIGH`.

# Normal state

Cuentas `ORACLE_MAINTAINED` predominantemente `EXPIRED & LOCKED`.

# Abnormal patterns

Cuenta `DEFAULT_SAMPLE`/`ADMINISTRATIVE` con `has_default_password: true` y `account_status: OPEN`.

# False positives

`ORACLE_MAINTAINED = Y` con contraseña por defecto pero `account_status: EXPIRED & LOCKED` no es explotable directamente.

# Correlation rules

Alimenta `security/security-healthcheck`, `security/compliance-mapping`.

# Confidence model

`FACT` para clasificación/estado leído. `PROBABLE_CAUSE` para superficie de riesgo (cuenta default + password default + OPEN).

# Severity

`CRITICAL` si `DEFAULT_SAMPLE`/`ADMINISTRATIVE` + `has_default_password` + `OPEN`. `MEDIUM` en otros casos con password por defecto.

# Output schema

```yaml
default_accounts:
  - user_token: string
    classification: ORACLE_MAINTAINED|APPLICATION|ADMINISTRATIVE|DEFAULT_SAMPLE|UNKNOWN
    has_default_password: bool|null
    account_status: string
    evidence_refs: [EVD-...]
```

# Related skills

`security/account-inventory`, `security/stale-accounts`.

# Escalation

Cuenta `DEFAULT_SAMPLE`/`ADMINISTRATIVE` `OPEN` con password default → `incident-root-cause-analyst`.

# Manual remediation guidance

`manual_action` sugiere `ALTER USER ... PASSWORD EXPIRE` o `ALTER USER ... ACCOUNT LOCK` — siempre `NOT_EXECUTED`, nunca sin dependency analysis previo.

# Security

`user_token` → MASK salvo `ORACLE_MAINTAINED = Y`. Nunca la contraseña por defecto misma.

# Tests

`tests/test_security_default_accounts.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/accounts.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

---
name: account-inventory
id: security/account-inventory
version: 1.0.0
domain: security
status: active
---

# Purpose

Inventario normalizado de cuentas (`user_token, account_status, authentication_type, common, oracle_maintained, profile, created, last_login, expiry_date, lock_date, password_change_date`) — nunca password/hash/verifier (`# 7` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai (`common`/`oracle_maintained`/`last_login` sólo 12.1+, `authentication_type` sólo 11.2+, `password_change_date` sólo 19c+).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-SEC-ACCOUNT-INVENTORY-001`

# Optional evidence

`Q-SEC-COMMON-LOCAL-USERS-001` cuando se requiere visibilidad cross-container completa (CDB).

# Licensing requirements

Ninguno.

# Query IDs

`Q-SEC-ACCOUNT-INVENTORY-001`, `Q-SEC-COMMON-LOCAL-USERS-001`.

# Collector IDs

`get_account_inventory`.

# Read-only operations

Lectura de `DBA_USERS`/`CDB_USERS`.

# Forbidden operations

Nunca crea/altera/elimina cuentas. Nunca selecciona `PASSWORD`/`SPARE4`.

# Decision logic

1. Campos no disponibles en la versión del target (ej. `last_login` en 10g) quedan `null`, nunca inventados.
2. `classification` se deriva vía `security/default-accounts`, nunca inline aquí.
3. Cuenta no autenticada por password (`authentication_type != PASSWORD`) no se evalúa contra password policy aquí — delegado a `security/external-authentication`.

# Normal state

Inventario completo, sin cuentas `OPEN` sin justificación conocida.

# Abnormal patterns

Cuentas `OPEN` con `authentication_type = PASSWORD` y sin `last_login` reciente conocido.

# False positives

Una cuenta de aplicación con `last_login: null` en 10g/11g no es anómala — la columna no existe en esas versiones.

# Correlation rules

Alimenta `security/account-status`, `security/default-accounts`, `security/stale-accounts`, `security/admin-privileges`.

# Confidence model

`FACT` para todo campo leído directamente.

# Severity

Informativo por sí solo — severidad se deriva en skills downstream (`stale-accounts`, `admin-privileges`).

# Output schema

```yaml
account_inventory:
  - user_token: string
    account_status: string
    authentication_type: string|null
    common: bool|NOT_APPLICABLE
    oracle_maintained: bool|null
    profile: string|null
    created: string|null
    last_login: string|null
    expiry_date: string|null
    lock_date: string|null
    password_change_date: string|null
    evidence_refs: [EVD-...]
```

# Related skills

`security/account-status`, `security/default-accounts`, `security/stale-accounts`, `security/common-local-users`.

# Escalation

Ninguna directa — base de evidencia para otros skills.

# Manual remediation guidance

N/A — inventario puro.

# Security

`username`/`user_token` → MASK por defecto salvo `oracle_maintained = Y`. Nunca password/hash.

# Tests

`tests/test_security_account_inventory.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/accounts.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

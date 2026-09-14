---
name: password-verifiers
id: security/password-verifiers
version: 1.0.0
domain: security
status: active
---

# Purpose

Awareness de tipo/versión de verifier de password (`legacy verifier present, modern verifier
present, mixed verifier posture, unknown`) — nunca muestra `PASSWORD`/`SPARE4`/hash/verifier
string (`# 25, # 26` del prompt de Fase 8).

# Supported Oracle versions

11g–23ai (`PASSWORD_VERSIONS` es 11g+).

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-SEC-PASSWORD-VERSIONS-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-SEC-PASSWORD-VERSIONS-001`.

# Collector IDs

`get_password_verifiers`.

# Read-only operations

Lectura de `DBA_USERS.PASSWORD_VERSIONS`.

# Forbidden operations

**The e-stack assesses password policy strength; it never attempts to determine, recover,
crack, validate, expose, compare, or test actual user passwords or password verifiers.** Nunca
expone `PASSWORD`, `SPARE4`, hash ni verifier string (`# 26` del prompt).

# Decision logic

1. `PASSWORD_VERSIONS` normalizado: contiene sólo `10G` → `LEGACY_PRESENT`; contiene `11G`/`12C`
   sin `10G` → `MODERN_PRESENT`; contiene ambos → `MIXED`; no determinable → `UNKNOWN`.
2. En 10g (columna no existe) → `capability_status: UNSUPPORTED`.
3. Nunca se almacena la cadena cruda de `PASSWORD_VERSIONS` en evidencia — sólo el enum
   normalizado.

# Normal state

`MODERN_PRESENT` en instalaciones recientes con `SQLNET.ALLOWED_LOGON_VERSION_SERVER`
configurado alto.

# Abnormal patterns

`LEGACY_PRESENT` (sólo hash 10G, case-insensitive) en cuentas administrativas de una instalación
19c+ — indica contraseña no rotada desde una migración antigua.

# False positives

`MIXED` es esperado durante una migración de versión en curso — no es automáticamente un
problema si es transitorio y conocido.

# Correlation rules

Alimenta `security/password-policy-strength`, `security/compliance-mapping`.

# Confidence model

`FACT` para el enum normalizado.

# Severity

`MEDIUM` para `LEGACY_PRESENT` en cuenta administrativa.

# Output schema

```yaml
password_hash_verifier_protection:
  rule: "The e-stack assesses password policy strength; it never attempts to determine, recover, crack, validate, expose, compare, or test actual user passwords or password verifiers."
  verifier_posture: LEGACY_PRESENT|MODERN_PRESENT|MIXED|UNKNOWN
  evidence_refs: [EVD-...]
```

# Related skills

`security/password-policy-strength`, `security/account-inventory`.

# Escalation

`LEGACY_PRESENT` en cuenta administrativa → finding `MEDIUM`, recomendación de rotación manual.

# Manual remediation guidance

`manual_action` sugiere `ALTER USER ... IDENTIFIED BY <nueva password>` (rotación) para forzar
regeneración del verifier moderno — siempre `NOT_EXECUTED`, nunca la password se genera ni
sugiere por el e-stack.

# Security

Nunca hash/verifier — sólo el enum normalizado de presencia de formato.

# Tests

`tests/test_no_password_hash_exposure.sh`, `tests/test_no_password_verifier_exposure.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/password-policy.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

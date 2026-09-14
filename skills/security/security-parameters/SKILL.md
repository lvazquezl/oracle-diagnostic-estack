---
name: security-parameters
id: security/security-parameters
version: 1.0.0
domain: security
status: active
---

# Purpose

Analiza parámetros de inicialización con impacto de seguridad, con version-awareness — nunca
asume aplicabilidad universal (`# 36` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai — cada parámetro individual evaluado por su propio boundary de versión.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-SEC-SECURITY-PARAMETERS-001`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

`Q-SEC-SECURITY-PARAMETERS-001`.

# Collector IDs

`get_security_parameters`.

# Read-only operations

Lectura de `V$PARAMETER`.

# Forbidden operations

Nunca ejecuta `ALTER SYSTEM SET`.

# Decision logic

1. `REMOTE_LOGIN_PASSWORDFILE` (`NONE|EXCLUSIVE|SHARED`) — relevante para
   `security/admin-privileges`.
2. `O7_DICTIONARY_ACCESSIBILITY` (legacy, default `FALSE` desde 10g).
3. `SEC_CASE_SENSITIVE_LOGON` (default `TRUE` desde 11g).
4. `REMOTE_OS_AUTHENT` (default `FALSE` desde 11g, deprecado).
5. Parámetro no aplicable a la versión del target (ej. deprecado o no introducido aún) →
   `applicable: false`, nunca se inventa un valor.

# Normal state

Defaults seguros de Oracle sin modificar innecesariamente (ej.
`SEC_CASE_SENSITIVE_LOGON = TRUE`).

# Abnormal patterns

`REMOTE_OS_AUTHENT = TRUE` (autenticación OS remota, superficie de riesgo conocida) o
`O7_DICTIONARY_ACCESSIBILITY = TRUE`.

# False positives

Ninguno — cada parámetro se compara contra su propio default documentado por versión.

# Correlation rules

Alimenta `security/compliance-mapping`, `security/security-healthcheck`.

# Confidence model

`FACT`.

# Severity

`HIGH` para `REMOTE_OS_AUTHENT = TRUE`/`O7_DICTIONARY_ACCESSIBILITY = TRUE` en producción.

# Output schema

```yaml
security_parameters:
  - parameter_token: string
    value: string
    applicable: bool
    evidence_refs: [EVD-...]
```

# Related skills

`security/admin-privileges`.

# Escalation

Parámetro inseguro en producción → finding `HIGH`.

# Manual remediation guidance

`manual_action` sugiere `ALTER SYSTEM SET <parametro> = <valor> SCOPE=SPFILE` (requiere
reinicio) — siempre `NOT_EXECUTED`.

# Security

`value` → KEEP (valor de parámetro, no PII).

# Tests

`tests/test_no_database_vault_change.sh` no aplica aquí — ver suite general de seguridad.

# Documentation requirements

Alimenta `analysis/ANA-*/security-posture.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

---
name: password-complexity
id: security/password-complexity
version: 1.0.0
domain: security
status: active
---

# Purpose

Evalúa específicamente los requisitos de complejidad (mayúscula/minúscula/dígito/carácter
especial/longitud mínima) extraídos por `security/password-verify-function`, comparados contra
`Target Profile.security.password_policy.complexity` (`# 16` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`security/password-verify-function` ya ejecutado.

# Required evidence

- evidencia de `security/password-verify-function`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

Ninguna directa — deriva de `security/password-verify-function`.

# Collector IDs

Ninguno.

# Read-only operations

Ninguna adicional.

# Forbidden operations

Nunca ejecuta la verify function ni prueba contraseñas.

# Decision logic

1. Consume `password_verify_function_policy.{minimum_length, uppercase_min, lowercase_min,
   digits_min, special_characters_min}` — nunca reinterpreta el source por su cuenta.
2. Compara cada valor contra `Target Profile.security.password_policy.complexity.*` — mismos
   estados que `password-policy-strength`.
3. `VERIFY_FUNCTION_NOT_ANALYZABLE` en el skill fuente → todos los controles de complejidad
   heredan `VERIFY_FUNCTION_NOT_ANALYZABLE`, nunca se asume un mínimo por defecto.

# Normal state

Complejidad `COMPLIANT` con función de verify custom bien documentada, o `POLICY_NOT_DEFINED`
sin policy target.

# Abnormal patterns

`PASSWORD_VERIFY_FUNCTION` ausente (`null`) en un profile de producción — sin verify function,
Oracle sólo aplica la complejidad mínima por defecto (si alguna), rara vez suficiente para
compliance corporativo.

# False positives

Ninguno — depende enteramente de la analizabilidad ya determinada aguas arriba.

# Correlation rules

Consume `security/password-verify-function`. Alimenta `security/password-policy-strength`.

# Confidence model

`FACT` cuando la función es analizable determinísticamente. `UNDETERMINED` cuando no.

# Severity

`HIGH` si `PASSWORD_VERIFY_FUNCTION` ausente en profile de cuenta administrativa con
`Target Profile.security.password_policy.complexity` definido.

# Output schema

```yaml
password_complexity:
  - profile_token: string
    function_token: string|null
    uppercase_status: string
    lowercase_status: string
    digit_status: string
    special_character_status: string
    evidence_refs: [EVD-...]
```

# Related skills

`security/password-verify-function`, `security/password-policy-strength`.

# Escalation

Ninguna directa — `password-policy-strength` consolida y escala.

# Manual remediation guidance

`manual_action` sugiere crear/actualizar `PASSWORD_VERIFY_FUNCTION` con las reglas requeridas —
siempre `NOT_EXECUTED`.

# Security

Ninguna exposición de contenido de password.

# Tests

`tests/test_password_uppercase_requirement.sh`, `tests/test_password_lowercase_requirement.sh`,
`tests/test_password_digit_requirement.sh`, `tests/test_password_special_character_requirement.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/password-policy.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

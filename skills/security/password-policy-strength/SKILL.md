---
name: password-policy-strength
id: security/password-policy-strength
version: 1.0.0
domain: security
status: active
---

# Purpose

Evalúa, por profile y por control (nunca agregado en un solo score), password-strength policy
contra `Target Profile.security.password_policy` — longitud, complejidad, expiración, intentos
fallidos, lock/grace time, reuse, presencia/analizabilidad de verify function (`# 16` del prompt
de Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

`security/password-profiles`, `security/password-verify-function` ya ejecutados.
`Target Profile.security.password_policy` idealmente definido (`# 15` del prompt) — sin él,
`POLICY_NOT_DEFINED`.

# Required evidence

- evidencia de `security/password-profiles`
- evidencia de `security/password-verify-function`

# Optional evidence

Ninguna.

# Licensing requirements

Ninguno.

# Query IDs

Ninguna directa — deriva de skills previos.

# Collector IDs

Ninguno.

# Read-only operations

Ninguna adicional.

# Forbidden operations

Nunca prueba/genera contraseñas contra cuentas reales para verificar compliance.

# Decision logic

1. Cada control (`minimum_length, uppercase_requirement, lowercase_requirement,
   digit_requirement, special_character_requirement, expiration_policy, failed_login_policy,
   lock_time_policy, grace_time_policy, reuse_time_policy, reuse_max_policy`) se evalúa
   individualmente contra `Target Profile.security.password_policy` — estados:
   `COMPLIANT|NON_COMPLIANT|PARTIALLY_COMPLIANT|NOT_APPLICABLE|INSUFFICIENT_EVIDENCE|
   POLICY_NOT_DEFINED|VERIFY_FUNCTION_NOT_ANALYZABLE`.
2. Sin `Target Profile.security.password_policy` definido → todos los controles
   `POLICY_NOT_DEFINED`, nunca se inventan valores objetivo.
3. `minimum_length`/complejidad dependen de `password-verify-function` — si
   `VERIFY_FUNCTION_NOT_ANALYZABLE`, esos controles heredan ese estado, nunca se asume
   compliance por mera presencia de la función.
4. `authentication_type != PASSWORD` (vía `security/external-authentication`) →
   `policy_status: NOT_APPLICABLE` para esa cuenta, nunca non-compliant.
5. `existing_password_compliance: NOT_DIRECTLY_VERIFIABLE` siempre, incluso si
   `policy_status: COMPLIANT` (`# 21` del prompt — obligatorio, no opcional).
6. `actual_password_content: NOT_INSPECTED` siempre (`# 20` del prompt).

# Normal state

Profiles `COMPLIANT` cuando la política target está definida y se cumple.

# Abnormal patterns

`NON_COMPLIANT` en `minimum_length`/`expiration_policy` para profiles de cuentas con privilegios
administrativos.

# False positives

`POLICY_NOT_DEFINED` no es un fallo del assessment — es un estado honesto ante ausencia de
policy target, distinto de `NON_COMPLIANT`.

# Correlation rules

Consume `security/password-profiles`, `security/password-verify-function`,
`security/external-authentication`. Alimenta `security/compliance-mapping`,
`security/security-healthcheck`.

# Confidence model

`FACT` para valores leídos. `OBSERVATION` para el resultado de comparación contra policy target.

# Severity

`HIGH` para `NON_COMPLIANT` en profile de cuenta administrativa; `MEDIUM` en otros casos.

# Output schema

```yaml
password_strength_policy_assessment:
  - profile_token: string
    minimum_length: {status: string, observed: int|null, target: int|null}
    uppercase_requirement: {status: string, target: int|null}
    lowercase_requirement: {status: string, target: int|null}
    digit_requirement: {status: string, target: int|null}
    special_character_requirement: {status: string, target: int|null}
    expiration_policy: {status: string, observed_days: int|null, target_days: int|null}
    failed_login_policy: {status: string, observed: int|null, target: int|null}
    lock_time_policy: {status: string, observed_minutes: int|null, target_minutes: int|null}
    grace_time_policy: {status: string, observed_days: int|null, target_days: int|null}
    reuse_time_policy: {status: string, observed_days: int|null, target_days: int|null}
    reuse_max_policy: {status: string, observed: int|null, target: int|null}
    policy_status: COMPLIANT|NON_COMPLIANT|PARTIALLY_COMPLIANT|NOT_APPLICABLE|INSUFFICIENT_EVIDENCE|POLICY_NOT_DEFINED
    existing_password_compliance: NOT_DIRECTLY_VERIFIABLE
    actual_password_content: NOT_INSPECTED
    evidence_refs: [EVD-...]
```

# Related skills

`security/password-profiles`, `security/password-complexity`, `security/password-verify-function`,
`security/external-authentication`.

# Escalation

`NON_COMPLIANT` en cuenta administrativa → finding `HIGH`, nunca acción automática.

# Manual remediation guidance

`manual_action` sugiere `ALTER PROFILE ... LIMIT ...` — siempre `NOT_EXECUTED`.

# Security

Sin exposición de contenido de password en ningún punto.

# Tests

`tests/test_password_minimum_length_policy.sh`, `tests/test_password_uppercase_requirement.sh`,
`tests/test_password_lowercase_requirement.sh`, `tests/test_password_digit_requirement.sh`,
`tests/test_password_special_character_requirement.sh`, `tests/test_password_life_time_policy.sh`,
`tests/test_failed_login_attempts_policy.sh`, `tests/test_password_lock_time_policy.sh`,
`tests/test_password_grace_time_policy.sh`, `tests/test_password_reuse_time_policy.sh`,
`tests/test_password_reuse_max_policy.sh`, `tests/test_existing_password_compliance_not_directly_verifiable.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/password-policy.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

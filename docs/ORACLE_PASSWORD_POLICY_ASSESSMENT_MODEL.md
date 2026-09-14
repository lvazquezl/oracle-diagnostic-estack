# Oracle Password Policy Assessment Model — Fase 8

## Principio

El e-stack evalúa la **política** de contraseñas configurada, nunca el contenido real de las contraseñas. Un policy status `COMPLIANT` certifica el profile/verify function actual, nunca las contraseñas ya existentes en el sistema.

## Baseline configurable (`Target Profile.security.password_policy`)

```yaml
security:
  password_policy:
    minimum_length: 16
    complexity: {uppercase_min: 1, lowercase_min: 1, digits_min: 1, special_characters_min: 1}
    password_life_time_days: 60
    failed_login_attempts: 5
    password_lock_time_minutes: 30
    password_grace_time_days: 7
    password_reuse: {minimum_days: 365, minimum_changes: 10}
```

Este es un **ejemplo de policy target**, no un default universal del e-stack. Sin definición explícita, todo control publica `POLICY_NOT_DEFINED` — nunca se inventa un valor objetivo.

## Controles evaluados (por profile, nunca agregados en un score)

| Control | Fuente | Estados |
|---|---|---|
| Longitud mínima | `security/password-verify-function` (source analysis) | `COMPLIANT\|NON_COMPLIANT\|PARTIALLY_COMPLIANT\|NOT_APPLICABLE\|INSUFFICIENT_EVIDENCE\|POLICY_NOT_DEFINED\|VERIFY_FUNCTION_NOT_ANALYZABLE` |
| Mayúscula/minúscula/dígito/especial | `security/password-verify-function` | igual |
| Expiración (`PASSWORD_LIFE_TIME`) | `DBA_PROFILES` | igual |
| Intentos fallidos (`FAILED_LOGIN_ATTEMPTS`) | `DBA_PROFILES` | igual |
| Lock time (`PASSWORD_LOCK_TIME`) | `DBA_PROFILES` | igual |
| Grace time (`PASSWORD_GRACE_TIME`) | `DBA_PROFILES` | igual |
| Reuse time/max | `DBA_PROFILES` | igual |
| Presencia/analizabilidad de verify function | `DBA_SOURCE`/`ALL_SOURCE` | `VERIFY_FUNCTION_NOT_ANALYZABLE` cuando la lógica no es determinista |

## Reglas obligatorias

1. **Authentication type awareness** (`# 22` del prompt): `authentication_type != PASSWORD` (EXTERNAL/GLOBAL/NONE) → `PASSWORD_POLICY_STATUS: NOT_APPLICABLE`, nunca non-compliant por ausencia de verify function.
2. **Multitenant scope** (`# 23` del prompt): common vs. local siempre distinguido — ningún hallazgo se mezcla entre containers.
3. **Existing password compliance uncertainty** (`# 21` del prompt, obligatorio): `existing_password_compliance: NOT_DIRECTLY_VERIFIABLE` incluso cuando `policy_status: COMPLIANT` — las contraseñas existentes pueden preceder al profile/verify function actual.
4. **Actual password content out of scope** (`# 20` del prompt): `actual_password_content: NOT_INSPECTED` siempre — nunca se determina longitud/complejidad real, nunca se obtiene plaintext, nunca se crackea, nunca se prueba.

## Ejemplo de output

```text
User: APP_USER_01
Authentication: PASSWORD
Profile: APP_PROFILE

Minimum length >= 16              PASS
Uppercase >= 1                    PASS
Expiration <= 60 days             PASS
Failed attempts <= 5              PASS

POLICY_STATUS: COMPLIANT
ACTUAL_PASSWORD_CONTENT: NOT_INSPECTED
ACTUAL_PASSWORD_COMPLIANCE: NOT_DIRECTLY_VERIFIABLE
```

Ver `docs/ORACLE_PASSWORD_VERIFY_FUNCTION_ANALYSIS.md` para el modelo de extracción de reglas de complejidad.

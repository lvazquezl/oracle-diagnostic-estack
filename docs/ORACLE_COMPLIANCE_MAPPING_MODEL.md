# Oracle Compliance Mapping Model — Fase 8

## Principio

`security/compliance-mapping` traduce hallazgos técnicos del dominio Security a un modelo de **control genérico, no propietario** — el e-stack nunca certifica cumplimiento de un framework regulatorio específico (PCI-DSS, HIPAA, SOX, GDPR, ISO 27001, etc.), sólo mapea hacia categorías de control genéricas y neutrales.

## Categorías de control genéricas

```text
ACCESS_CONTROL              — cuentas, roles, privilegios, PUBLIC grants, admin privileges
AUTHENTICATION_STRENGTH     — password policy, verify function, profiles
AUDIT_ACCOUNTABILITY        — unified/traditional auditing, privileged audit
DATA_PROTECTION_AT_REST     — TDE, tablespace/column encryption
DATA_PROTECTION_IN_TRANSIT  — network encryption, TLS
DATA_PROTECTION_ADVANCED    — Database Vault, OLS, Data Redaction, Data Masking
NETWORK_EXPOSURE            — database links, directories
CONFIGURATION_HARDENING     — security parameters
```

Cada hallazgo `security/*` se etiqueta con 0-N categorías (nunca forzado a exactamente una) — un finding sobre `PASSWORD_VERIFY_FUNCTION` ausente pertenece a `AUTHENTICATION_STRENGTH`, no a `AUDIT_ACCOUNTABILITY`.

## Explícitamente fuera de alcance

- **Nunca** se declara "cumple PCI-DSS requirement 8.2.3" ni equivalente de ningún framework nombrado — mapear a un framework específico requiere contexto legal/regulatorio y scope de auditoría que el e-stack no tiene ni puede inferir.
- **Nunca** se genera un badge o score de compliance global.
- El cliente puede mantener su propio mapping (categoría genérica → control de su framework) fuera del e-stack; el e-stack sólo entrega las categorías genéricas como building blocks.

## Salida

```yaml
compliance_mapping:
  finding_id: FND-SEC-...
  categories: [AUTHENTICATION_STRENGTH]
  framework_certification: NOT_ASSERTED   # constante, siempre presente
```

`framework_certification: NOT_ASSERTED` es un campo fijo y obligatorio en cada entrada — nunca omitido, nunca condicional.

## Consumidores

`security/compliance-mapping` es consultado por `security/manual-remediation-plan` para agrupar acciones relacionadas, y por el orquestador cuando el Target Profile declara `security.compliance_context` (sólo como agrupación informativa, nunca como certificación).

---
name: database-vault-awareness
id: security/database-vault-awareness
version: 1.0.0
domain: security
status: active
---

# Purpose

Sólo awareness de `installed, enabled, status` de Oracle Database Vault — licensing gate
aplicado, nunca modifica (`# 39` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-SEC-DATABASE-VAULT-STATUS-001`

# Optional evidence

Ninguna.

# Licensing requirements

Oracle Database Vault — `SEPARATELY_LICENSED` por defecto.

# Query IDs

`Q-SEC-DATABASE-VAULT-STATUS-001`.

# Collector IDs

`get_database_vault_status`.

# Read-only operations

Lectura de `V$OPTION`/`DBA_DV_STATUS` (condicional).

# Forbidden operations

Nunca habilita Database Vault, nunca crea/modifica realms o command rules.

# Decision logic

1. `V$OPTION.PARAMETER = 'Oracle Database Vault' = FALSE` → `installed: false`,
   `capability_status: UNSUPPORTED`, nunca se intenta `DBA_DV_STATUS`.
2. `installed: true` → `security/licensing-gates` determina `license.status`; nunca se reporta
   `INCLUDED` sin confirmación explícita del DBA.

# Normal state

`installed: false` en la mayoría de instalaciones (opción separadamente licenciada).

# Abnormal patterns

`installed: true`, `enabled: true` sin confirmación de licencia en el Target Profile — reportado
como `REQUIRES_REVIEW`, nunca asumido usable.

# False positives

Ninguno.

# Correlation rules

Alimenta `security/licensing-gates`, `security/compliance-mapping`.

# Confidence model

`FACT` para instalado/habilitado. El `license.status` es `REQUIRES_REVIEW` por defecto sin
confirmación.

# Severity

Informativo — licensing gate, no una vulnerabilidad en sí.

# Output schema

```yaml
database_vault:
  installed: bool|null
  enabled: bool|null
  license: {feature: "Oracle Database Vault", required: true, edition: string|null, pack: null, status: string, source: string}
  evidence_refs: [EVD-...]
```

# Related skills

`security/ols-awareness`, `security/licensing-gates`.

# Escalation

`installed: true` sin licencia confirmada → finding `REQUIRES_REVIEW`, nunca bloqueante del
resto del assessment.

# Manual remediation guidance

N/A — awareness puro, sin recomendación de habilitar (decisión de licenciamiento del cliente).

# Security

Ninguna exposición de configuración de realm/command rule más allá de status agregado.

# Tests

`tests/test_no_database_vault_change.sh`, `tests/test_database_vault_awareness.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/security-posture.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

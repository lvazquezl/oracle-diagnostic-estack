---
name: ols-awareness
id: security/ols-awareness
version: 1.0.0
domain: security
status: active
---

# Purpose

Sólo awareness y licensing gate de Oracle Label Security (`# 40` del prompt de Fase 8).

# Supported Oracle versions

10g–23ai.

# Supported OS/platforms

Todas.

# Supported architectures

Standalone y RAC.

# Prerequisites

Ninguno.

# Required evidence

- `Q-SEC-OLS-STATUS-001`

# Optional evidence

Ninguna.

# Licensing requirements

Oracle Label Security — `SEPARATELY_LICENSED` por defecto.

# Query IDs

`Q-SEC-OLS-STATUS-001`.

# Collector IDs

`get_ols_status`.

# Read-only operations

Lectura de `V$OPTION`.

# Forbidden operations

Nunca crea/modifica policies/labels de OLS.

# Decision logic

1. `V$OPTION.PARAMETER = 'Oracle Label Security'` → `installed`/`enabled`.
2. Igual criterio de licensing gate que `database-vault-awareness` — nunca `INCLUDED` sin
   confirmación.

# Normal state

`installed: false` en la mayoría de instalaciones.

# Abnormal patterns

`installed: true` sin confirmación de licencia.

# False positives

Ninguno.

# Correlation rules

Alimenta `security/licensing-gates`.

# Confidence model

`FACT` para instalado. `license.status` `REQUIRES_REVIEW` por defecto.

# Severity

Informativo.

# Output schema

```yaml
ols:
  installed: bool|null
  enabled: bool|null
  license: {feature: "Oracle Label Security", required: true, edition: string|null, pack: null, status: string, source: string}
  evidence_refs: [EVD-...]
```

# Related skills

`security/database-vault-awareness`, `security/licensing-gates`.

# Escalation

Ninguna directa.

# Manual remediation guidance

N/A — awareness puro.

# Security

Ninguna exposición de label policy content.

# Tests

`tests/test_ols_awareness.sh`.

# Documentation requirements

Alimenta `analysis/ANA-*/security-posture.md`.

# Change history

v1.0.0 — Fase 8, creación inicial.

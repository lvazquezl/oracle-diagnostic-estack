---
name: TEMPLATE
display_name: "Template"          # sólo para UI/documentación — NUNCA usar como identificador
id: dominio/TEMPLATE               # SIEMPRE domain-qualified y globalmente único (docs/CONTRACTS.md#skill-contract)
version: 0.0.0
domain: ""
status: candidate
---

# Purpose

# Supported Oracle versions

# Supported OS/platforms

# Supported architectures

# Prerequisites

# Required evidence

- query_id:

# Optional evidence

- query_id:

# Read-only operations

# Forbidden operations

- No ejecuta ninguna operación de escritura. Sólo lectura y, cuando corresponde, generación de texto de comando para ejecución humana.

# Decision logic

# Confidence model

# Output schema

```yaml
findings: [{observation: string, severity: LOW|MEDIUM|HIGH, confidence: FACT|OBSERVATION|HYPOTHESIS|PROBABLE_CAUSE|CONFIRMED_ROOT_CAUSE|UNDETERMINED, evidence_refs: [EVD-...]}]
```

# Related skills

# Escalation

# Data sensitivity

# Context budget

# Tests

# Documentation requirements

# Evolution via `/change`

- Cambios vía `/change skill`. Ver [EVOLUTION.md](../../EVOLUTION.md).

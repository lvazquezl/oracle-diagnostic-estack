---
name: severity-awareness
id: incident/severity-awareness
version: 1.0.0
domain: incident
status: active
---

# Purpose

Aplica el mapping de severidad configurable (`SEV1-4` o esquema corporativo equivalente) declarado
en `docs/TARGET_PROFILE.md#schema` (bloque `incident.severity_model`) — nunca inventa impacto para
justificar una severidad (`# 335`-`# 349` del prompt de Fase 11).

# Supported Oracle versions

N/A directo.

# Supported OS/platforms

Todas.

# Supported architectures

Todas.

# Prerequisites

`incident/intake` ejecutado.

# Required evidence

- Bloque `incident:` normalizado (`severity` declarado o ausente).
- `incident.severity_model` del Target Profile, cuando exista.

# Optional evidence

Ninguna adicional.

# Read-only operations

Cálculo local.

# Forbidden operations

Nunca infiere `business_impact`/`users_affected` a partir de la severidad — esos campos vienen
únicamente de evidencia declarada (ver `incident/impact-analysis`).

# Decision logic

1. Si `incident.severity_model` está declarado en el Target Profile, mapear la severidad
   reportada contra ese esquema (`SEV1|SEV2|SEV3|SEV4` u otro corporativo).
2. Sin `severity_model` declarado, `severity` permanece `UNKNOWN` — nunca se asume SEV1 "para estar
   seguros" ni SEV4 "para minimizar" (`# 348` del prompt: "no inventar impacto").
3. Un cambio de severidad durante la investigación (escalamiento/desescalamiento) se registra como
   evento de timeline (`STATE_CHANGE`), nunca sobrescribe silenciosamente la severidad inicial.

# Normal state

`severity` mapeado consistentemente contra el `severity_model` declarado.

# Abnormal patterns

`severity: UNKNOWN` sostenido sin que el DBA declare un `severity_model` — reportado como
limitación, nunca oculto.

# False positives

Asumir SEV1 por defecto ante ausencia de policy es el falso positivo que este skill evita
explícitamente.

# Correlation rules

Consume `incident/intake`. Alimenta `incident/classification`, `incident/evidence-plan`.

# Confidence model

`FACT` cuando `severity_model` está declarado y aplicado; `UNDETERMINED` sin policy.

# Severity

Este skill ES el productor de severidad del dominio.

# Output schema

```yaml
severity_assessment:
  severity: SEV1|SEV2|SEV3|SEV4|UNKNOWN
  severity_model_applied: string|null
  rationale: string
```

# Related skills

`incident/intake`, `incident/classification`, `incident/impact-analysis`.

# Escalation

Ninguna directa.

# Manual remediation guidance

N/A directa.

# Security

Sin datos sensibles.

# Tests

`tests/test_incident_severity_awareness.sh`.

# Documentation requirements

Alimenta `incident-summary.md`.

# Change history

v1.0.0 — Fase 11, creación inicial.
